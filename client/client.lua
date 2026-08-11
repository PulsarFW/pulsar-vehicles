_characterLoaded, GLOBAL_PED = false, nil

VEHICLE_INSIDE = nil
VEHICLE_SEAT = nil
VEHICLE_CLASS = nil

VEHICLE_TOP_SPEED = nil

VEHICLE_SEATBELT = false
VEHICLE_HARNESS = false

local vehicleDoorNames = {
	[0] = "Driver",
	[1] = "Passenger",
	[2] = "Rear Driver",
	[3] = "Rear Passenger",
	[4] = "Hood",
	[5] = "Trunk",
}

CreateThread(function()
		plsr.State.flags.adjustingCam = false

		RegisterCallbacks()

		TriggerEvent("Vehicles:Client:StartUp")

		plsr.Keybinds:Add("toggle_engine", "G", "keyboard", "Vehicle - Toggle Engine", function()
			if VEHICLE_INSIDE and VEHICLE_SEAT == -1 then
				if IsPauseMenuActive() ~= 1 then
					plsr.Vehicles.Engine:Toggle(VEHICLE_INSIDE)
				end
			end
		end)

		plsr.Interaction:RegisterMenu("veh_quick_actions", 'Vehicle', "car", function()
			if VEHICLE_INSIDE then
				local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)
				local subMenu = {}
				local seatAmount = GetVehicleModelNumberOfSeats(GetEntityModel(VEHICLE_INSIDE))
				plsr.Interaction:ShowMenu({
					{
						icon = "key",
						label = "Give Keys",
						shouldShow = function()
							return VEHICLE_INSIDE and plsr.Vehicles.Keys:Has(vehEnt.VIN, vehEnt.GroupKeys)
						end,
						action = function()
							if plsr.Vehicles.Keys:Has(vehEnt.VIN, vehEnt.GroupKeys) then
								if IsPedInAnyVehicle(PlayerPedId(), true) then
									local sids = {}
									for i = -1, GetVehicleModelNumberOfSeats(VEHICLE_INSIDE), 1 do
										local ped = GetPedInVehicleSeat(VEHICLE_INSIDE, i)
										if ped ~= 0 and ped ~= PlayerPedId() then
											table.insert(sids, GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped)))
										end
									end
									plsr.Callbacks:ServerCallback("Vehicles:GiveKeys", {
										netId = VehToNet(VEHICLE_INSIDE),
										sids = sids,
									})
								end
							end

							plsr.Interaction:Hide()
						end,
					},
					{
						icon = "chair",
						label = "Seats",
						shouldShow = function()
							if VEHICLE_INSIDE then
								if GetVehicleModelNumberOfSeats(GetEntityModel(VEHICLE_INSIDE)) > 1 then
									return true
								end
							end
							return false
						end,
						action = function()
							local seatOptions = {}
							local seatAmount = GetVehicleModelNumberOfSeats(GetEntityModel(VEHICLE_INSIDE))
							for i = 1, seatAmount do
								local actualSeatNumber = i - 2
								if GetPedInVehicleSeat(VEHICLE_INSIDE, actualSeatNumber) == 0 then
									table.insert(seatOptions, {
										icon = "chair",
										label = actualSeatNumber == -1 and "Driver's Seat" or "Seat #" .. i,
										action = function()
											TriggerEvent("Vehicles:Client:Actions:SwitchSeat", actualSeatNumber)
											plsr.Interaction:Hide()
										end,
									})
								end
							end

							if #seatOptions > 0 then
								plsr.Interaction:ShowMenu(seatOptions)
							else
								plsr.Notification:Error("No Seats Free")
							end
						end,
					},
					{
						icon = "car-side",
						label = "Doors",
						shouldShow = function()
							if VEHICLE_INSIDE then
								if GetNumberOfVehicleDoors(VEHICLE_INSIDE) >= 1 then
									return true
								end
							end
							return false
						end,
						action = function()
							local doorOptions = {}
							for doorId, doorName in pairs(vehicleDoorNames) do
								if GetIsDoorValid(VEHICLE_INSIDE, doorId) then
									table.insert(doorOptions, {
										icon = "car-side",
										label = doorName,
										action = function()
											TriggerEvent("Vehicles:Client:Actions:ToggleDoor", doorId)
										end,
									})
								end
							end

							plsr.Interaction:ShowMenu(doorOptions)
						end,
					},
					{
						icon = "car-side",
						label = "Close All Doors",
						shouldShow = function()
							if VEHICLE_INSIDE then
								if GetNumberOfVehicleDoors(VEHICLE_INSIDE) >= 1 then
									return true
								end
							end
							return false
						end,
						action = function()
							if VEHICLE_INSIDE then
								TriggerEvent("Vehicles:Client:Actions:ToggleDoor", "shut")
							end
						end,
					},
					{
						icon = "car-side",
						label = "Open All Doors",
						shouldShow = function()
							if VEHICLE_INSIDE then
								if GetNumberOfVehicleDoors(VEHICLE_INSIDE) >= 1 then
									return true
								end
							end
							return false
						end,
						action = function()
							if VEHICLE_INSIDE then
								TriggerEvent("Vehicles:Client:Actions:ToggleDoor", "open")
							end
						end,
					},
					{
						icon = "person-through-window",
						label = "Windows",
						shouldShow = function()
							if VEHICLE_INSIDE then
								if GetNumberOfVehicleDoors(VEHICLE_INSIDE) >= 1 then
									return true
								end
							end
							return false
						end,
						action = function()
							local windowOptions = {}
							table.insert(windowOptions, {
								icon = "person-through-window",
								label = "Driver Window",
								action = function()
									TriggerEvent("Vehicles:Client:Actions:ToggleWindow", 0)
								end,
							})

							table.insert(windowOptions, {
								icon = "person-through-window",
								label = "Passenger Window",
								action = function()
									TriggerEvent("Vehicles:Client:Actions:ToggleWindow", 1)
								end,
							})

							table.insert(windowOptions, {
								icon = "person-through-window",
								label = "Close All",
								action = function()
									TriggerEvent("Vehicles:Client:Actions:ToggleWindow", "shut")
								end,
							})

							table.insert(windowOptions, {
								icon = "person-through-window",
								label = "Open All",
								action = function()
									TriggerEvent("Vehicles:Client:Actions:ToggleWindow", "open")
								end,
							})

							plsr.Interaction:ShowMenu(windowOptions)
						end,
					},
					{
						icon = "gauge",
						label = "Check Mileage",
						action = function()
							if VEHICLE_INSIDE then
								local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)
								if vehEnt and vehEnt.Mileage then
									plsr.Notification:Info(
										"This Vehicle Has " .. vehEnt.Mileage .. " Miles on the Odometer",
										10000
									)
								end

								plsr.Interaction:Hide()
							end
						end,
					},
					{
						icon = "gauge-simple",
						label = "Check Nitrous Levels",
						shouldShow = function()
							if VEHICLE_INSIDE then
								local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)
								if vehEnt and vehEnt.Nitrous then
									return true
								end
							end
							return false
						end,
						action = function()
							if VEHICLE_INSIDE then
								local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)
								if vehEnt and vehEnt.Nitrous then
									plsr.Notification:Standard(
										"Nitrous Remaining: " .. plsr.Utils:Round(vehEnt.Nitrous, 2) .. "%",
										10000
									)
								end

								plsr.Interaction:Hide()
							end
						end,
					},
					{
						icon = "trash-can",
						label = "Remove Nitrous",
						shouldShow = function()
							if VEHICLE_INSIDE and GetPedInVehicleSeat(VEHICLE_INSIDE, -1) == PlayerPedId() then
								local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)
								if vehEnt and vehEnt.Nitrous then
									return true
								end
							end
							return false
						end,
						action = function()
							if VEHICLE_INSIDE then
								local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)
								if vehEnt and vehEnt.Nitrous then
									TriggerEvent("Vehicles:Client:RemoveNitrous")
								end
							end
						end,
					},
					-- {
					-- 	icon = "print-magnifying-glass",
					-- 	label = "Inspect VIN",
					-- 	shouldShow = function()
					-- 		return (plsr.State.flags.onDuty ~= "police" and Vehicles:HasAccess(VEHICLE_INSIDE))
					-- 			or (plsr.State.flags.onDuty == "police" and LocalPlayer.state.inPdStation)
					-- 	end,
					-- 	action = function()
					-- 		if
					-- 			VEHICLE_INSIDE
					-- 			and (
					-- 				(plsr.State.flags.onDuty ~= "police" and Vehicles:HasAccess(VEHICLE_INSIDE))
					-- 				or (plsr.State.flags.onDuty == "police" and LocalPlayer.state.inPdStation)
					-- 			)
					-- 		then
					--             ListMenu:Close()
					-- 			TriggerServerEvent("Vehicle:Server:InspectVIN", VehToNet(VEHICLE_INSIDE))
					-- 		end
					-- 	end,
					-- },
					{
						icon = "lightbulb",
						label = "Neons",
						shouldShow = function()
							if VEHICLE_INSIDE and plsr.Vehicles.Sync.Neons:Has() and not plsr.Police:IsPdCar(VEHICLE_INSIDE) then
								return true
							end
						end,
						action = function()
							if VEHICLE_INSIDE then
								plsr.Vehicles.Sync.Neons:Toggle()
							end
						end,
					},
				})
			end
		end, function()
			if VEHICLE_INSIDE then
				return true
			end
			return false
		end)
