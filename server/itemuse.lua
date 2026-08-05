function RegisterItemUses()
	plsr.Inventory.Items:RegisterUse("lockpick", "Vehicles", function(source, slot, itemData)
		Citizen.SetTimeout(500, function()
			plsr.Callbacks:ClientCallback(source, "Vehicles:Lockpick", true, function(using, success)
				if using then
					local newValue = slot.CreateDate - (60 * 60 * 24)
					if success then
						newValue = slot.CreateDate - (60 * 60 * 12)
					end
					if (os.time() - itemData.durability >= newValue) then
						plsr.Inventory.Items:RemoveId(slot.Owner, slot.invType, slot)
					else
						plsr.Inventory:SetItemCreateDate(slot.id, newValue)
					end
				end
			end)
		end)
	end)

	plsr.Inventory.Items:RegisterUse("adv_lockpick", "Vehicles", function(source, slot, itemData)
		Citizen.SetTimeout(500, function()
			plsr.Callbacks:ClientCallback(source, "Vehicles:AdvLockpick", true, function(using, success)
				if using then
					local newValue = slot.CreateDate - (60 * 60 * 24)
					if success then
						newValue = slot.CreateDate - (60 * 60 * 12)
					end
					if (os.time() - itemData.durability >= newValue) then
						plsr.Inventory.Items:RemoveId(slot.Owner, slot.invType, slot)
					else
						plsr.Inventory:SetItemCreateDate(slot.id, newValue)
					end
				end
			end)
		end)
	end)

	plsr.Inventory.Items:RegisterUse("electronics_kit", "Vehicles", function(source, slot, itemData)
		Citizen.SetTimeout(500, function()
			plsr.Callbacks:ClientCallback(source, "Vehicles:Hack", true, function(using, success)
				if using then
					local newValue = slot.CreateDate - (60 * 60 * 24)
					if success then
						newValue = slot.CreateDate - (60 * 60 * 12)
					end
					if (os.time() - itemData.durability >= newValue) then
						plsr.Inventory.Items:RemoveId(slot.Owner, slot.invType, slot)
					else
						plsr.Inventory:SetItemCreateDate(slot.id, newValue)
					end
				end
			end)
		end)
	end)

	plsr.Inventory.Items:RegisterUse("adv_electronics_kit", "Vehicles", function(source, slot, itemData)
		Citizen.SetTimeout(500, function()
			plsr.Callbacks:ClientCallback(source, "Vehicles:AdvHack", true, function(using, success)
				if using then
					local newValue = slot.CreateDate - (60 * 60 * 24)
					if success then
						newValue = slot.CreateDate - (60 * 60 * 12)
					end
					if (os.time() - itemData.durability >= newValue) then
						plsr.Inventory.Items:RemoveId(slot.Owner, slot.invType, slot)
					else
						plsr.Inventory:SetItemCreateDate(slot.id, newValue)
					end
				end
			end)
		end)
	end)

	plsr.Inventory.Items:RegisterUse("screwdriver", "Vehicles", function(source, slot, itemData)
		Citizen.SetTimeout(1500, function()
			plsr.Callbacks:ClientCallback(source, "Vehicles:Lockpick", {
				{
					base = 4000,
					mod = 900,
				},
				{
	
					base = 3500,
					mod = 900,
				},
				false
			}, function(using, success)
				if using then
					local newValue = slot.CreateDate - (60 * 60 * 24)
					if success then
						newValue = slot.CreateDate - (60 * 60 * 12)
					end
					if (os.time() - itemData.durability >= newValue) then
						plsr.Inventory.Items:RemoveId(slot.Owner, slot.invType, slot)
					else
						plsr.Inventory:SetItemCreateDate(slot.id, newValue)
					end
				end
			end)
		end)
	end)

	plsr.Inventory.Items:RegisterUse("repairkit", "Vehicles", function(source, itemData)
		plsr.Callbacks:ClientCallback(source, "Vehicles:RepairKit", false, function(success)
			if success then
				plsr.Inventory.Items:RemoveSlot(itemData.Owner, itemData.Name, 1, itemData.Slot, itemData.invType)
			end
		end)
	end)

	plsr.Inventory.Items:RegisterUse("repairkitadv", "Vehicles", function(source, itemData)
		plsr.Callbacks:ClientCallback(source, "Vehicles:RepairKit", true, function(success)
			if success then
				plsr.Inventory.Items:RemoveSlot(itemData.Owner, itemData.Name, 1, itemData.Slot, itemData.invType)
			end
		end)
	end)

	plsr.Inventory.Items:RegisterUse("fakeplates", "Vehicles", function(source, itemData)
		local currentMeta = itemData.MetaData or {}
		if not currentMeta.Plate then -- Data needs generating
			local updatingMetaData = {}

			updatingMetaData.Plate = plsr.Vehicles.Identification.Plate:Generate(true)
			updatingMetaData.VIN = plsr.Vehicles.Identification.VIN:GenerateLocal() -- Might not be completely unique but odds are low and idc
			updatingMetaData.OwnerName = plsr.Generator.Name:First() .. " " .. plsr.Generator.Name:Last()
			updatingMetaData.SID = plsr.Sequence:Get("Character")
			updatingMetaData.Vehicle = plsr.Vehicles:RandomName()

			currentMeta = plsr.Inventory:UpdateMetaData(itemData.id, updatingMetaData)
		end

		if not currentMeta.Vehicle then
			currentMeta.Vehicle = plsr.Vehicles:RandomName()

			plsr.Inventory:UpdateMetaData(iitemData.id, {
				Vehicle = currentMeta.Vehicle
			})
		end

		if currentMeta then
			plsr.Callbacks:ClientCallback(source, "Vehicles:GetFakePlateAddingVehicle", {}, function(veh)
				if not veh then
					return
				end
				veh = NetworkGetEntityFromNetworkId(veh)
				if veh and DoesEntityExist(veh) then
					local vehState = plsr.State.Entity(veh)
					if not vehState.VIN then
						return
					end

					local vehicle = plsr.Vehicles.Owned:GetActive(vehState.VIN)
					if not vehicle then
						return
					end
					if not vehicle:GetData("FakePlate") then
						vehicle:SetData("FakePlate", currentMeta.Plate)
						vehicle:SetData("FakePlateData", currentMeta)

						SetVehicleNumberPlateText(veh, currentMeta.Plate)
						vehState.FakePlate = currentMeta.Plate

						plsr.Vehicles.Owned:ForceSave(vehState.VIN)

						plsr.Inventory.Items:RemoveSlot(itemData.Owner, itemData.Name, 1, itemData.Slot, itemData.invType)

						plsr.Execute:Client(source, "Notification", "Success", "Fake Plate Installed")
					else
						plsr.Execute:Client(source, "Notification", "Error", "A Fake Plate is Already Installed")
					end
				end
			end)
		end
	end)

	plsr.Inventory.Items:RegisterUse("carpolish", "Vehicles", function(source, itemData)
		UseCarPolish(source, itemData, 1)
	end)

	plsr.Inventory.Items:RegisterUse("carpolish_high", "Vehicles", function(source, itemData)
		UseCarPolish(source, itemData, 2)
	end)

	plsr.Inventory.Items:RegisterUse("carclean", "Vehicles", function(source, itemData)
		TriggerClientEvent("Vehicles:Client:CleaningKit", source)
	end)

	plsr.Inventory.Items:RegisterUse("purgecontroller", "Vehicles", function(source, itemData)
		UsePurgeColorController(source, itemData)
	end)

	plsr.Inventory.Items:RegisterUse("car_bomb", "Vehicles", function(source, itemData)
		plsr.Callbacks:ClientCallback(source, "Vehicles:UseCarBomb", {}, function(veh, reason, config)
			if not veh then
				if reason then
					plsr.Execute:Client(source, "Notification", "Error", reason)
				end
				return
			end
			veh = NetworkGetEntityFromNetworkId(veh)
			if veh and DoesEntityExist(veh) then
				local char = plsr.Fetch:CharacterSource(source)
				if char then
					local vehState = plsr.State.Entity(veh)
					if not vehState.VIN then
						return
					end

					if not vehState.CarBomb then
						vehState.CarBomb = {
							Speed = config.minSpeed,
							Removal = config.removalTime,
							ExplosionTicks = config.preExplosionTicks,
							InstalledBy = char:GetData("SID"),
						}

						plsr.Inventory.Items:RemoveSlot(itemData.Owner, itemData.Name, 1, itemData.Slot, itemData.invType)

						plsr.Execute:Client(source, "Notification", "Success", "Car Bomb Installed")
					else
						plsr.Execute:Client(source, "Notification", "Error", "Vehicle Already Has Car Bomb")
					end
				else
					plsr.Execute:Client(source, "Notification", "Error", "Error Installing Car Bomb")
				end
			end
		end)
	end)

	plsr.Inventory.Items:RegisterUse("harness", "Vehicles", function(source, itemData)
		plsr.Callbacks:ClientCallback(source, "Vehicles:InstallHarness", {}, function(veh)
			if not veh then
				return
			end
			veh = NetworkGetEntityFromNetworkId(veh)
			if veh and DoesEntityExist(veh) then
				local vehState = plsr.State.Entity(veh)
				if not vehState.VIN then
					return
				end

				if plsr.Inventory.Items:RemoveSlot(itemData.Owner, itemData.Name, 1, itemData.Slot, itemData.invType) then
					vehState.Harness = 10
					plsr.Execute:Client(source, "Notification", "Success", "Harness Installed")
				end
			end
		end)
	end)

	plsr.Inventory.Items:RegisterUse("nitrous", "Vehicles", function(source, itemData)
		if itemData?.MetaData?.Nitrous and itemData?.MetaData?.Nitrous > 0 then
			plsr.Callbacks:ClientCallback(source, "Vehicles:InstallNitrous", {}, function(veh)
				if not veh then
					return
				end
				veh = NetworkGetEntityFromNetworkId(veh)
				if veh and DoesEntityExist(veh) then
					local vehState = plsr.State.Entity(veh)
					if not vehState.VIN then
						return
					end

					if plsr.Inventory.Items:RemoveId(itemData.Owner, itemData.invType, itemData) then
						vehState.Nitrous = itemData.MetaData.Nitrous + 0.0
						plsr.Execute:Client(source, "Notification", "Success", "Nitrous Oxide Installed")
					end
				end
			end)
		else
			plsr.Execute:Client(source, "Notification", "Error", "The Bottle is Empty!")
		end
	end)
