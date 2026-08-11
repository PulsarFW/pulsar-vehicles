SLIM_JIM_ATTEMPTS = {}

local _actionShowing = false

_vehicleClasses = {
	X = {
		value = 2000000,
		lockpick = false,
		advLockpick = false,
		hack = false,
		advHack = {
			exterior = { rows = 10, length = 5, duration = 15000, charSize = 2 },
			interior = { rows = 10, length = 5, duration = 15000, charSize = 2 },
		},
	},
	S = {
		value = 1000000,
		lockpick = false,
		advLockpick = false,
		hack = false,
		advHack = {
			exterior = { rows = 9, length = 4, duration = 20000, charSize = 2 },
			interior = { rows = 9, length = 4, duration = 20000, charSize = 2 },
		},
		topSpeed = 160.0, -- IN MPH (IS CONVERTED LATER)
	},
	A = {
		value = 500000,
		lockpick = {
			exterior = { stages = { 2, 3, 4, 5 }, base = 5 },
			interior = { stages = { 2, 3, 4, 5 }, base = 5 },
		},
		advLockpick = {
			exterior = { stages = { 0.8, 1.0, 1.2 }, base = 5 },
			interior = { stages = { 0.8, 1.0, 1.2 }, base = 5 },
		},
		hack = {
			exterior = { rows = 14, length = 8, duration = 18000, charSize = 2 },
			interior = { rows = 14, length = 8, duration = 18000, charSize = 2 },
		},
		advHack = {
			exterior = { rows = 8, length = 4, duration = 30000, charSize = 2, charSet = "alphanumer" },
			interior = { rows = 8, length = 4, duration = 30000, charSize = 2, charSet = "alphanumer" },
		},
		topSpeed = 150.0,
	},
	B = {
		value = 350000,
		lockpick = {
			exterior = { stages = { 0.8, 1.0, 1.2, 1.4, 1.6 }, base = 6 },
			interior = { stages = { 0.8, 1.0, 1.2, 1.4, 1.6 }, base = 6 },
		},
		advLockpick = {
			exterior = { stages = { 0.4, 0.5 }, base = 4 },
			interior = { stages = { 0.4, 0.5 }, base = 4 },
		},
		hack = {
			exterior = { rows = 8, length = 4, duration = 30000, charSize = 2, charSet = "alphanumer" },
			interior = { rows = 8, length = 4, duration = 30000, charSize = 2, charSet = "alphanumer" },
		},
		advHack = {
			exterior = { rows = 6, length = 3, duration = 20000, charSize = 1, charSet = "alphanumer" },
			interior = { rows = 6, length = 3, duration = 20000, charSize = 1, charSet = "alphanumer" },
		},
		topSpeed = 140.0,
	},
	C = {
		value = 250000,
		lockpick = {
			exterior = { stages = { 0.8, 1.0, 1.2, 1.4 }, base = 6 },
			interior = { stages = { 0.8, 1.0, 1.2, 1.4 }, base = 6 },
		},
		advLockpick = {
			exterior = { stages = { 0.4, 0.5 }, base = 5 },
			interior = { stages = { 0.4, 0.5 }, base = 5 },
		},
		hack = {
			exterior = { rows = 8, length = 4, duration = 30000, charSize = 2, charSet = "alphanumer" },
			interior = { rows = 8, length = 4, duration = 30000, charSize = 2, charSet = "alphanumer" },
		},
		advHack = {
			exterior = { rows = 6, length = 3, duration = 20000, charSize = 1, charSet = "alphanumer" },
			interior = { rows = 6, length = 3, duration = 20000, charSize = 1, charSet = "alphanumer" },
		},
		topSpeed = 120.0,
	},
	D = {
		value = 150000,
		lockpick = {
			exterior = { stages = { 0.8, 1.0, 1.2 }, base = 6 },
			interior = { stages = { 0.8, 1.0, 1.2 }, base = 6 },
		},
		advLockpick = {
			exterior = { stages = { 0.4, 0.5 }, base = 5 },
			interior = { stages = { 0.4, 0.5 }, base = 5 },
		},
		hack = {
			exterior = { rows = 8, length = 4, duration = 30000, charSize = 2, charSet = "alphanumer" },
			interior = { rows = 8, length = 4, duration = 30000, charSize = 2, charSet = "alphanumer" },
		},
		advHack = {
			exterior = { rows = 6, length = 3, duration = 20000, charSize = 1, charSet = "alphanumer" },
			interior = { rows = 6, length = 3, duration = 20000, charSize = 1, charSet = "alphanumer" },
		},
		topSpeed = 110.0,
	},
}

