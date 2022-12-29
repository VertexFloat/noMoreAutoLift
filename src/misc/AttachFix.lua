-- Author: VertexFloat
-- Date: 12.09.2022
-- Version: Farming Simulator 22, 1.0.0.2
-- Copyright (C): VertexFloat, All Rights Reserved
-- AttachFix main class

-- Changelog (1.0.0.1) :
--
-- improved attach behavior when header is on header trailer

-- Changelog (1.0.0.2) :
--
-- improved and optimized code
-- minor bugs fixed

AttachFix = {
    MOD_NAME = g_currentModName
}

local AttachFix_mt = Class(AttachFix)

function AttachFix.new()
    local self = setmetatable({}, AttachFix_mt)

    self.isNotLowered = false
    self.allowedJointTypes = nil

    g_messageCenter:subscribe(BuyVehicleEvent, self.onVehicleBought, self)
    g_messageCenter:subscribe(MessageType.VEHICLE_RESET, self.onVehicleReset, self)

    return self
end

function AttachFix:update(dt)
    local controlledVehicle = g_currentMission.controlledVehicle

    self.isNotLowered = false

    if controlledVehicle ~= nil then
        for _, vehicle in pairs(g_currentMission.vehicles) do
            if vehicle ~= nil then
                if vehicle == controlledVehicle then
                    if SpecializationUtil.hasSpecialization(AttacherJoints, vehicle.specializations) then
                        local info = vehicle.spec_attacherJoints.attachableInfo

                        if info.attachable ~= nil then
                            if self:getIsAttachableObjectDynamicMounted(info.attachable) or self:getIsAttachableObjectPendingDynamicMount(info.attachable) then
                                self.isNotLowered = true
                            end
                        end
                    end
                end
            end
        end
    end
end

function AttachFix:setImplementsLoweredOnAttach(isManualAttach)
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle ~= nil then
            if SpecializationUtil.hasSpecialization(Attachable, vehicle.specializations) then
                for key, value in pairs(vehicle.spec_attachable) do
                    if key == "inputAttacherJoints" then
                        for _, inputAttacherJoint in pairs(value) do
                            if inputAttacherJoint.allowsLowering then
                                if isManualAttach then
                                    inputAttacherJoint.isDefaultLowered = false

                                    if self.allowedJointTypes ~= nil then
                                        for jointType, _ in pairs(self.allowedJointTypes) do
                                            if jointType == inputAttacherJoint.jointType then
                                                inputAttacherJoint.isDefaultLowered = true
                                            end
                                        end
                                    end
                                else
                                    inputAttacherJoint.isDefaultLowered = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function AttachFix:onPostAttach(superFunc, attacherVehicle, inputJointDescIndex, jointDescIndex, loadFromSavegame)
    local spec = self.spec_attacherJointControl
    local inputAttacherJoints = self:getInputAttacherJoints()

    if inputAttacherJoints[inputJointDescIndex] ~= nil and inputAttacherJoints[inputJointDescIndex].isControllable then
        local attacherJoints = attacherVehicle:getAttacherJoints()
        local jointDesc = attacherJoints[jointDescIndex]

        jointDesc.allowsLoweringBackup = jointDesc.allowsLowering
        jointDesc.allowsLowering = false
        jointDesc.upperRotationOffsetBackup = jointDesc.upperRotationOffset
        jointDesc.lowerRotationOffsetBackup = jointDesc.lowerRotationOffset

        spec.jointDesc = jointDesc

        for _, control in ipairs(spec.controls) do
            control.moveAlpha = control.func(self)
        end

        if not loadFromSavegame then
            spec.heightTargetAlpha = spec.jointDesc.lowerAlpha
        end

        self:requestActionEventUpdate()
    end
end

function AttachFix:onVehicleBought()
    if manualAttach ~= nil then
        self:setImplementsLoweredOnAttach(manualAttach.isEnabled)
    else
        self:setImplementsLoweredOnAttach(false)
    end
end

function AttachFix:onVehicleReset()
    if manualAttach ~= nil then
        self:setImplementsLoweredOnAttach(manualAttach.isEnabled)
    else
        self:setImplementsLoweredOnAttach(false)
    end
end

function AttachFix:onManualAttachModeChanged()
    g_currentMission.attachFix:setImplementsLoweredOnAttach(manualAttach.isEnabled)
end

function AttachFix:getIsAttachableObjectDynamicMounted(object)
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle ~= nil then
            if SpecializationUtil.hasSpecialization(DynamicMountAttacher, vehicle.specializations) then
                for _, dynamicMountedObject in pairs(vehicle.spec_dynamicMountAttacher.dynamicMountedObjects) do
                    if object == dynamicMountedObject then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function AttachFix:getIsAttachableObjectPendingDynamicMount(object)
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle ~= nil then
            if SpecializationUtil.hasSpecialization(DynamicMountAttacher, vehicle.specializations) then
                for pendingDynamicMountObject, _ in pairs(vehicle.spec_dynamicMountAttacher.pendingDynamicMountObjects) do
                    if object == pendingDynamicMountObject then
                        return true
                    end
                end
            end
        end
    end

    return false
end

function AttachFix:delete()
    g_messageCenter:unsubscribe(BuyVehicleEvent, self)
    g_messageCenter:unsubscribe(MessageType.VEHICLE_RESET, self)
end

local instance

local function load(mission)
    if g_modIsLoaded[AttachFix.MOD_NAME] then
        instance = AttachFix.new()

        mission.attachFix = instance

        addModEventListener(instance)
    end
end

Mission00.load = Utils.prependedFunction(Mission00.load, load)

local function onFinishedLoading()
    if g_modIsLoaded[AttachFix.MOD_NAME] then
        if g_modIsLoaded["FS22_manualAttach"] then
            manualAttach = _G["FS22_manualAttach"].g_manualAttach

            g_currentMission.attachFix.allowedJointTypes = manualAttach.AUTO_ATTACH_JOINTYPES

            manualAttach.onManualAttachModeChanged = Utils.appendedFunction(manualAttach.onManualAttachModeChanged, AttachFix.onManualAttachModeChanged)

            AttacherJointControl.onPostAttach = Utils.overwrittenFunction(AttacherJointControl.onPostAttach, AttachFix.onPostAttach)

            g_currentMission.attachFix:setImplementsLoweredOnAttach(manualAttach.isEnabled)
        else
            g_currentMission.attachFix:setImplementsLoweredOnAttach(false)
        end
    end
end

FSBaseMission.onFinishedLoading = Utils.prependedFunction(FSBaseMission.onFinishedLoading, onFinishedLoading)

local function attachImplementFromInfo(info)
    local attacherVehicleJointDescIndex = info.spec_attacherJoints.attachableInfo.attacherVehicleJointDescIndex

    if attacherVehicleJointDescIndex ~= nil then
        if g_currentMission.attachFix.isNotLowered then
            info:setJointMoveDown(attacherVehicleJointDescIndex, false, true)
        end
    end
end

AttacherJoints.attachImplementFromInfo = Utils.appendedFunction(AttacherJoints.attachImplementFromInfo, attachImplementFromInfo)

local function delete()
    if g_modIsLoaded[AttachFix.MOD_NAME] then
        g_currentMission.attachFix:delete()

        removeModEventListener(instance)

        g_currentMission.attachFix = nil

        instance = nil
    end
end

FSBaseMission.delete = Utils.prependedFunction(FSBaseMission.delete, delete)