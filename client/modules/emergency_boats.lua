AddEventHandler('Vehicles:Client:StartUp', function()
    plsr.Interaction:RegisterMenu("pd_ems_boats", "Access Boat", "ship", function()
        StartRequestEmergencyBoat()
        plsr.Interaction:Hide()
    end, function()
        if plsr.State.flags.onDuty == "police" or plsr.State.flags.onDuty == "ems" then
            local pedCoords = GetEntityCoords(PlayerPedId())
            local inVehicleStorageZone, vehicleStorageZoneId = GetVehicleStorageAtCoords(pedCoords)

            if inVehicleStorageZone and vehicleStorageZoneId then
                local vehStorageData = _vehicleStorage[vehicleStorageZoneId]

                if vehStorageData and vehStorageData.spaces and vehStorageData.vehType == 1 then
                    return true
                end
            end
        end
    end)
end)

function StartRequestEmergencyBoat()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local inVehicleStorageZone, vehicleStorageZoneId = GetVehicleStorageAtCoords(pedCoords)
    if inVehicleStorageZone and vehicleStorageZoneId then
        local vehStorageData = _vehicleStorage[vehicleStorageZoneId]

        if vehStorageData and vehStorageData.spaces and vehStorageData.vehType == 1 then
            local parkingSpace = GetClosestAvailableParkingSpace(pedCoords, vehStorageData.spaces)

            if parkingSpace then
                TriggerServerEvent("Vehicles:Server:RequestEmergencyBoat", parkingSpace)
                return
            end
        end
    end

    plsr.Notification:Error("Not at Boat Storage or Spaces Full")
end