VEHICLE = {
    _required = {},
    Engine = {
        Force = function(self, veh, state)
            local vehState = plsr.State.Entity(veh)

            if state and vehState.Fuel and vehState.Fuel <= 0.0 then
                state = false
                plsr.Notification:Error('Vehicle Out of Fuel', 2500, 'gas-pump')
            end

            if state and GetVehicleEngineHealth(veh) <= -2000.0 then
                state = false
                plsr.Notification:Error('Vehicle Engine Damaged', 2500)
            end

            if state then
				if not vehState.VEH_IGNITION then
					vehState.VEH_IGNITION = true
				end
                SetVehicleEngineOn(veh, true, false, true)
                SetVehicleUndriveable(veh, false)

                if _actionShowing then
                    plsr.Action:Hide('engine')
                    _actionShowing = false
                end
            else
				if vehState.VEH_IGNITION then
					vehState.VEH_IGNITION = false
				end
                SetVehicleEngineOn(veh, false, true, true)
                SetVehicleUndriveable(veh, true)
            end

            TriggerEvent('Vehicles:Client:Ignition', state)
        end,
        Off = function(self, customMessage)
            local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)
            plsr.Vehicles.Engine:Force(VEHICLE_INSIDE, false)
            plsr.Notification:Info(customMessage and customMessage or 'Engine Turned Off', 1500)

            if plsr.Vehicles.Keys:Has(vehEnt.VIN, vehEnt.GroupKeys) then
                plsr.Action:Show('engine', '{keybind}toggle_engine{/keybind} Turn Engine On')
                _actionShowing = true
            end
        end,
        On = function(self)
            local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)

            if plsr.Vehicles.Keys:Has(vehEnt.VIN, vehEnt.GroupKeys) then
                plsr.Vehicles.Engine:Force(VEHICLE_INSIDE, true)
				plsr.Notification:Info('Engine Turned On', 1500)
            else
                plsr.Notification:Error('You Don\'t Have Keys For This Vehicle', 3000, 'key')
            end
        end,
		CheckKeys = function (self)
			local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)

            if plsr.Vehicles.Keys:Has(vehEnt.VIN, vehEnt.GroupKeys) then
                return true
            else
                plsr.Notification:Error('You Don\'t Have Keys For This Vehicle', 3000, 'key')
                return false
            end
		end,
        Toggle = function(self)
            local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)

            if vehEnt.VEH_IGNITION then
                plsr.Vehicles.Engine:Off()
            else
                plsr.Vehicles.Engine:On()
            end
        end,
    },
	SlimJim = function(self, vehicle)
		local vehEnt = plsr.State.Entity(vehicle)
		local val = GetVehicleHandlingInt(vehicle, "CHandlingData", "nMonetaryValue")

		if not vehEnt.towObjective then
			if vehEnt and vehEnt.VIN and not plsr.Vehicles:HasAccess(vehicle) then
				local vVIN = vehEnt.VIN

				if SLIM_JIM_ATTEMPTS[vVIN] and SLIM_JIM_ATTEMPTS[vVIN] > 3 then
					plsr.Notification:Error("You Have Tried This Vehicle Enough Already")
					return
				end

				local setToFail = false
				if vehEnt.Owned or val > 100000 then
					setToFail = true
				end
	
				local failRoll = math.random(0, 60)
				if failRoll <= 20 and failRoll >= 5 then
					setToFail = true
				end
	
				local startCoords = GetEntityCoords(GLOBAL_PED)
				TaskTurnPedToFaceEntity(GLOBAL_PED, vehicle, 500)
	
				local dumbAnim = true
	
				RequestAnimDict("veh@break_in@0h@p_m_one@")
				while not HasAnimDictLoaded("veh@break_in@0h@p_m_one@") do
					Wait(5)
				end
	
				CreateThread(function()
					while dumbAnim do
						TaskPlayAnim(
							GLOBAL_PED,
							"veh@break_in@0h@p_m_one@",
							"low_force_entry_ds",
							1.0,
							1.0,
							1.0,
							16,
							0.0,
							0,
							0,
							0
						)
						Wait(1000)
	
						if math.random(100) <= 50 then
							SetVehicleAlarm(VEHICLE_INSIDE, true)
							SetVehicleAlarmTimeLeft(VEHICLE_INSIDE, 1000)
							StartVehicleAlarm(VEHICLE_INSIDE)
						end
					end
				end)
	
				plsr.Minigame.Play:RoundSkillbar(12, 3, {
					onSuccess = function()
						dumbAnim = false
						ClearPedTasks(GLOBAL_PED)
						if not SLIM_JIM_ATTEMPTS[vVIN] then
							SLIM_JIM_ATTEMPTS[vVIN] = 1
						else
							SLIM_JIM_ATTEMPTS[vVIN] = SLIM_JIM_ATTEMPTS[vVIN] + 1
						end
	
						if setToFail then
							plsr.Notification:Error("It Was too Difficult and It Didn't Work")
						else
							if #(startCoords - GetEntityCoords(GLOBAL_PED)) <= 2.0 then
								SetVehicleHasBeenOwnedByPlayer(vehicle, true)
								SetEntityAsMissionEntity(vehicle, true, true)
								plsr.Callbacks:ServerCallback("Vehicles:BreakOpenLock", {
									netId = VehToNet(vehicle),
								}, function(success)
									plsr.Notification:Success("You Managed to Unlock the Vehicle", 3000, "key")
								end)
							else
								plsr.Notification:Error("Too Far")
							end
						end
					end,
					onFail = function()
						dumbAnim = false
						ClearPedTasks(GLOBAL_PED)
						if not SLIM_JIM_ATTEMPTS[vVIN] then
							SLIM_JIM_ATTEMPTS[vVIN] = 1
						else
							SLIM_JIM_ATTEMPTS[vVIN] = SLIM_JIM_ATTEMPTS[vVIN] + 1
						end
						plsr.Notification:Error("It Was too Difficult and It Didn't Work")
					end,
				}, {
					useWhileDead = false,
					vehicle = false,
					controlDisables = {
						disableMovement = true,
						disableCarMovement = true,
						disableMouse = false,
						disableCombat = true,
					},
				})
			end
		else
			plsr.Notification:Error("You Cannot Slimjim This Vehicle", 3000, 'key')
		end
	end,
	LockpickExterior = function(self, config, canUnlockOwned, vehicle, cb)
		local vehEnt = plsr.State.Entity(vehicle)
		local val = GetVehicleHandlingInt(vehicle, "CHandlingData", "nMonetaryValue")

		local team = plsr.State.character.Team

		if
			not vehEnt.towObjective
			and not plsr.Police:IsPdCar(vehicle)
			and not vehEnt.noLockpick
			and (not vehEnt.boostVehicle or vehEnt.boostVehicle == team)
		then
			do
				-- VIN is optional: ambient/traffic vehicles never get a DB VIN, only ones a player has entered/owned do.
				-- Lock state falls back to the native door-lock status so a never-touched ambient car still works.
				local vVIN = vehEnt.VIN
				local isServerVehicle = vVIN ~= nil

				if isServerVehicle and plsr.Vehicles.Keys:Has(vVIN, vehEnt.GroupKeys) then
					plsr.Notification:Error("You Already Have Keys To This Vehicle", 3000, 'key')
					return cb(false)
				end

				local nativeLocked = GetVehicleDoorLockStatus(vehicle) >= 2
				if not vehEnt.Locked and not nativeLocked then
					plsr.Notification:Error("This Vehicle Is Already Unlocked", 3000, 'key')
					return cb(false)
				end

				local alerted = false
				local startCoords = GetEntityCoords(GLOBAL_PED)
				TaskTurnPedToFaceEntity(GLOBAL_PED, vehicle, 500)
	
				local dumbAnim = true
				RequestAnimDict("veh@break_in@0h@p_m_one@")
				while not HasAnimDictLoaded("veh@break_in@0h@p_m_one@") do
					Wait(5)
				end

				TriggerEvent("Laptop:Client:LSUnderground:Boosting:AttemptExterior", vehicle)
	
				CreateThread(function()
					while dumbAnim do
						TaskPlayAnim(
							GLOBAL_PED,
							"veh@break_in@0h@p_m_one@",
							"low_force_entry_ds",
							1.0,
							1.0,
							1.0,
							16,
							0.0,
							0,
							0,
							0
						)
						Wait(1000)
					end
				end)
	
				local wasFailed = false
				for k, v in ipairs(config.stages) do
					local alarmRoll = math.random(100)
					if alarmRoll <= 20 then
						SetVehicleAlarm(vehicle, true)
						SetVehicleAlarmTimeLeft(vehicle, math.random(25, 40) * 100)
						StartVehicleAlarm(vehicle)
						if not alerted and not plsr.State.Entity(vehicle).boostVehicle then
							plsr.EmergencyAlerts:CreateIfReported(200.0, "lockpickext", true)
							alerted = true
						end
					end
	
					local stageComplete = false
					if wasFailed then
						break
					end
	
					plsr.Minigame.Play:RoundSkillbar(v, config.base - k, {
						onSuccess = function()
							Wait(400)
							stageComplete = true
						end,
						onFail = function()
							wasFailed = true
							stageComplete = true
						end,
					}, {
						useWhileDead = false,
						vehicle = false,
						controlDisables = {
							disableMovement = true,
							disableCarMovement = true,
							disableMouse = false,
							disableCombat = true,
						},
						animation = {
							animDict = "veh@break_in@0h@p_m_one@",
							anim = "low_force_entry_ds",
							flags = 16,
						},
					})
	
					while not stageComplete do
						Wait(1)
					end
				end
	
				dumbAnim = false
				ClearPedTasks(GLOBAL_PED)
	
				if not wasFailed then
					if #(startCoords - GetEntityCoords(GLOBAL_PED)) <= 2.0 and #(GetEntityCoords(vehicle) - GetEntityCoords(GLOBAL_PED)) <= 5.0 then
						SetVehicleHasBeenOwnedByPlayer(vehicle, true)
						SetEntityAsMissionEntity(vehicle, true, true)

						if isServerVehicle then
							if vehEnt.Owned and not canUnlockOwned then
								plsr.Notification:Error("It Was Too Hard", 3000, 'key')
								return cb(true, false)
							end

							plsr.Callbacks:ServerCallback("Vehicles:BreakOpenLock", {
								netId = VehToNet(vehicle),
							}, function(success)
								if success then
									plsr.Notification:Success("Vehicle Unlocked", 3000, "key")
								end
							end)
						else
							SetVehicleDoorsLocked(vehicle, 1)
							vehEnt.Locked = false
							plsr.Notification:Success("Vehicle Unlocked", 3000, "key")
						end

						cb(true, true)
					else
						plsr.Notification:Error("Too Far")

						cb(false, false)
					end
				else
					cb(true, false)
				end
			end
		else
			plsr.Notification:Error("You Cannot Lockpick This Vehicle", 3000, 'key')
			cb(false, false)
		end
	end,
	Lockpick = function(self, config, canUnlockOwned, cb)
		local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)
		local team = plsr.State.character.Team

		if
			not vehEnt.towObjective
			and not vehEnt.noLockpick
			and (not vehEnt.boostVehicle or vehEnt.boostVehicle == team)
		then
			do
				-- VIN is optional: ambient/traffic vehicles never get a DB VIN, only ones a player has entered/owned do
				local vVIN = vehEnt.VIN
				local isServerVehicle = vVIN ~= nil

				if isServerVehicle and plsr.Vehicles.Keys:Has(vVIN, vehEnt.GroupKeys) then
					plsr.Notification:Error("You Already Have Keys To This Vehicle", 3000, 'key')
					return cb(false, false)
				end

				local alerted = false
				local wasFailed = false

				for k, v in ipairs(config.stages) do
					local alarmRoll = math.random(100)
					if alarmRoll <= 20 then
						SetVehicleAlarm(VEHICLE_INSIDE, true)
						SetVehicleAlarmTimeLeft(VEHICLE_INSIDE, math.random(15, 30) * 100)
						StartVehicleAlarm(VEHICLE_INSIDE)
						if not alerted and not plsr.State.Entity(VEHICLE_INSIDE).boostVehicle then
							if plsr.EmergencyAlerts:CreateIfReported(200.0, "lockpickint", true) then
								TriggerServerEvent('Radar:Server:StolenVehicle', GetVehicleNumberPlateText(VEHICLE_INSIDE))
							end
							alerted = true
						end
					end

					local stageComplete = false
					if wasFailed then
						break
					end

					plsr.Minigame.Play:RoundSkillbar(v, config.base - k, {
						onSuccess = function()
							Wait(400)
							stageComplete = true
						end,
						onFail = function()
							wasFailed = true
							stageComplete = true
						end,
					}, {
						useWhileDead = false,
						vehicle = true,
						controlDisables = {
							disableMovement = true,
							disableCarMovement = true,
							disableMouse = false,
							disableCombat = true,
						},
						animation = {
							animDict = "veh@break_in@0h@p_m_one@",
							anim = "low_force_entry_ds",
							flags = 16,
						},
					})

					while not stageComplete do
						Wait(1)
					end
				end

				if not wasFailed then
					if VEHICLE_INSIDE and VEHICLE_SEAT == -1 then
						SetVehicleHasBeenOwnedByPlayer(VEHICLE_INSIDE, true)
						SetEntityAsMissionEntity(VEHICLE_INSIDE, true, true)

						if isServerVehicle then
							if vehEnt.Owned and not canUnlockOwned then
								plsr.Notification:Error("It Was Too Hard", 3000, 'key')
								return cb(true, false)
							end

							plsr.Callbacks:ServerCallback("Vehicles:GetKeys", vVIN, function(success)
								plsr.Notification:Success("Lockpicked Vehicle Ignition", 3000, 'key')
								plsr.Action:Show('engine', '{keybind}toggle_engine{/keybind} Turn Engine On')
								_actionShowing = true

								TriggerEvent("Laptop:Client:LSUnderground:Boosting:SuccessIgnition", VEHICLE_INSIDE)
							end)
						else
							plsr.Vehicles.Engine:Force(VEHICLE_INSIDE, true)
							plsr.Notification:Success("Hotwired Vehicle", 3000, 'key')
							TriggerEvent("Laptop:Client:LSUnderground:Boosting:SuccessIgnition", VEHICLE_INSIDE)
						end

						cb(true, true)
					else
						cb(true, false)
					end
				else
					cb(true, false)
				end
			end
		else
			plsr.Notification:Error("You Cannot Lockpick This Vehicle", 3000, 'key')
			cb(false, false)
		end
	end,
	HackExterior = function(self, hackData, canUnlockOwned, vehicle, cb)
		local vehEnt = plsr.State.Entity(vehicle)
		local val = GetVehicleHandlingInt(vehicle, "CHandlingData", "nMonetaryValue")
		local team = plsr.State.character.Team

		if
			not vehEnt.towObjective
			and not vehEnt.noLockpick
			and (not vehEnt.boostVehicle or vehEnt.boostVehicle == team)
		then
			if vehEnt and vehEnt.VIN then
				local startCoords = GetEntityCoords(GLOBAL_PED)
				TaskTurnPedToFaceEntity(GLOBAL_PED, vehicle, 500)
				TriggerEvent("Laptop:Client:LSUnderground:Boosting:AttemptExterior", vehicle)
	
				plsr.Minigame.Play:Pattern(
					3,
					hackData.duration,
					hackData.rows,
					hackData.length,
					hackData.charSize,
					hackData.charSet or false, {
					onSuccess = function()
						if #(startCoords - GetEntityCoords(GLOBAL_PED)) <= 2.0 then
							SetVehicleHasBeenOwnedByPlayer(vehicle, true)
							SetEntityAsMissionEntity(vehicle, true, true)

							plsr.Callbacks:ServerCallback("Vehicles:BreakOpenLock", {
								netId = VehToNet(vehicle),
							}, function(success)
								if success then
									plsr.Notification:Success("Vehicle Unlocked", 3000, "key")
								end
							end)
		
							cb(true, true)
						else
							plsr.Notification:Error("Too Far")
		
							cb(false, false)
						end
					end,
					onFail = function()
						cb(true, false)
					end,
				}, {
					useWhileDead = false,
					vehicle = false,
					controlDisables = {
						disableMovement = true,
						disableCarMovement = true,
						disableMouse = false,
						disableCombat = true,
					},
					animation = {
						animDict = "amb@medic@standing@kneel@base",
						anim = "base",
						flags = 16,
					},
				})
			end
		else
			plsr.Notification:Error("You Cannot Lockpick This Vehicle", 3000, 'key')
		end
	end,
	Hack = function(self, hackData, canUnlockOwned, cb)
		local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)
		local val = GetVehicleHandlingInt(VEHICLE_INSIDE, "CHandlingData", "nMonetaryValue")
		local team = plsr.State.character.Team

		if
			not vehEnt.towObjective
			and not vehEnt.noLockpick
			and (not vehEnt.boostVehicle or vehEnt.boostVehicle == team)
		then
			if vehEnt and vehEnt.VIN then
				local startCoords = GetEntityCoords(GLOBAL_PED)
				TaskTurnPedToFaceEntity(GLOBAL_PED, VEHICLE_INSIDE, 500)
	
				plsr.Minigame.Play:Pattern(
					3,
					hackData.duration,
					hackData.rows,
					hackData.length,
					hackData.charSize,
					hackData.charSet or false, {
					onSuccess = function()
						if VEHICLE_INSIDE and VEHICLE_SEAT == -1 then
							SetVehicleHasBeenOwnedByPlayer(VEHICLE_INSIDE, true)
							SetEntityAsMissionEntity(VEHICLE_INSIDE, true, true)
							if vehEnt.Owned and not canUnlockOwned then
								plsr.Notification:Error("It Was Too Hard", 3000, 'key')
								return cb(true, false)
							end

							plsr.Callbacks:ServerCallback("Vehicles:GetKeys", vehEnt.VIN, function(success)
								plsr.Notification:Success("Vehicle Ignition Bypassed", 3000, 'key')
								plsr.Action:Show('engine', '{keybind}toggle_engine{/keybind} Turn Engine On')
								_actionShowing = true

								TriggerEvent("Laptop:Client:LSUnderground:Boosting:SuccessIgnition", VEHICLE_INSIDE)
							end)
		
							cb(true, true)
						else
							cb(true, false)
						end
					end,
					onFail = function()
						cb(true, false)
					end,
				}, {
					useWhileDead = false,
					vehicle = true,
					controlDisables = {
						disableMovement = true,
						disableCarMovement = true,
						disableMouse = false,
						disableCombat = true,
					},
					animation = {
						animDict = "veh@break_in@0h@p_m_one@",
						anim = "low_force_entry_ds",
						flags = 16,
					},
				})
			end
		else
			plsr.Notification:Error("You Cannot Lockpick This Vehicle", 3000, 'key')
		end
	end,
	CanBeStored = function(self, vehicle)
		local vehicleCoords = GetEntityCoords(vehicle)
		local inVehicleStorageZone, vehicleStorageZoneId = GetVehicleStorageAtCoords(vehicleCoords)
		return inVehicleStorageZone or plsr.Properties:GetNearHouseGarage(vehicleCoords)
	end,
	Properties = {
		Get = function(self, vehicle)
			return GetVehicleProperties(vehicle)
		end,
		Set = function(self, vehicle, data)
			return SetVehicleProperties(vehicle, data)
		end,
	},
	Utils = {
		IsCloseToRearOfVehicle = function(self, vehicle, coords)
			if not coords then
				coords = plsr.State.flags.position
			end

			return IsCloseToFrontOfVehicle(vehicle, coords)
		end,
		IsCloseToFrontOfVehicle = function(self, vehicle, coords)
			if not coords then
				coords = plsr.State.flags.position
			end

			return IsCloseToRearOfVehicle(vehicle, coords)
		end,
		IsCloseToVehicle = function(self, vehicle, coords)
			if not coords then
				coords = plsr.State.flags.position
			end

			return IsCloseToVehicle(vehicle, coords)
		end,
	},
	Class = {
		Get = function(self, entity)
            if GetVehicleClass(entity) == 15 or GetVehicleClass(entity) == 16 or GetVehicleClass(entity) == 19 then
                return "S"
            end

			local value = GetVehicleHandlingInt(entity, "CHandlingData", "nMonetaryValue")
			for k, v in pairs(_vehicleClasses) do
				if value == v.value then
					return k
				end
			end

			return "D"
		end,
		IsClass = function(self, entity, class)
			local entClass = Vehicle.Class:Get(entity)
			return entClass == class 
		end,
		IsClassOrHigher = function(self, entity, class)
			return _vehicleClasses[Vehicle.Class:Get(entity)].value >= _vehicleClasses[class]?.value or 10000
		end,
	}
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["pulsar_core"]:RegisterComponent("Vehicles", VEHICLE)
end)

