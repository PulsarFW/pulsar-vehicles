local tempTakenPlates = {}

function IsPersonalPlateValid(plate)
    plate = string.upper(plate)

    local res = string.match(plate, "[A-HJ-NPR-Z0-9 ]+", 1)
    local trimmedLength = #plate:gsub(" ", "")

    local addedSpacing = math.floor((8 - trimmedLength) / 2)

    if res and res == plate and trimmedLength >= 4 then
        if trimmedLength < 8 then
            return string.rep(" ", addedSpacing) .. plate .. string.rep(" ", (8 - trimmedLength) - addedSpacing)
        else
            return plate
        end
    end

    return false
end

function IsPersonalPlateTaken(plate)
    if GENERATED_TEMP_PLATES[plate] then
        return true
    end

    if tempTakenPlates[plate] then
        return true
    end

    local test = IsPlateOwned(plate)
    return test
end

function PrivatePlateStuff(char, source, itemData)
    plsr.Callbacks:ClientCallback(source, "Vehicles:GetPersonalPlate", {}, function(veh, plate)
        if not veh or not plate then
            return
        end
        veh = NetworkGetEntityFromNetworkId(veh)
        if veh and DoesEntityExist(veh) then
            local vehState = plsr.State.Entity(veh)
            if not vehState.VIN then
                plsr.Execute:Client(source, "Notification", "Error", "Error")
                return
            end

            local vehicle = plsr.Vehicles.Owned:GetActive(vehState.VIN)
            if not vehicle then
                plsr.Execute:Client(source, "Notification", "Error", "Can't Do It on This Vehicle")
                return
            end

            if vehicle:GetData("FakePlate") then
                plsr.Execute:Client(source, "Notification", "Error", "Can't Do It on This Vehicle")
                return
            end

            local originalPlate = vehicle:GetData("RegisteredPlate")
            local newPlate = IsPersonalPlateValid(plate)

            if not newPlate then
                plsr.Execute:Client(source, "Notification", "Error", "Invalid Plate Formatting")
                return
            end

            if IsPersonalPlateTaken(newPlate) then
                plsr.Execute:Client(source, "Notification", "Error", "That Plate is Taken")
                return
            end

            tempTakenPlates[vehicle:GetData("RegisteredPlate")] = true
            tempTakenPlates[newPlate] = true

            local previousPlateChanges = vehicle:GetData("PreviousPlates") or {}

            table.insert(previousPlateChanges, {
                time = os.time(),
                oldPlate = vehicle:GetData("RegisteredPlate"),
                newPlate = newPlate,
                doneBy = char:GetData("SID")
            })

            vehicle:SetData("PreviousPlates", previousPlateChanges)
            vehicle:SetData("RegisteredPlate", newPlate)
            SetVehicleNumberPlateText(veh, newPlate)
            vehState.Plate = newPlate
            vehState.RegisteredPlate = newPlate

            plsr.Vehicles.Owned:ForceSave(vehState.VIN)
            plsr.Inventory.Items:RemoveSlot(itemData.Owner, itemData.Name, 1, itemData.Slot, itemData.invType)

            plsr.Execute:Client(source, "Notification", "Success", "Personal Plate Setup")
            plsr.Logger:Info('Vehicles', string.format("Personal Plate Change For Vehicle: %s. %s -> %s", vehState.VIN, originalPlate, newPlate))
        else
            plsr.Execute:Client(source, "Notification", "Error", "Error")
        end
    end)
end

