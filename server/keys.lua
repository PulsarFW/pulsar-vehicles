VEHICLE_KEYS = {}

RegisterServerEvent("Vehicles:Server:StealLocalKeys", function(vehNet)
	local src = source
	local veh = NetworkGetEntityFromNetworkId(vehNet)
	local vehEnt = plsr.State.Entity(veh)
	if vehEnt and vehEnt.VIN then
		plsr.Vehicles.Keys:Give(src, vehEnt.VIN)
	end
end)

_vehKeys = {
	Keys = {
		Has = function(self, source, VIN, groupKeys)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local id = char:GetData('SID')
				if VEHICLE_KEYS[id] == nil then
					return false
				end
				return (VEHICLE_KEYS[id][VIN] or (groupKeys and (plsr.State:Player(source).onDuty == groupKeys or (plsr.State:Player(source).sentOffDuty and plsr.State:Player(source).sentOffDuty == groupKeys))))
			end
			return false
		end,
		Add = function(self, source, VIN)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local id = char:GetData('SID')
				if VEHICLE_KEYS[id] == nil then
					VEHICLE_KEYS[id] = {}
				end
				VEHICLE_KEYS[id][VIN] = true
	
				TriggerClientEvent("Vehicles:Client:UpdateKeys", source, VEHICLE_KEYS[id])
			end
		end,
		Remove = function(self, source, VIN)
			local char = plsr.Fetch:CharacterSource(source)
			if char then
				local id = char:GetData('SID')
				if VEHICLE_KEYS[id] == nil then
					VEHICLE_KEYS[id] = {}
					return
				end
				if plsr.Vehicles.Keys:Has(source, VIN, false) then
					VEHICLE_KEYS[id][VIN] = nil
					TriggerClientEvent("Vehicles:Client:UpdateKeys", source, VEHICLE_KEYS[id])
				end
			end
		end,
		AddBySID = function(self, SID, VIN)
			if VEHICLE_KEYS[SID] == nil then
				VEHICLE_KEYS[SID] = {}
			end

			VEHICLE_KEYS[SID][VIN] = true

			local char = plsr.Fetch:SID(SID)
			if char then
				TriggerClientEvent('Vehicles:Client:UpdateKeys', char:GetData('Source'), VEHICLE_KEYS[SID])
			end
		end
	},
}

AddEventHandler("Proxy:Shared:ExtendReady", function(component)
	if component == "Vehicles" then
		exports["pulsar_core"]:ExtendComponent(component, _vehKeys)
	end
end)
