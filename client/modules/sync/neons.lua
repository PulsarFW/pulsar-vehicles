function UpdateVehicleNeonsState(veh, state)
    DisableVehicleNeonLights(veh, state)
end

function DoVehicleNeonUpdate(veh, newState)
    local vehEnt = plsr.State.Entity(veh)
    if vehEnt then
        vehEnt.neonsDisabled = newState
    end
end

plsr.State.Entity:WatchKey('neonsDisabled', function(netId, value)
    local veh = NetToVeh(netId)
    if DoesEntityExist(veh) and SYNCED_VEHICLES[veh] then
        SYNCED_VEHICLES[veh].neonsDisabled = value
        UpdateVehicleNeonsState(veh, value)
    end
end)

RegisterNetEvent('VehicleSync:Client:SyncNeons', function(veh, state)
    if NetworkDoesEntityExistWithNetworkId(veh) then
        local veh = NetToVeh(veh)
        if DoesEntityExist(veh) and SYNCED_VEHICLES[veh] then
            SYNCED_VEHICLES[veh].neonsDisabled = state
            UpdateVehicleNeonsState(veh, state)
        end
    end
end)