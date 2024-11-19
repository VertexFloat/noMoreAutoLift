-- main.lua
--
-- author: 4c65736975
--
-- Copyright (c) 2024 VertexFloat. All Rights Reserved.
--
-- This source code is licensed under the GPL-3.0 license found in the
-- LICENSE file in the root directory of this source tree.

local function getIsAttachableObjectDynamicMounted(object)
  for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
    if vehicle ~= nil and SpecializationUtil.hasSpecialization(DynamicMountAttacher, vehicle.specializations) then
      for _, dynamicMountedObject in pairs(vehicle.spec_dynamicMountAttacher.dynamicMountedObjects) do
        if object == dynamicMountedObject then
          return true
        end
      end
    end
  end

  return false
end

local function getIsAttachableObjectPendingDynamicMount(object)
  for _, vehicle in pairs(g_currentMission.vehicleSystem.vehicles) do
    if vehicle ~= nil and SpecializationUtil.hasSpecialization(DynamicMountAttacher, vehicle.specializations) then
      for pendingDynamicMountObject, _ in pairs(vehicle.spec_dynamicMountAttacher.pendingDynamicMountObjects) do
        if object == pendingDynamicMountObject then
          return true
        end
      end
    end
  end

  return false
end

local function attachImplementFromInfo(self, info)
  if info.attachable ~= nil then
    local attacherJoints = info.attacherVehicle.spec_attacherJoints.attacherJoints
    local isLowered = true

    if info.attachable.spec_foldable ~= nil then
      isLowered, _ = info.attachable:getAllowsLowering()
    end

    if getIsAttachableObjectDynamicMounted(info.attachable) or getIsAttachableObjectPendingDynamicMount(info.attachable) then
      isLowered = false
    end

    if attacherJoints[info.attacherVehicleJointDescIndex].allowsLowering then
      attacherJoints[info.attacherVehicleJointDescIndex].isDefaultLowered = isLowered
    end
  end
end

AttacherJoints.attachImplementFromInfo = Utils.prependedFunction(AttacherJoints.attachImplementFromInfo, attachImplementFromInfo)

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

    spec.heightTargetAlpha = spec.jointDesc.lowerAlpha

    self:requestActionEventUpdate()
  end
end

AttacherJointControl.onPostAttach = Utils.overwrittenFunction(AttacherJointControl.onPostAttach, onPostAttach)