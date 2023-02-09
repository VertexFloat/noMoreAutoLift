-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.3, 08/02/2023
-- @filename: NoMoreAutoLift.lua

-- Changelog (1.0.0.1) :
--
-- improved attach behavior when header is on header trailer

-- Changelog (1.0.0.2) :
--
-- improved and optimized code
-- minor bugs fixed

-- Changelog (1.0.0.3) :
--
-- cleaned code
-- improved compatibility with manualAttach version above 2.0.0.0

NoMoreAutoLift = {}

local manualAttach = nil

function NoMoreAutoLift:loadMap(filename)
	self.isNotLowered = false
	self.allowedJointTypes = nil

	g_messageCenter:subscribe(BuyVehicleEvent, self.onVehicleBought, self)
	g_messageCenter:subscribe(MessageType.VEHICLE_RESET, self.onVehicleReset, self)
end

function NoMoreAutoLift:update(dt)
	local controlledVehicle = g_currentMission.controlledVehicle

	self.isNotLowered = false

	if controlledVehicle ~= nil then
		if SpecializationUtil.hasSpecialization(AttacherJoints, controlledVehicle.specializations) then
			local info = controlledVehicle.spec_attacherJoints.attachableInfo

			if info.attachable ~= nil then
				if self:getIsAttachableObjectDynamicMounted(info.attachable) or self:getIsAttachableObjectPendingDynamicMount(info.attachable) then
					self.isNotLowered = true
				end
			end
		end
	end
end

function NoMoreAutoLift:setImplementsLoweredOnAttach(isManualAttach)
	for _, vehicle in pairs(g_currentMission.vehicles) do
		if vehicle ~= nil then
			if SpecializationUtil.hasSpecialization(Attachable, vehicle.specializations) then
				for key, value in pairs(vehicle.spec_attachable) do
					if key == 'inputAttacherJoints' then
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

function NoMoreAutoLift:onVehicleBought()
	if manualAttach ~= nil then
		self:setImplementsLoweredOnAttach(manualAttach.isEnabled)
	else
		self:setImplementsLoweredOnAttach(false)
	end
end

function NoMoreAutoLift:onVehicleReset()
	if manualAttach ~= nil then
		self:setImplementsLoweredOnAttach(manualAttach.isEnabled)
	else
		self:setImplementsLoweredOnAttach(false)
	end
end

function NoMoreAutoLift:onManualAttachModeChanged()
	NoMoreAutoLift:setImplementsLoweredOnAttach(manualAttach.isEnabled)
end

function NoMoreAutoLift:getIsAttachableObjectDynamicMounted(object)
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

function NoMoreAutoLift:getIsAttachableObjectPendingDynamicMount(object)
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

function NoMoreAutoLift:deleteMap()
	g_messageCenter:unsubscribeAll(self)
end

addModEventListener(NoMoreAutoLift)

local function onFinishedLoading()
	local isManualAttach = false

	if g_modIsLoaded['FS22_manualAttach'] then
		manualAttach = _G['FS22_manualAttach'].g_manualAttach

		if manualAttach == nil then
			manualAttach = g_currentMission.manualAttach
		end

		if manualAttach ~= nil then
			manualAttach.onManualAttachModeChanged = Utils.appendedFunction(manualAttach.onManualAttachModeChanged, NoMoreAutoLift.onManualAttachModeChanged)

			NoMoreAutoLift.allowedJointTypes = manualAttach.AUTO_ATTACH_JOINTYPES

			isManualAttach = manualAttach.isEnabled
		end
	end

	NoMoreAutoLift:setImplementsLoweredOnAttach(isManualAttach)
end

FSBaseMission.onFinishedLoading = Utils.prependedFunction(FSBaseMission.onFinishedLoading, onFinishedLoading)

local function onPostAttach(self, superFunc, attacherVehicle, inputJointDescIndex, jointDescIndex, loadFromSavegame)
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

AttacherJointControl.onPostAttach = Utils.overwrittenFunction(AttacherJointControl.onPostAttach, onPostAttach)

local function attachImplementFromInfo(info)
	local attacherVehicleJointDescIndex = info.spec_attacherJoints.attachableInfo.attacherVehicleJointDescIndex

	if attacherVehicleJointDescIndex ~= nil then
		if NoMoreAutoLift.isNotLowered then
			info:setJointMoveDown(attacherVehicleJointDescIndex, false, true)
		end
	end
end

AttacherJoints.attachImplementFromInfo = Utils.appendedFunction(AttacherJoints.attachImplementFromInfo, attachImplementFromInfo)