end)

AddEventHandler("Vehicles:Client:GiveKeys", function(entityData, data)
	local vehEnt = plsr.State.Entity(entityData.entity)

	if plsr.Vehicles.Keys:Has(vehEnt.VIN, vehEnt.GroupKeys) then
		local myCoords = GetEntityCoords(PlayerPedId())
		local peds = GetGamePool("CPed")
		local sids = {}
		for _, ped in ipairs(peds) do
			if ped ~= PlayerPedId() and IsPedAPlayer(ped) then
				local entCoords = GetEntityCoords(ped)
				if #(entCoords - myCoords) <= 4.0 then
					table.insert(sids, GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped)))
				end
			end
		end
		plsr.Callbacks:ServerCallback("Vehicles:GiveKeys", {
			netId = VehToNet(entityData.entity),
			sids = sids,
		})
	end
	
end)

RegisterNetEvent("Characters:Client:Spawn")
AddEventHandler("Characters:Client:Spawn", function()
	_characterLoaded = true
	TriggerEvent("Vehicles:Client:CharacterLogin")
end)

RegisterNetEvent("Characters:Client:Logout")
AddEventHandler("Characters:Client:Logout", function()
	_characterLoaded = false

	TriggerEvent("Vehicles:Client:CharacterLogout")
end)

