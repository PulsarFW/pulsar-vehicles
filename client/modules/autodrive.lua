local speed = 20.0
local autopilotActive = false
local keysToDisable = {
	322, -- Esc
	177, -- Backspace
	32, -- W
	34, -- A
	8, -- S
	9, -- D
	23, -- F
	21, -- LShift
	22, -- Space
}

AddEventHandler('Vehicles:Client:StartUp', function()
	plsr.Keybinds:Add('veh_toggle_autodrive', 'Y', 'keyboard', 'Vehicle - Toggle Autopilot', function()
		if VEHICLE_INSIDE and DoesEntityExist(VEHICLE_INSIDE) and VEHICLE_SEAT == -1 then
			if plsr.Vehicles.Engine:CheckKeys() then -- check if have keys
				StartAutoPilot()
			end
		end
	end)

	plsr.Interaction:RegisterMenu("veh_autodrive_danger", false, "skull-crossbones", function()
		StopAutoPilot()
		Wait(1000)
		StartAutoPilot(true)
	end, function()
		if VEHICLE_INSIDE and autopilotActive then
			return true
		end
		return false
	end)
end)

function StartAutoPilot(crazyMode)
	local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
	if not autopilotActive and vehicle then
		autopilotActive = true
		local destination = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))

		local flags = 49599
		if crazyMode then
			flags = 787263
		end

		-- //If no mark is set, wander.
		if destination == vector3(0, 0, 0) then
			TaskVehicleDriveWander(PlayerPedId(), vehicle, crazyMode and 200.0 or speed, flags)
			plsr.Notification.Persistent:Info("autodrive", "Autodrive Wander On", "fas fa-car")
		else
			TaskVehicleDriveToCoordLongrange(
				PlayerPedId(),
				vehicle,
				destination.x,
				destination.y,
				destination.z,
				crazyMode and 200.0 or speed,
				flags,
				20.0
			)
			plsr.Notification.Persistent:Info("autodrive", "Autodrive To Destination On", "fas fa-car")
		end

		CreateThread(function()
			while autopilotActive do
				if not VEHICLE_INSIDE then
					autopilotActive = false
					break
				end

				for k, v in ipairs(keysToDisable) do
					if IsControlPressed(0, v) then
						autopilotActive = false
						break
					end
				end
				Wait(0)
			end

			ClearPedTasks(PlayerPedId())
			plsr.Notification.Persistent:Remove("autodrive")
		end)
	end
end

function StopAutoPilot()
	if autopilotActive then
		autopilotActive = false
	end
end