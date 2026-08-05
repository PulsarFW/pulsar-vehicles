AddEventHandler('Vehicles:Client:StartUp', function()
    plsr.Callbacks:RegisterClientCallback('Vehicles:GetFakePlateAddingVehicle', function(data, cb)
        local target = plsr.Targeting:GetEntityPlayerIsLookingAt()
        if target and target.entity and DoesEntityExist(target.entity) and IsEntityAVehicle(target.entity) and CanModelHaveFakePlate(GetEntityModel(target.entity)) then
            if plsr.Vehicles:HasAccess(target.entity, false, true) and (plsr.Vehicles.Utils:IsCloseToRearOfVehicle(target.entity) or plsr.Vehicles.Utils:IsCloseToFrontOfVehicle(target.entity)) then
                plsr.Progress:Progress({
                    name = "vehicle_adding_plate",
                    duration = 5000,
                    label = "Installing Plate",
                    useWhileDead = false,
                    canCancel = true,
                    ignoreModifier = true,
                    controlDisables = {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = false,
                    },
                    animation = {
                        animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
                        anim = "machinic_loop_mechandplayer",
                        --flags = 15,
                    },
                }, function(cancelled)
                    if not cancelled and plsr.Vehicles:HasAccess(target.entity, true, true) and (plsr.Vehicles.Utils:IsCloseToRearOfVehicle(target.entity) or plsr.Vehicles.Utils:IsCloseToFrontOfVehicle(target.entity)) then
                        cb(VehToNet(target.entity))
                    else
                        cb(false)
                    end
                end)
            else
                cb(false)
            end
        else
            cb(false)
        end
    end)
end)

AddEventHandler('Vehicles:Client:RemoveFakePlate', function(entityData)
    if entityData and DoesEntityExist(entityData.entity) and CanModelHaveFakePlate(GetEntityModel(entityData.entity)) then
        plsr.Progress:Progress({
            name = "vehicle_removing_plate",
            duration = 5000,
            label = "Removing Plate",
            useWhileDead = false,
            canCancel = true,
			ignoreModifier = true,
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = false,
            },
            animation = {
                animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
                anim = "machinic_loop_mechandplayer",
                --flags = 15,
            },
        }, function(cancelled)
            if not cancelled and plsr.Vehicles:HasAccess(entityData.entity) and (plsr.Vehicles.Utils:IsCloseToRearOfVehicle(entityData.entity) or plsr.Vehicles.Utils:IsCloseToFrontOfVehicle(entityData.entity)) then
                plsr.Callbacks:ServerCallback('Vehicles:RemoveFakePlate', VehToNet(entityData.entity), function(success, plate)
                    if success then
                        plsr.Notification:Success('Removed Plate Successfully')
                        SetVehicleNumberPlateText(entityData.entity, plate)
                    else
                        plsr.Notification:Error('Could not Remove Plate')
                    end
                end)
            else
                plsr.Notification:Error('Could not Remove Plate')
            end
        end)
    end
end)

AddEventHandler('Vehicles:Client:RemoveHarness', function(entityData)
    if entityData and DoesEntityExist(entityData.entity) then
        plsr.Progress:Progress({
            name = "vehicle_removing_harness",
            duration = 5000,
            label = "Removing Harness",
            useWhileDead = false,
            canCancel = true,
			ignoreModifier = true,
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = false,
            },
            animation = {
                animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
                anim = "machinic_loop_mechandplayer",
                --flags = 15,
            },
        }, function(cancelled)
            if not cancelled and plsr.Vehicles:HasAccess(entityData.entity, true) then
                plsr.Callbacks:ServerCallback('Vehicles:RemoveHarness', VehToNet(entityData.entity), function(success)
                    if success then
                        plsr.Notification:Success('Removed Harness Successfully')
                    else
                        plsr.Notification:Error('Could not Remove Harness')
                    end
                end)
            else
                plsr.Notification:Error('Could not Remove Harness')
            end
        end)
    end
end)