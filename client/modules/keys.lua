VEHICLE_KEYS = {}

local _lockdelay = false

AddEventHandler("Vehicles:Client:StartUp", function()
	plsr.Callbacks:RegisterClientCallback("Vehicles:Keys:GetVehicleToShare", function(data, cb)
		local playerCoords = GetEntityCoords(GLOBAL_PED)
		local veh = VEHICLE_INSIDE and VEHICLE_INSIDE or GetClosestVehicleWithinRadius(playerCoords, 10.0)
		if DoesEntityExist(veh) then
			local vehEnt = plsr.State.Entity(veh)
			if
				vehEnt
				and vehEnt.VIN
				and plsr.Vehicles.Keys:Has(vehEnt.VIN, vehEnt.GroupKeys)
			then
				if IsPedInAnyVehicle(PlayerPedId(), true) then
					local sids = {}
					for i = -1, GetVehicleModelNumberOfSeats(veh), 1 do
						local ped = GetPedInVehicleSeat(veh, i)
						if ped ~= 0 and ped ~= PlayerPedId() then
							table.insert(sids, GetPlayerServerId(NetworkGetPlayerIndexFromPed(ped)))
						end
					end
					return cb(VehToNet(veh), sids)
				else
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
					return cb(VehToNet(veh), sids)
				end
			else
				cb(false)
			end
		else
			cb(false)
		end
	end)

	plsr.Keybinds:Add("vehicle_lock", "l", "keyboard", "Vehicle - Toggle Door Locks", function()
		if not _lockdelay then
			local veh = VEHICLE_INSIDE and VEHICLE_INSIDE
				or GetClosestVehicleWithinRadius(GetEntityCoords(GLOBAL_PED), 10.0)
			if DoesEntityExist(veh) then
				_lockdelay = true
				Citizen.SetTimeout(1500, function()
					_lockdelay = false
				end)
				plsr.Vehicles:SetLocks(veh)
			end
		end
	end)
end)

AddEventHandler('Vehicles:Client:K9GetInNearestSeat', function(entityData)
	if entityData and DoesEntityExist(entityData.entity) then
		local vehmodel = GetEntityModel(entityData.entity)
		for i = -1, GetVehicleModelNumberOfSeats(vehmodel) do
			if GetPedInVehicleSeat(entityData.entity, i) == 0 then
				TaskWarpPedIntoVehicle(PlayerPedId(), entityData.entity, i)
				Wait(100)
				plsr.Animations.Emotes:Play("dogsitcar", false, false, false)
				return
			end
		end
	end
end)

AddEventHandler('Vehicles:Client:K9LeaveVehicle', function()
	local veh = GetVehiclePedIsIn(PlayerPedId(), false)
	if plsr.State.flags.isK9Ped and veh ~= 0 then
		TaskLeaveVehicle(PlayerPedId(), veh, 16)
		Wait(100)
		local coords = GetEntityCoords(PlayerPedId())
		SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z - 0.4)
		Wait(100)
		plsr.Animations.Emotes:ForceCancel()
	end
end)

RegisterNetEvent("Vehicles:Client:UpdateKeys", function(keys)
	VEHICLE_KEYS = keys
end)

_vehicleKeysExtension = {
	Keys = {
		Has = function(self, VIN, gKeys)
			if VIN and (
				VEHICLE_KEYS[VIN] 
				or (gKeys and (plsr.State.flags.onDuty == gKeys or (plsr.State.flags.sentOffDuty and plsr.State.flags.sentOffDuty == gKeys)))
			) then
				return true
			else
				return false
			end
		end,
	},
	SetLocks = function(self, veh, state)
		if plsr.State.Entity(veh).keepLocked then
			return	
		end

		plsr.Callbacks:ServerCallback("Vehicles:ToggleLocks", {
			netId = NetworkGetNetworkIdFromEntity(veh),
			state = state,
		}, function(success, newState)
			if success then
				UnlockAnim()
				if newState then
					plsr.Notification:Error("Vehicle Locked")
					plsr.Sounds.Do.Play:One("central-locking.ogg", 0.2)
					DoVehicleLockFlash(veh)
				else
					plsr.Notification:Success("Vehicle Unlocked")
					plsr.Sounds.Do.Play:One("central-locking.ogg", 0.2)
					DoVehicleUnlockFlash(veh)
				end
			end
		end)
	end,
	HasAccess = function(self, vehicle, keysOnly, ownedOnly) -- Does the character have access to the vehicle
		if DoesEntityExist(vehicle) then
			local vehEnt = plsr.State.Entity(vehicle)
			if vehEnt.VIN then
				if ownedOnly and not vehEnt.Owned then
					return false
				end

				if not keysOnly and not vehEnt.Locked then
					return true
				end

				if plsr.Vehicles.Keys:Has(vehEnt.VIN, vehEnt.GroupKeys) then
					return true
				end
			end
		end
		return false
	end,
}

AddEventHandler("Proxy:Shared:ExtendReady", function(component)
	if component == "Vehicles" then
		exports["pulsar_core"]:ExtendComponent(component, _vehicleKeysExtension)
	end
end)

AddEventHandler("Vehicles:Client:ToggleLocks", function(entityData)
	if not DoesEntityExist(entityData.entity) then
		return
	end

	plsr.Vehicles:SetLocks(entityData.entity)
end)
