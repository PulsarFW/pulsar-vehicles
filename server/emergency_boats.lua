local boatModels = {
	police = `predator`,
	ems = `dinghy3`,
}

local boatCooldowns = {}

RegisterNetEvent("Vehicles:Server:RequestEmergencyBoat", function(parkingSpace)
	local src = source
	local char = plsr.Fetch:CharacterSource(src)
	local onDuty = plsr.State:Player(src).onDuty
	if
		char
		and (onDuty == "police" or onDuty == "ems")
		and (not boatCooldowns[onDuty] or boatCooldowns[onDuty] <= os.time())
	then
		plsr.Vehicles:SpawnTemp(
			source,
			boatModels[onDuty] or `predator`,
			"boat",
			parkingSpace.xyz,
			parkingSpace.w,
			function(veh, VIN)
				plsr.Vehicles.Keys:Add(src, VIN)

				plsr.State.Entity(veh).GroupKeys = onDuty
				plsr.State.Entity(veh).EmergencyBoat = true

				boatCooldowns[onDuty] = os.time() + (60 * 0.25) -- Will do for now
			end
		)
	else
		plsr.Execute:Client(source, "Notification", "Error", "On Cooldown")
	end
end)

RegisterNetEvent("Vehicles:Server:DeleteEmergencyBoat", function(vNet)
	local src = source
	local char = plsr.Fetch:CharacterSource(src)
	local onDuty = plsr.State:Player(src).onDuty
	if char and (onDuty == "police" or onDuty == "ems") then
		local veh = NetworkGetEntityFromNetworkId(vNet)
		if veh and DoesEntityExist(veh) and plsr.State.Entity(veh).EmergencyBoat then
			plsr.Vehicles:Delete(veh, function() end)

			boatCooldowns[onDuty] = false
		end
	end
end)