AddEventHandler("Vehicles:Client:EnterVehicle", function(veh)
	local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)

	TriggerEvent("Vehicles:Client:Seatbelt", false)

	Wait(1000)

	TriggerEvent("Vehicles:Client:Ignition", vehEnt.VEH_IGNITION)
end)

AddEventHandler('Vehicles:Client:BecameDriver', function(veh, seat)
	local vehClass = plsr.Vehicles.Class:Get(VEHICLE_INSIDE)
    local vehEnt = plsr.State.Entity(VEHICLE_INSIDE)

    if vehEnt.VEH_IGNITION == nil then
        plsr.Vehicles.Engine:Force(VEHICLE_INSIDE, GetIsVehicleEngineRunning(VEHICLE_INSIDE))
	else
		plsr.Vehicles.Engine:Force(VEHICLE_INSIDE, vehEnt.VEH_IGNITION)
    end

    if GetVehicleClass(VEHICLE_INSIDE) == 13 then
        plsr.Vehicles.Engine:Force(VEHICLE_INSIDE, true)
    end

    while IsVehicleNeedsToBeHotwired(VEHICLE_INSIDE) do
        Wait(0)
        SetVehicleNeedsToBeHotwired(VEHICLE_INSIDE, false)
    end

	SetVehRadioStation(VEHICLE_INSIDE, "OFF")

    if vehEnt.VEH_IGNITION then
        if not vehEnt.PlayerDriven then -- It was stolen directly with a ped in it, get keys
            plsr.Vehicles.Engine:Force(VEHICLE_INSIDE, true)
            plsr.Callbacks:ServerCallback('Vehicles:GetKeys', vehEnt.VIN, function()
                plsr.Notification:Success('You found the keys in the vehicle', 3000, 'key')
            end)
        end
    else
        if plsr.Vehicles.Keys:Has(vehEnt.VIN, vehEnt.GroupKeys) then
            plsr.Action:Show('engine', '{keybind}toggle_engine{/keybind} Turn Engine On')
            _actionShowing = true
        end
    end

	if not vehEnt.PlayerDriven then
		vehEnt.PlayerDriven = true
	end

	vehEnt.LastDriven = GetCloudTimeAsInt()
end)