function RegisterPersonalPlateCallbacks()
    plsr.Inventory.Items:RegisterUse("personal_plates", "Vehicles", function(source, itemData)
        local char = plsr.Fetch:CharacterSource(source)
        if not char or (plsr.State:Player(source).onDuty ~= "government" and plsr.State:Player(source).onDuty ~= "dgang") then
            plsr.Execute:Client(source, "Notification", "Error", "Error")
            return
        end

        PrivatePlateStuff(char, source, itemData)
	end)

    plsr.Inventory.Items:RegisterUse("personal_plates_donator", "Vehicles", function(source, itemData)
        local char = plsr.Fetch:CharacterSource(source)
        if not char then
            plsr.Execute:Client(source, "Notification", "Error", "Error")
            return
        end

        PrivatePlateStuff(char, source, itemData)
	end)

    plsr.Chat:RegisterAdminCommand("adddonatorplates", function(source, args, rawCommand)
        local license = table.unpack(args)
    
        if license then
            local success = plsr.Vehicles.DonatorPlates:Add(license)
            if success then
                plsr.Chat.Send.System:Single(source, "Successfully Added")
            else
                plsr.Chat.Send.System:Single(source, "Failed")
            end
        end
      end, {
        help = "[Admin] Add donator plates",
        params = {
            {
                name = "Player Identifier",
                help = "Player License",
            },
        },
    }, 1)

    plsr.Chat:RegisterAdminCommand("getdonatorplates", function(source, args, rawCommand)
        local license = table.unpack(args)
    
        if license then
            local success = plsr.Vehicles.DonatorPlates:Check(license)
            if success and success.pending then
                plsr.Chat.Send.System:Single(source, string.format("Player Identifier: %s<br>Pending Plates: %s<br>Redeemed Plates: %s", license, success.pending, success.redeemed or 0))
            else
                plsr.Chat.Send.System:Single(source, "Failed")
            end
        end
      end, {
        help = "[Admin] Check donator plates",
        params = {
            {
                name = "Player Identifier",
                help = "Player License",
            },
        },
    }, 1)

    plsr.Chat:RegisterAdminCommand("removedonatorplates", function(source, args, rawCommand)
        local license = table.unpack(args)
    
        if license then
            local success = plsr.Vehicles.DonatorPlates:Remove(license, 1)
            if success then
                plsr.Chat.Send.System:Single(source, "Successfully Removed")
            else
                plsr.Chat.Send.System:Single(source, "Failed")
            end
        end
      end, {
        help = "[Admin] Remove donator plates",
        params = {
            {
                name = "Player Identifier",
                help = "Player License",
            },
        },
    }, 1)

    plsr.Callbacks:RegisterServerCallback("Vehicles:CheckDonatorPersonalPlates", function(source, data, cb)
        local plyr = plsr.Fetch:Source(source)
        if plyr then
            local res = plsr.Vehicles.DonatorPlates:Check(plyr:GetData("Identifier"))

            cb(res?.pending or 0)
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback("Vehicles:ClaimDonatorPersonalPlates", function(source, data, cb)
        local plyr = plsr.Fetch:Source(source)
        if plyr then
            local char = plsr.Fetch:CharacterSource(source)
            local res = plsr.Vehicles.DonatorPlates:Check(plyr:GetData("Identifier"))

            if char and res?.pending >= data then
                local isRemoved = plsr.Vehicles.DonatorPlates:Remove(plyr:GetData("Identifier"), data)

                if isRemoved then
                    plsr.Inventory:AddItem(char:GetData("SID"), "personal_plates_donator", data, {}, 1)
                    cb(true)

                    plsr.Logger:Warn(
                      "Donator",
                      string.format(
                        "%s [%s] Redeemed %s Donator Plates - Character %s %s (%s)", 
                        plyr:GetData("Name"),
                        plyr:GetData("AccountID"),
                        data,
                        char:GetData('First'),
                        char:GetData('Last'),
                        char:GetData('SID')
                      ),
                      {
                        console = true,
                        file = false,
                        database = true,
                        discord = {
                          embed = true,
                          type = "error",
                          webhook = GetConvar("discord_donation_webhook", ''),
                        }
                      }
                    )
                    return
                end
            end
        else
            cb(false)
        end
    end)
end

-- Citizen.SetTimeout(2500, function()
--     print(IsPersonalPlateValid('FFFF'))
--     print(IsPersonalPlateValid('FFFFF'))
--     print(IsPersonalPlateValid('FFFFFF'))
--     print(IsPersonalPlateValid('FFFFFFF'))
--     print(IsPersonalPlateValid('FFFFFFFF'))
-- end)

_vehDonatorPlates = {
	DonatorPlates = {
		Add = function(self, playerIdentifier)
            local p = promise.new()
            EnsureVehiclesTable(function()
                plsr.Database:Update(
                    "INSERT INTO `donator_plates` (`player`, `pending`) VALUES (?, 1) ON DUPLICATE KEY UPDATE `pending` = `pending` + 1",
                    { playerIdentifier },
                    function(success)
                        p:resolve(success)
                    end
                )
            end)

            return Citizen.Await(p)
        end,
        Check = function(self, playerIdentifier)
            local p = promise.new()
            EnsureVehiclesTable(function()
                plsr.Database:Single("SELECT `player`, `pending`, `redeemed` FROM `donator_plates` WHERE `player` = ?", { playerIdentifier }, function(success, row)
                    p:resolve(success and row or false)
                end)
            end)

            return Citizen.Await(p)
        end,
        Remove = function(self, playerIdentifier, amount)
            local p = promise.new()
            EnsureVehiclesTable(function()
                plsr.Database:Update(
                    "UPDATE `donator_plates` SET `pending` = `pending` - ?, `redeemed` = `redeemed` + ? WHERE `player` = ? AND `pending` >= ?",
                    { amount, amount, playerIdentifier, amount },
                    function(success, updated)
                        p:resolve(success and updated > 0)
                    end
                )
            end)

            return Citizen.Await(p)
        end,
	},
}

AddEventHandler("Proxy:Shared:ExtendReady", function(component)
	if component == "Vehicles" then
		exports["pulsar_core"]:ExtendComponent(component, _vehDonatorPlates)
	end
end)

AddEventHandler("Vehicles:Server:AddDonatorPlates", function(license)
    plsr.Vehicles.DonatorPlates:Add(license)
end)

function TebexAddDonatorPlate(source, args)
	local sid = table.unpack(args)
	sid = tonumber(sid)
	if sid == nil or sid == 0 then
        plsr.Logger:Warn(
			"Donator Plate",
			"Provided SID (server ID) was empty.",
			{
				console = true,
				file = false,
				database = true,
				discord = {
					embed = true,
					type = "error",
					webhook = GetConvar("discord_donation_webhook", ''),
				}
			}
		)
		return
	end
	local player = plsr.Fetch:Source(sid)
	if player then
		local license = player:GetData("Identifier")
		local success = plsr.Vehicles.DonatorPlates:Add(license)
		if success then
			plsr.Chat.Send.System:Single(sid, "Successfully Added")
		else
			plsr.Chat.Send.System:Single(sid, "Failed")
		end
	end  
end
RegisterCommand("tebexadddonatorplate", TebexAddDonatorPlate, true)