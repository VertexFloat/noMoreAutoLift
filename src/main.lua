-- @author: 4c65736975, All Rights Reserved
-- @version: 1.0.0.5, 10|05|2023
-- @filename: main.lua

-- Changelog (1.0.0.1):
-- improved attach behavior when header is on header trailer

-- Changelog (1.0.0.2):
-- improved and optimized code
-- minor bugs fixed

-- Changelog (1.0.0.3):
-- cleaned code
-- improved compatibility with manualAttach version above 2.0.0.0

-- Changelog (1.0.0.4):
-- fixed compatibility with trailed implements

-- Changelog (1.0.0.5):
-- cleaned and improved code

local function getIsAttachableObjectDynamicMounted(object)
  for _, vehicle in pairs(g_currentMission.vehicles) do
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
  for _, vehicle in pairs(g_currentMission.vehicles) do
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

    if g_currentMission.manualAttach ~= nil then
      if g_currentMission.manualAttach.AUTO_ATTACH_JOINTYPES[attacherJoints[info.attacherVehicleJointDescIndex].jointType] then
        isLowered = true
      else
        isLowered = not g_currentMission.manualAttach.isEnabled
      end
    end

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