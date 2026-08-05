function UpdateVehicleIndicatorState(veh, state)
    if not state then
        SetVehicleIndicatorLights(veh, 0, false)
        SetVehicleIndicatorLights(veh, 1, false)
    end

    if state == 0 then -- Hazards
        SetVehicleIndicatorLights(veh, 0, true)
        SetVehicleIndicatorLights(veh, 1, true)
    elseif state == 1 then -- Right
        SetVehicleIndicatorLights(veh, 0, true)
        SetVehicleIndicatorLights(veh, 1, false)
    elseif state == 2 then -- Left
        SetVehicleIndicatorLights(veh, 0, false)
        SetVehicleIndicatorLights(veh, 1, true)
    end
end

function DoVehicleIndicatorUpdate(veh, newState)
    local vehEnt = plsr.State.Entity(veh)
    if vehEnt then
        vehEnt.indicators = newState
    end
end

plsr.State.Entity:WatchKey('indicators', function(netId, value)
    local veh = NetToVeh(netId)
    if DoesEntityExist(veh) and SYNCED_VEHICLES[veh] then
        SYNCED_VEHICLES[veh].indicators = value
        UpdateVehicleIndicatorState(veh, value)
    end
end)

RegisterNetEvent('VehicleSync:Client:SyncIndicators', function(veh, state)
    if NetworkDoesEntityExistWithNetworkId(veh) then
        local veh = NetToVeh(veh)
        if DoesEntityExist(veh) and SYNCED_VEHICLES[veh] then
            SYNCED_VEHICLES[veh].indicators = state
            UpdateVehicleIndicatorState(veh, state)
        end
    end
end)