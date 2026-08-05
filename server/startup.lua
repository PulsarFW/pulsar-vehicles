local _ran = false

function Startup()
    if _ran then return end
    _ran = true

    EnsureVehiclesTable(function()
        plsr.Database:Scalar("SELECT COUNT(*) FROM `vehicles` WHERE `owner_type` = 0", nil, function(success, count)
            if success then
                plsr.Logger:Trace('Vehicles', string.format('Loaded ^2%s^7 Character Owned Vehicles', count))
            end
        end)

        plsr.Database:Scalar("SELECT COUNT(*) FROM `vehicles` WHERE `owner_type` = 1", nil, function(success, count)
            if success then
                plsr.Logger:Trace('Vehicles', string.format('Loaded ^2%s^7 Fleet Owned Vehicles', count))
            end
        end)
    end)

    -- CreateThread(function()
    --     -- Let the server startup, no vehicles need to be saved in the first 2 mins
    --     Wait(120000)
    --     while true do
    --         local savingVINs = {}
    --         for k, v in pairs(ACTIVE_OWNED_VEHICLES) do
    --             if v ~= nil then
    --                 local vData = v:GetData()
    --                 if vData.EntityId and DoesEntityExist(vData.EntityId) then
    --                     local vehEnt = Entity(vData.EntityId)
    --                     if (vehEnt and vehEnt.state and vehEnt.state.NeedSave) then
    --                         vehEnt.state.NeedSave = false
    --                         table.insert(savingVINs, vData.VIN)
    --                     end
    --                 end
    --             end
    --         end

    --         if #savingVINs > 0 then
    --             local timeSpread = math.floor((720 * 1000) / #savingVINs)
    --             if timeSpread < 2000 then
    --                 timeSpread = 2000
    --             end
    
    --             Logger:Info('Vehicles', 'Running Periodical Save For '.. #savingVINs .. ' Vehicles')
    
    --             for k, v in ipairs(savingVINs) do
    --                 SaveVehicle(v)
    --                 Wait(timeSpread)
    --             end
    --         else
    --             Wait(180000)
    --         end
    --     end
    -- end)

    local deleteTime = 120 -- Minutes

    CreateThread(function()
        -- Let the server startup, no vehicles need to be saved in the first 2 mins
        while true do
            Wait(1000 * 60 * 30)
            local vehs = GetAllVehicles()
            local timeBefore = os.time() - 60 * deleteTime

            for k, v in ipairs(vehs) do
                if DoesEntityExist(v) then
                    local state = plsr.State.Entity(v)
                    if state and not state.Owned and not state.SpawnTemp and state.LastDriven and state.LastDriven <= timeBefore then
                        plsr.Vehicles:Delete(v, function() end)
                    end
                end
            end
        end
    end)
end