local LAST_DIRT_LEVEL = false
local DIRT_MULT = false

AddEventHandler('Vehicles:Client:StartUp', function()
    plsr.Callbacks:RegisterClientCallback('Vehicles:UseCarPolish', function(data, cb)
        local target = plsr.Targeting:GetEntityPlayerIsLookingAt()
        if target and target.entity and DoesEntityExist(target.entity) and IsEntityAVehicle(target.entity) then
            if plsr.Vehicles.Utils:IsCloseToVehicle(target.entity) then
                plsr.Progress:Progress({
                    name = "vehicle_applying_polish",
                    duration = 5000,
                    label = "Applying Polish",
                    useWhileDead = false,
                    canCancel = true,
                    controlDisables = {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = false,
                    },
                    animation = {
                        anim = "maid",
                    },
                }, function(cancelled)
                    if not cancelled and plsr.Vehicles.Utils:IsCloseToVehicle(target.entity) then
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


AddEventHandler('Vehicles:Client:StartUp', function()
    AddTaskToVehicleThread('car_polish', 8, true, function(veh, class, running, inside, onExit)
        if LAST_DIRT_LEVEL then
            if DIRT_MULT then
                local diff = GetVehicleDirtLevel(veh) - LAST_DIRT_LEVEL
                if DoesEntityExist(veh) and diff > 0 then
                    LAST_DIRT_LEVEL += (diff / DIRT_MULT)
                    local newDirtLevel = plsr.Utils:Round(LAST_DIRT_LEVEL, 5)
                    if newDirtLevel > 10.0 then
                        newDirtLevel = 10.0
                    end

                    SetVehicleDirtLevel(veh, newDirtLevel)
                    LAST_DIRT_LEVEL = newDirtLevel
                end
            end
        else
            local ent = plsr.State.Entity(veh)
            LAST_DIRT_LEVEL = GetVehicleDirtLevel(veh)
            if ent?.Polish then
                print('Vehicle Has Polish: ', json.encode(ent?.Polish))
                DIRT_MULT = ent.Polish?.Mult or 2
            else
                DIRT_MULT = false
            end
        end

        if onExit then
            LAST_DIRT_LEVEL = false
        end
    end, true)
end)