end

local polishTypes = {
	{ -- Normal Polish
		length = (60 * 60 * 24 * 7), -- Lasts for a week
		multiplier = 10.0,
	},
	{ -- High Polish
		length = (60 * 60 * 24 * 14), -- Lasts for 2 weeks
		multiplier = 15.0,
	}
}

function UseCarPolish(source, itemData, type)
	local typeData = polishTypes[type]
	if not type then return end

	plsr.Callbacks:ClientCallback(source, "Vehicles:UseCarPolish", {}, function(veh)
		if not veh then
			return
		end
		veh = NetworkGetEntityFromNetworkId(veh)
		if veh and DoesEntityExist(veh) then
			local vehState = plsr.State.Entity(veh)
			if not vehState.VIN then
				return
			end

			if (not vehState.Polish) or (vehState.Polish?.Type ~= type) or (vehState.Polish?.Time and (os.time() - vehState.Polish?.Time) >= (60 * 60 * 24)) then
				vehState.Polish = {
					Type = t,
					Expires = os.time() + typeData.length,
					Time = os.time(),
					Mult = typeData.multiplier,
				}

				plsr.Inventory.Items:RemoveSlot(itemData.Owner, itemData.Name, 1, itemData.Slot, itemData.invType)

				plsr.Execute:Client(source, "Notification", "Success", "Polish Applied")
			else
				plsr.Execute:Client(source, "Notification", "Error", "Vehicle Already Has That Polish and It Was Recently Installed")
			end
		end
	end)
