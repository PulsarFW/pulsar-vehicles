AddEventHandler('Vehicles:Client:StartUp', function()
    plsr.Keybinds:Add('emergency_lights', 'Q', 'keyboard', 'Vehicle - Toggle Emergency Lighting', function()
        plsr.Vehicles.Sync.EmergencyLights:Toggle()
    end)

    plsr.Keybinds:Add('emergency_sirens', 'LMENU', 'keyboard', 'Vehicle - Toggle Emergency Sirens', function()
        plsr.Vehicles.Sync.EmergencySiren:Toggle()
    end)

    plsr.Keybinds:Add('emergency_sirens_tone', 'R', 'keyboard', 'Vehicle - Cycle Emergency Siren Tone', function()
        plsr.Vehicles.Sync.EmergencySiren:Cycle()
    end)

    plsr.Keybinds:Add('emergency_airhorn', 'E', 'keyboard', 'Vehicle - Emergency Airhorn', function()
        plsr.Vehicles.Sync.EmergencyAirhorn:Set(true)
    end, function()
        plsr.Vehicles.Sync.EmergencyAirhorn:Set(false)
    end)

    plsr.Keybinds:Add('veh_indicators_hazards', '\\', 'keyboard', 'Vehicle - Indicator - Hazards', function()
        plsr.Vehicles.Sync.Indicators:Set(0)
    end)

    plsr.Keybinds:Add('veh_indicators_right', 'X', 'keyboard', 'Vehicle - Indicator - Right', function()
        plsr.Vehicles.Sync.Indicators:Set(1)
    end)

    plsr.Keybinds:Add('veh_indicators_left', 'Z', 'keyboard', 'Vehicle - Indicator - Left', function()
        plsr.Vehicles.Sync.Indicators:Set(2)
    end)

    plsr.Keybinds:Add('veh_neons_toggle', '', 'keyboard', 'Vehicle - Toggle Neons/Underglow', function()
        plsr.Vehicles.Sync.Neons:Toggle()
    end)

    plsr.Keybinds:Add('veh_k9_leavevehicle', '', 'keyboard', 'Vehicle - K9 - Get Out of Vehicle', function()
        if plsr.State.flags.isK9Ped then
            TriggerEvent("Vehicles:Client:K9LeaveVehicle")
        end
    end)
end)