RegisterNetEvent("Vehicles:Client:Actions:SwitchSeat")
AddEventHandler("Vehicles:Client:Actions:SwitchSeat", function(seatNum)
	if not VEHICLE_INSIDE then
		return
	end
	if GetPedInVehicleSeat(VEHICLE_INSIDE, seatNum) == 0 then
		SetPedIntoVehicle(GLOBAL_PED, VEHICLE_INSIDE, seatNum)
	else
		plsr.Notification:Error("Seat Occupied")
	end
end)

RegisterNetEvent("Vehicles:Client:Actions:ToggleDoor")
AddEventHandler("Vehicles:Client:Actions:ToggleDoor", function(doorNum)
	local vehicle = VEHICLE_INSIDE

	if not vehicle then
		local targetVehicle = plsr.Targeting:GetEntityPlayerIsLookingAt()
		if
			targetVehicle
			and targetVehicle.entity
			and DoesEntityExist(targetVehicle.entity)
			and GetEntitySpeed(targetVehicle.entity) <= 2.0
			and GetPedInVehicleSeat(targetVehicle.entity, -1) == 0
			and GetVehicleDoorLockStatus(targetVehicle.entity) == 1
		then
			vehicle = targetVehicle.entity
		else
			return
		end
	end

	if doorNum == "shut" or doorNum == "close" then
		plsr.Vehicles.Sync.Doors:Shut(vehicle, "all", false)
	elseif doorNum == "open" then
		plsr.Vehicles.Sync.Doors:Open(vehicle, "all", false, false)
	else
		if GetVehicleDoorAngleRatio(vehicle, doorNum) > 0.0 then
			plsr.Vehicles.Sync.Doors:Shut(vehicle, doorNum, false)
		else
			plsr.Vehicles.Sync.Doors:Open(vehicle, doorNum, false, false)
		end
	end
end)

RegisterNetEvent("Vehicles:Client:Actions:ToggleWindow")
AddEventHandler("Vehicles:Client:Actions:ToggleWindow", function(winNum)
	local vehicle = VEHICLE_INSIDE

	if not vehicle then
		local targetVehicle = plsr.Targeting:GetEntityPlayerIsLookingAt()
		if
			targetVehicle
			and targetVehicle.entity
			and DoesEntityExist(targetVehicle.entity)
			and GetEntitySpeed(targetVehicle.entity) <= 2.0
			and GetPedInVehicleSeat(targetVehicle.entity, -1) == 0
		then
			vehicle = targetVehicle.entity
		else
			return
		end
	end

	if winNum == "shut" or winNum == "close" then
		for i = 0, 4 do
			RollUpWindow(vehicle, i)
		end
	elseif winNum == "open" then
		for i = 0, 4 do
			RollDownWindows(vehicle, i)
		end
	else
		if IsVehicleWindowIntact(vehicle, winNum) then
			RollDownWindows(vehicle, winNum)
		else
			RollUpWindow(vehicle, winNum)
		end
	end
end)