AddEventHandler('Vehicles:Client:ExitVehicle', function(veh)
	if _actionShowing then
		plsr.Action:Hide('engine')
		_actionShowing = false
	end

    if veh and DoesEntityExist(veh) then
        local sb = plsr.State.Entity(veh)
        if sb and sb.VEH_IGNITION then
            SetVehicleEngineOn(veh, true, true, true)
        else
            SetVehicleEngineOn(veh, false, true, true)
        end
    end
end)

AddEventHandler("Vehicles:Client:InspectVIN", function(entityData)
	if entityData?.entity then
		if plsr.Vehicles:HasAccess(entityData.entity) then
			plsr.Progress:Progress({
				name = "inspect_vin",
				duration = 4000,
				label = "Inspecting VIN",
				useWhileDead = false,
				canCancel = true,
				ignoreModifier = true,
				controlDisables = {
					disableMovement = true,
					disableCarMovement = true,
					disableMouse = false,
					disableCombat = true,
				},
				animation = {
					anim = "tablet2",
				},
			}, function(cancelled)
				if not cancelled then
					TriggerServerEvent("Vehicle:Server:InspectVIN", VehToNet(entityData.entity))
				end
			end)
		end
	end
end)

RegisterNetEvent("Vehicles:Client:ViewVIN", function(VIN)
	plsr.ListMenu:Show({
		main = {
			label = 'VIN Inspection',
			items = {
				{
					label = 'Vehicle Identification Number',
					description = VIN,
				},
			},
		},
	})
end)

