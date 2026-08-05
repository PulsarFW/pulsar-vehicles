LAST_VEH_POS = vector3(0, 0, 0)

AddEventHandler('Vehicles:Client:StartUp', function()
    AddTaskBeforeVehicleThread('mileage', function(veh, class)
        LAST_VEH_POS = GetEntityCoords(THREAD_VEHICLE)
    end)

    AddTaskToVehicleThread('mileage', 8, false, function(veh, class, engine, inside, onExit)
        if DoesEntityExist(veh) then
            local vehEnt = plsr.State.Entity(veh)
            local currentMileage = vehEnt.Mileage
            if type(currentMileage) ~= 'number' then currentMileage = 0 end

            local vehCoords = GetEntityCoords(DAMAGE_VEHICLE)
            local distCovered = #(vehCoords - LAST_VEH_POS)
            if distCovered >= 0.5 then -- Otherwise the vehicle isn't actually moving cunt
                local distCoveredMiles = distCovered / 1609
                local newMileage = plsr.Utils:Round(currentMileage + distCoveredMiles, 2)
                vehEnt.Mileage = newMileage
            end

            LAST_VEH_POS = vehCoords
        end
    end, true)
end)