end

function UsePurgeColorController(source, itemData)
	plsr.Callbacks:ClientCallback(source, "Vehicles:UsePurgeColorController", {}, function(veh)
		if not veh then
			return
		end
		veh = NetworkGetEntityFromNetworkId(veh)
		if veh and DoesEntityExist(veh) then
			local vehState = plsr.State.Entity(veh)
			if not vehState.VIN then
				return
			end

			plsr.Callbacks:ClientCallback(source, "Vehicles:UsePurgeColorControllerMenu", { purgeColor = vehState?.PurgeColor, purgeLocation = vehState?.PurgeLocation }, function(retval)
				if retval then
					if retval.purgeColor then
						vehState.PurgeColor = {
							r = retval.purgeColor.r,
							g = retval.purgeColor.g,
							b = retval.purgeColor.b,
						}
					end
					if retval.purgeLocation then
						vehState.PurgeLocation = retval.purgeLocation
					end
					plsr.Execute:Client(source, "Notification", "Success", "Purge Changes Applied")
				else
					plsr.Execute:Client(source, "Notification", "Error", "Changes were discarded")
				end
			end)
			
		end
	end)
end

RegisterNetEvent('Vehicles:Server:HarnessDamage', function()
	local src = source
	local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
	if DoesEntityExist(veh) then
		local vehState = plsr.State.Entity(veh)
		if vehState and vehState.VIN and vehState.Harness and vehState.Harness > 0 then
			vehState.Harness = vehState.Harness - 1
		end
	end
end)

RegisterNetEvent('Vehicles:Server:RemoveBomb', function(vNet)
	local veh = NetworkGetEntityFromNetworkId(vNet)
	if veh and DoesEntityExist(veh) then
		local vehState = plsr.State.Entity(veh)
		if vehState and vehState.VIN and vehState.CarBomb then
			vehState.CarBomb = false
		end
	end
end)

RegisterServerEvent('Vehicles:Server:NitrousUsage', function(vNet, used)
	local src = source
    local veh = NetworkGetEntityFromNetworkId(vNet)

    local ent = plsr.State.Entity(veh)
    if ent and ent.Nitrous then
		ent.Nitrous = ent.Nitrous - used
		if ent.Nitrous < 0 then
			ent.Nitrous = 0.0
		end
    end
end)