RegisterNetEvent("Vehicles:Client:AttemptSlimJim", function()
	if not VEHICLE_INSIDE and _characterLoaded then
		local target = plsr.Targeting:GetEntityPlayerIsLookingAt()
		if
			target
			and target.entity
			and DoesEntityExist(target.entity)
			and IsEntityAVehicle(target.entity)
			and IsThisModelACar(GetEntityModel(target.entity))
			and #(GetEntityCoords(target.entity) - GetEntityCoords(GLOBAL_PED)) <= 2.0
		then
			plsr.Vehicles:SlimJim(target.entity)
		end
	end
end)

-- proximity-based search instead of a crosshair raycast: player just needs to be near a locked vehicle, not aimed precisely at it
local function findNearestLockedVehicle(maxDist)
	local pedCoords = GetEntityCoords(GLOBAL_PED)
	local closest, closestDist = nil, maxDist or 3.5
	for _, vehicle in ipairs(GetGamePool("CVehicle")) do
		if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
			local dist = #(GetEntityCoords(vehicle) - pedCoords)
			local vehEnt = plsr.State.Entity(vehicle)
			local isLocked = vehEnt.Locked or GetVehicleDoorLockStatus(vehicle) >= 2
			if dist < closestDist and isLocked then
				closest = vehicle
				closestDist = dist
			end
		end
	end
	return closest
end

AddEventHandler("Vehicles:Client:StartUp", function()
	plsr.Callbacks:RegisterClientCallback("Vehicles:Slimjim", function(data, cb)
		print("Vehicles:Slimjim")
		if _characterLoaded and plsr.State.flags.onDuty == "police" then
			if not VEHICLE_INSIDE then
				local target = plsr.Targeting:GetEntityPlayerIsLookingAt()
				if
					target
					and target.entity
					and DoesEntityExist(target.entity)
					and IsEntityAVehicle(target.entity)
					and #(GetEntityCoords(target.entity) - GetEntityCoords(GLOBAL_PED)) <= 2.0
				then
					local vehClass = _vehicleClasses.C
					if vehClass?.advLockpick then
						plsr.Vehicles:LockpickExterior(vehClass.advLockpick.exterior, data, target.entity, cb)
					else
						plsr.Notification:Error("Cannot Slimjim This Vehicle")
					end
				else
					print('nope2')
					cb(false, false)
				end
			end
		else
			print('nope')
			cb(false, false)
		end
	end)

	plsr.Callbacks:RegisterClientCallback("Vehicles:Lockpick", function(data, cb)
		if _characterLoaded then
			if VEHICLE_INSIDE then
				if VEHICLE_SEAT == -1 then
					local vehClass = _vehicleClasses[plsr.Vehicles.Class:Get(VEHICLE_INSIDE)]

					local boostOverride = plsr.State.Entity(VEHICLE_INSIDE).boostForceHack

					if vehClass?.lockpick and not boostOverride then
						plsr.Vehicles:Lockpick(vehClass.lockpick.interior, data, cb)
					else
						plsr.Notification:Error("Cannot Lockpick This Vehicle")
					end
				else
					cb(false, false)
				end
			else
				local vehicle = findNearestLockedVehicle(3.5)
				if vehicle then
					local vehClass = _vehicleClasses[plsr.Vehicles.Class:Get(vehicle)]
					local boostOverride = plsr.State.Entity(vehicle).boostForceHack

					if vehClass?.lockpick and not boostOverride then
						plsr.Vehicles:LockpickExterior(vehClass.lockpick.exterior, data, vehicle, cb)
					else
						plsr.Notification:Error("Cannot Lockpick This Vehicle")
					end
				else
					plsr.Notification:Error("No Locked Vehicle Nearby", 3000, 'key')
					cb(false, false)
				end
			end
		else
			cb(false, false)
		end
	end)

	plsr.Callbacks:RegisterClientCallback("Vehicles:AdvLockpick", function(data, cb)
		if _characterLoaded then
			if VEHICLE_INSIDE then
				if VEHICLE_SEAT == -1 then
					local vehClass = _vehicleClasses[plsr.Vehicles.Class:Get(VEHICLE_INSIDE)]

					local boostOverride = plsr.State.Entity(VEHICLE_INSIDE).boostForceHack

					if vehClass?.advLockpick and not boostOverride then
						plsr.Vehicles:Lockpick(vehClass.advLockpick.interior, data, cb)
					else
						plsr.Notification:Error("Cannot Lockpick This Vehicle")
					end
				else
					cb(false, false)
				end
			else
				local vehicle = findNearestLockedVehicle(3.5)
				if vehicle then
					local vehClass = _vehicleClasses[plsr.Vehicles.Class:Get(vehicle)]
					local boostOverride = plsr.State.Entity(vehicle).boostForceHack

					if vehClass?.advLockpick and not boostOverride then
						plsr.Vehicles:LockpickExterior(vehClass.advLockpick.exterior, data, vehicle, cb)
					else
						plsr.Notification:Error("Cannot Lockpick This Vehicle")
					end
				else
					plsr.Notification:Error("No Locked Vehicle Nearby", 3000, 'key')
					cb(false, false)
				end
			end
		else
			cb(false, false)
		end
	end)

	plsr.Callbacks:RegisterClientCallback("Vehicles:Hack", function(data, cb)
		if _characterLoaded then
			if VEHICLE_INSIDE then
				if VEHICLE_SEAT == -1 then
					local vehClass = _vehicleClasses[plsr.Vehicles.Class:Get(VEHICLE_INSIDE)]
					if vehClass?.hack then
						plsr.Vehicles:Hack(vehClass?.hack.interior, data, cb)
					else
						plsr.Notification:Error("Cannot Hack This Vehicle")
					end
				else
					cb(false, false)
				end
			else
				local target = plsr.Targeting:GetEntityPlayerIsLookingAt()
				if
					target
					and target.entity
					and DoesEntityExist(target.entity)
					and IsEntityAVehicle(target.entity)
					and #(GetEntityCoords(target.entity) - GetEntityCoords(GLOBAL_PED)) <= 2.0
				then
					local vehClass = _vehicleClasses[plsr.Vehicles.Class:Get(target.entity)]
					if vehClass?.hack then
						plsr.Vehicles:HackExterior(vehClass.hack.exterior, data, target.entity, cb)
					else
						plsr.Notification:Error("Cannot Hack This Vehicle")
					end
				else
					cb(false, false)
				end
			end
		else
			cb(false, false)
		end
	end)

	plsr.Callbacks:RegisterClientCallback("Vehicles:AdvHack", function(data, cb)
		if _characterLoaded then
			if VEHICLE_INSIDE then
				if VEHICLE_SEAT == -1 then
					local vehClass = _vehicleClasses[plsr.Vehicles.Class:Get(VEHICLE_INSIDE)]
					if vehClass?.advHack then
						plsr.Vehicles:Hack(vehClass?.advHack.interior, data, cb)
					else
						plsr.Notification:Error("Cannot Hack This Vehicle")
					end
				else
					cb(false, false)
				end
			else
				local target = plsr.Targeting:GetEntityPlayerIsLookingAt()
				if
					target
					and target.entity
					and DoesEntityExist(target.entity)
					and IsEntityAVehicle(target.entity)
					and #(GetEntityCoords(target.entity) - GetEntityCoords(GLOBAL_PED)) <= 2.0
				then
					local vehClass = _vehicleClasses[plsr.Vehicles.Class:Get(target.entity)]
					if vehClass?.advHack then
						plsr.Vehicles:HackExterior(vehClass.advHack.exterior, data, target.entity, cb)
					else
						plsr.Notification:Error("Cannot Hack This Vehicle")
					end
				else
					cb(false, false)
				end
			end
		else
			cb(false, false)
		end
	end)
end)
