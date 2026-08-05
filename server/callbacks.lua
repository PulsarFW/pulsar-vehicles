local _taggedVehs = {}

function RegisterCallbacks()
    plsr.Callbacks:RegisterServerCallback('Vehicles:GetKeys', function(source, VIN, cb)
        plsr.Vehicles.Keys:Add(source, VIN)
        cb(true)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:ToggleLocks', function(source, data, cb)
        local veh = NetworkGetEntityFromNetworkId(data.netId)
        local vehState = plsr.State.Entity(veh)
        if DoesEntityExist(veh) and vehState.VIN and not vehState.wasThermited then
            local groupKeys = vehState.GroupKeys
            if plsr.Vehicles.Keys:Has(source, vehState.VIN, vehState.GroupKeys) then
                local newState = data.state
                if newState == nil then 
                    newState = not vehState.Locked
                end

                vehState.Locked = newState
                SetVehicleDoorsLocked(veh, vehState.Locked and 2 or 1)
                cb(true, vehState.Locked)
            end
        end
        cb(false)
    end)

	plsr.Callbacks:RegisterServerCallback('Vehicles:Server:VehicleMegaphone', function(source, data, cb)
        TriggerClientEvent("VOIP:Client:Megaphone:Use", source, true)
        cb(true)
    end)
	
    plsr.Callbacks:RegisterServerCallback('Vehicles:BreakOpenLock', function(source, data, cb)
        local veh = NetworkGetEntityFromNetworkId(data.netId)
        local vehState = plsr.State.Entity(veh)
        if DoesEntityExist(veh) and vehState.VIN then
            vehState.Locked = false
            SetVehicleDoorsLocked(veh, vehState.Locked and 2 or 1)
            cb(true, vehState.Locked)
        end
        cb(false)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:GetVehiclesInStorage', function(source, storageId, cb)
        local character = plsr.Fetch:CharacterSource(source)
        local storageData = _vehicleStorage[storageId]
        if not character or not storageData then
            cb(false)
            return
        end

        local charJobs = character:GetData('Jobs') or {}
        local fleetFetch = false

        if type(storageData.restricted) ~= 'table' or DoesCharacterPassStorageRestrictions(source, charJobs, storageData.restricted) then
            local myDuty = plsr.State:Player(source).onDuty

            if type(storageData.fleet) == 'table' and myDuty then
                for k, v in ipairs(storageData.fleet) do
                    if v.JobId == myDuty then
                        local jobData = plsr.Jobs.Permissions:HasJob(source, v.JobId, v.WorkplaceId)
                        if jobData then
                            local jobPermissions = plsr.Jobs.Permissions:GetPermissionsFromJob(source, jobData.Id)
                            if jobPermissions then
                                fleetFetch = {
                                    Id = jobData.Id,
                                    Workplace = (jobData.Workplace and jobData.Workplace.Id or false),
                                    Level = GetAllowedFleetVehicleLevelFromJobPermissions(jobPermissions)
                                }
                            end
                        end
                    end
                end
            end

            local characterId = character:GetData('SID')
            plsr.Vehicles.Owned:GetAll(storageData.vehType, 0, characterId, function(vehicles)
                cb(vehicles)
            end, 1, storageId, true, fleetFetch, {
                _id = 0,
                VIN = 1,
                Make = 1,
                Model = 1,
                Type = 1,
                Owner = 1,
                RegisteredPlate = 1,
                GovAssigned = 1,
            })
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:GetVehiclesInStorageSelect', function(source, data, cb)
        if data.VIN then
            plsr.Vehicles.Owned:GetVIN(data.VIN, cb)
        end
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:GetVehiclesInPropertyStorage', function(source, storageId, cb)
        local character = plsr.Fetch:CharacterSource(source)
        if not character then
            cb(false)
            return
        end

        local property = plsr.Properties:Get(storageId)
        local maxParking = plsr.Properties:GetMaxParkingSpaces(storageId)

        if property and property.id and plsr.Properties.Keys:Has(property.id, character:GetData("ID")) and maxParking and maxParking > 0 then
            local characterId = character:GetData('SID')
            plsr.Vehicles.Owned:GetAll(0, false, false, function(vehicles)
                local c = {}
                local charsToFetch = {}

                for k, v in ipairs(vehicles) do
                    if v.Owner and v.Owner.Type == 0 and v.Owner.Id then
                        if not c[v.Owner.Id] then
                            c[v.Owner.Id] = true
                            table.insert(charsToFetch, v.Owner.Id)
                        end
                    end
                end

                local placeholders = {}
                for i = 1, #charsToFetch do
                    table.insert(placeholders, "?")
                end

                plsr.Database:Query(
                    "SELECT `data` FROM `characters` WHERE `sid` IN (" .. table.concat(placeholders, ", ") .. ") AND `deleted` = 0",
                    charsToFetch,
                    function(success, rows)
                    local results = {}
                    if success then
                        for k, row in ipairs(rows) do
                            local ok, decoded = pcall(json.decode, row.data)
                            if ok and type(decoded) == "table" then
                                table.insert(results, decoded)
                            end
                        end
                    end
                    if success and #results > 0 then
                        local dumbShit = {}
                        for k, v in ipairs(results) do
                            dumbShit[v.SID] = v
                        end

                        cb(vehicles, {
                            current = plsr.Vehicles.Owned.Properties:GetCount(storageId),
                            max = maxParking or 0
                        }, characterId, dumbShit)
                    else
                        cb(false)
                    end
                end)
            end, 2, storageId, true, false, {
                _id = 0,
                VIN = 1,
                Make = 1,
                Model = 1,
                Type = 1,
                Owner = 1,
                RegisteredPlate = 1,
            })
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:RetrieveVehicleFromStorage', function(source, data, cb)
        local character = plsr.Fetch:CharacterSource(source)
        if not character or not data or not data.VIN or not data.coords or not data.heading then
            cb(false)
            return
        end

        local characterId = character:GetData('SID')

        if plsr.Vehicles.Owned:GetActive(data.VIN) then
            cb(false)
            return
        end

        plsr.Vehicles.Owned:GetVIN(data.VIN, function(vehicle)

            if vehicle and vehicle.VIN then
                local isAuthedForVehicle = false
                local extraData = {}
                if vehicle.Owner.Type == 0 and (vehicle.Owner.Id == characterId or data.storageType == 2) then
                    isAuthedForVehicle = true
                elseif vehicle.Owner.Type == 1 then
                    local onDuty = plsr.State:Player(source).onDuty

                    if onDuty and onDuty == vehicle.Owner.Id then
                        local jobPermissions = plsr.Jobs.Permissions:GetPermissionsFromJob(source, vehicle.Owner.Id, vehicle.Owner.Workplace)
                        if jobPermissions then
                            local allowedLevel = GetAllowedFleetVehicleLevelFromJobPermissions(jobPermissions)
                            if (allowedLevel >= vehicle.Owner.Level) then
                                isAuthedForVehicle = true

                                if plsr.Police:IsPdCar(vehicle.Vehicle) or plsr.Police:IsEMSCar(vehicle.Vehicle) then
                                    local callsign = character:GetData("Callsign")

                                    extraData.callsign = callsign
                                end
                            end
                        end
                    end
                end

                if isAuthedForVehicle then
                    plsr.Vehicles.Owned:Spawn(source, vehicle.VIN, data.coords, data.heading, function(success, vehicleData, vehicleId)
                        if success then
                            plsr.Vehicles.Keys:Add(source, vehicle.VIN)

                            if data.storageType == 2 and vehicle.Owner.Id ~= characterId then
                                plsr.Vehicles.Keys:AddBySID(vehicle.Owner.Id, vehicle.VIN)
                            end
                        end
                        cb(success)
                    end, extraData)
                else
                    cb(false)
                end
            end
        end)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:PutVehicleInStorage', function(source, data, cb)
        local character = plsr.Fetch:CharacterSource(source)
        local storageData = _vehicleStorage[data.storageId]
        if not character or not data or not data.VIN or not data.storageId or not storageData then
            cb(false)
            return
        end

        if storageData.retrievalOnly then
            plsr.Execute:Client(source, 'Notification', 'Error', 'Cannot Store Vehicles Here')
            cb(false)
            return
        end

        local characterId = character:GetData('SID')
        local vehicle = plsr.Vehicles.Owned:GetActive(data.VIN)

        if not vehicle then
            cb(false)
            return
        end

        local vehicleOwner = vehicle:GetData('Owner')

        local isAuthedForVehicle = false
        if vehicleOwner.Type == 0 and (not storageData.restricted) or (storageData.restricted and DoesCharacterPassStorageRestrictions(source, character:GetData('Jobs') or {}, storageData.restricted) and characterId == vehicleOwner.Id) then
            isAuthedForVehicle = true
        elseif vehicleOwner.Type == 1 then
            if storageData.fleet and DoesVehiclePassFleetRestrictions(vehicleOwner, storageData.fleet) then
                local onDuty = plsr.State:Player(source).onDuty

                if onDuty and onDuty == vehicleOwner.Id then
                    local jobPermissions = plsr.Jobs.Permissions:GetPermissionsFromJob(source, vehicleOwner.Id, vehicleOwner.Workplace)
                    if jobPermissions then
                        local allowedLevel = GetAllowedFleetVehicleLevelFromJobPermissions(jobPermissions)
                        if (allowedLevel >= vehicleOwner.Level) then
                            local t = vehicle:GetData('LastDriver') or {}
                            if #t >= 20 then
                                table.remove(t, 1)
                            end

                            table.insert(t, {
                                time = os.time(),
                                char = characterId,
                            })

                            vehicle:SetData('LastDriver', t)

                            isAuthedForVehicle = true
                        end
                    end
                end
            else
                plsr.Execute:Client(source, 'Notification', 'Error', 'Cannot Store This Vehicle Here')
            end
        end

        if isAuthedForVehicle and vehicle:GetData('Type') == storageData.vehType then
            plsr.Vehicles.Owned:Store(data.VIN, 1, data.storageId, function(success)
                cb(success)
            end)
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback("Vehicles:Impound:TagVehicle", function(source, data, cb)
        local char = plsr.Fetch:CharacterSource(source)
        if char ~= nil then
            if plsr.State:Player(source).onDuty == "police" then
                local entState = plsr.State.Entity(NetworkGetEntityFromNetworkId(data.vNet))
                if entState ~= nil and entState.VIN ~= nil and _taggedVehs[entState.VIN] == nil then
                    _taggedVehs[entState.VIN] = data
                    cb(true)
                else
                    cb(false)
                end
            else
                cb(false)
            end
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:PutVehicleInPropertyStorage', function(source, data, cb)
        local character = plsr.Fetch:CharacterSource(source)
        if not character or not data or not data.VIN or not data.storageId then
            cb(false)
            return
        end

        local characterId = character:GetData('SID')
        local vehicle = plsr.Vehicles.Owned:GetActive(data.VIN)

        if not vehicle then
            cb(false)
            return
        end

        local vehicleOwner = vehicle:GetData('Owner')
        if vehicleOwner.Type == 0 and vehicle:GetData('Type') == 0 then
            if plsr.Properties.Keys:HasBySID(data.storageId, vehicleOwner.Id) then
                local property = plsr.Properties:Get(data.storageId)
                local vehLimit = plsr.Properties:GetMaxParkingSpaces(data.storageId)
                if not vehLimit then
                    vehLimit = 0
                end

                if plsr.Vehicles.Owned.Properties:GetCount(data.storageId, vehicle:GetData('VIN')) < vehLimit then
                    plsr.Vehicles.Owned:Store(data.VIN, 2, data.storageId, function(success)
                        cb(success)
                    end)
                else
                    cb(false, true)
                end
            else
                cb(false)
            end
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:Impound', function(source, data, cb)
        local character = plsr.Fetch:CharacterSource(source)
        if not character or not data.type or not data.vNet then
            cb(false)
            return
        end

        local veh = NetworkGetEntityFromNetworkId(data.vNet)
        local myDuty = plsr.State:Player(source).onDuty

        if DoesEntityExist(veh) and myDuty and plsr.Jobs.Permissions:HasPermission(source, _impoundConfig.RequiredPermission) or plsr.Jobs.Permissions:HasPermission(source, _impoundConfig.Police.RequiredPermission) then
            local vState = plsr.State.Entity(veh)
            if vState and vState.VIN and not vState.towObjective then
                local ownedVehicle = plsr.Vehicles.Owned:GetActive(vState.VIN)
                if ownedVehicle then
                    local impounderData = {
                        SID = character:GetData('SID'),
                        First = character:GetData('First'),
                        Last = character:GetData('Last'),
                        ID = character:GetData('ID'),
                        Police = myDuty == 'police',
                    }

                    if _taggedVehs[vState.VIN] ~= nil then
                        local c = plsr.Fetch:SID(_taggedVehs[vState.VIN].requester)
                        if c ~= nil then
                            local duty = plsr.State:Player(c:GetData("Source")).onDuty
                            impounderData = {
                                SID = c:GetData('SID'),
                                First = c:GetData('First'),
                                Last = c:GetData('Last'),
                                ID = c:GetData('ID'),
                                Police = duty == 'police',
                            }
                        end

                        data = _taggedVehs[vState.VIN]
                    end

                    local impoundData = ParseImpoundData(0, 0, impounderData)
                    if data.type == 'impound' then
                        impoundData = ParseImpoundData(_impoundConfig.RegularFine, 0, impounderData)
                    elseif data.type == 'police' and data.level then
                        local levelData = _impoundConfig.Police.Levels[data.level]
                        if levelData then
                            local policeFine = 0

                            if levelData.Fine.Percent and vState and vState.Value then
                                local fineMultiplier = levelData.Fine.Percent / 100
                                policeFine = math.ceil(vState.Value * fineMultiplier)
                            end
    
                            if policeFine <= levelData.Fine.Min then
                                policeFine = levelData.Fine.Min
                            end
    
                            impoundData = ParseImpoundData(policeFine, levelData.Holding, impounderData)
                        end
                    end

                    if ownedVehicle:GetData('Type') == 0 and ownedVehicle:GetData('Owner').Type == 0 then
                        ownedVehicle:SetData('Storage', impoundData)
                    end
                end

                if myDuty == 'tow' and _taggedVehs[vState.VIN] ~= nil then
                    plsr.Banking.Balance:Deposit(plsr.Banking.Accounts:GetPersonal(character:GetData("SID")).Account, 800, {
                        type = 'paycheck',
                        title = "PD Tow Fee",
                        description = 'Your Fee For A Vehicle Pickup',
                        data = 800
                    })
                end

                plsr.Vehicles:Delete(veh, function(success)
                    cb(success)
                end)
            elseif vState and vState.towObjective then
                if myDuty == 'tow' and _taggedVehs[vState.VIN] ~= nil then
                    plsr.Banking.Balance:Deposit(plsr.Banking.Accounts:GetPersonal(character:GetData("SID")).Account, 800, {
                        type = 'paycheck',
                        title = "PD Tow Fee",
                        description = 'Your Fee For A Vehicle Pickup',
                        data = 800
                    })
                end
                plsr.Vehicles:Delete(veh, function(success)
                    if success then
                        plsr.Tow:PayoutPickup(source)
                    end
                    cb(success)
                end)
            else
                cb(false)
            end
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:GetVehiclesInImpound', function(source, data, cb)
        local character = plsr.Fetch:CharacterSource(source)
        if not character then
            cb(false)
            return
        end

        local characterId = character:GetData('SID')
        plsr.Vehicles.Owned:GetAll(0, 0, characterId, function(vehicles)
            for k, v in ipairs(vehicles) do
                if v.Seized then
                    -- TODO: ADD ASSET FEE SEIZURE CHECK HERE
                    if not plsr.Loans:HasBeenDefaulted("vehicle", v.VIN) then
                        plsr.Vehicles.Owned:Seize(v.VIN, false)
                        v.Seized = false
                    end
                    Wait(100)
                end
            end
            cb(vehicles, os.time())
        end, 0, 0, false)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:RetrieveVehicleFromImpound', function(source, data, cb)
        local character = plsr.Fetch:CharacterSource(source)
        if not character or not data.VIN or not data.coords or not data.heading then
            cb(false)
            return
        end

        local characterId = character:GetData('SID')
        local timeNow = os.time()

        plsr.Vehicles.Owned:GetVIN(data.VIN, function(vehicle)
            if vehicle and vehicle.VIN and vehicle.Storage.Type == 0 and not vehicle.Seized then

                if vehicle.Storage.Fine and vehicle.Storage.Fine > 0 then
                    if not plsr.Wallet:Modify(source, -vehicle.Storage.Fine) then
                        cb(false)
                        return
                    end

                    local f = plsr.Banking.Accounts:GetOrganization("government")
                    plsr.Banking.Balance:Deposit(f.Account, vehicle.Storage.Fin, false, true)
                end


                if vehicle.Storage.TimeHold and (vehicle.Storage.TimeHold.ExpiresAt - timeNow) > 0 then
                    -- Holding Time Has Not Expired
                    cb(false)
                    return
                end

                plsr.Vehicles.Owned:Spawn(source, vehicle.VIN, data.coords, data.heading, function(success, vehicleData, vehicleId)
                    if success then
                        local vData = plsr.Vehicles.Owned:GetActive(vehicle.VIN)
                        vData:SetData('Storage', GetVehicleTypeDefaultStorage(vehicleData.Type))
                        plsr.Vehicles.Keys:Add(source, vehicle.VIN)
                    end
                    cb(success)
                end)
            else
                cb(false)
            end
        end)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:CompleteCustoms', function(source, data, cb)
        local character = plsr.Fetch:CharacterSource(source)
        if not character or type(data.cost) ~= 'number' or type(data.changes) ~= 'table' or not data.vNet then
            cb(false)
            return
        end

        local veh = NetworkGetEntityFromNetworkId(data.vNet)
        local vehState = plsr.State.Entity(veh)
        if DoesEntityExist(veh) and vehState and vehState.VIN then
            if plsr.Wallet:Modify(source, -math.abs(data.cost)) then
                local vehicleData = plsr.Vehicles.Owned:GetActive(vehState.VIN)
                local newProperties = false
                if vehicleData and vehicleData:GetData('Properties') then
                    local currentProperties = vehicleData:GetData('Properties')
    
                    for k, v in pairs(data.changes) do
                        if k == 'mods' then
                            for mod, val in pairs(v) do
                                currentProperties.mods[mod] = val
                            end
                        elseif k == 'extras' then
                            currentProperties.extras = currentProperties.extras or {}
                            for extraId, val in pairs(v) do
                                currentProperties.extras[extraId] = val
                            end
                        else
                            currentProperties[k] = v
                        end
                    end
    
                    newProperties = currentProperties
                    vehicleData:SetData('Properties', currentProperties)
                    vehicleData:SetData('DirtLevel', 0.0)
                    plsr.Vehicles.Owned:ForceSave(vehicleData:GetData('VIN'))

                elseif vehState.PleaseDoNotFuckingDelete then
                    _savedVehiclePropertiesClusterfuck[vehState.VIN] = data.new
                end
    
                SetVehicleDirtLevel(veh, 0.0)

                local f = plsr.Banking.Accounts:GetOrganization("dgang")
                plsr.Banking.Balance:Deposit(f.Account, math.abs(data.cost), {
                    type = 'deposit',
                    title = 'Benny\'s',
                    description = string.format("Benny's Vehicle Modifications For %s %s", character:GetData("First"), character:GetData("Last")),
                    data = {},
                }, true)
    
                cb(true, newProperties)
            else
                cb(false)
            end
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:WheelFitment', function(source, data, cb)
        local character = plsr.Fetch:CharacterSource(source)
        if not character or not data?.vNet then
            cb(false)
            return
        end

        local veh = NetworkGetEntityFromNetworkId(data.vNet)
        local vehEnt = plsr.State.Entity(veh)
        if DoesEntityExist(veh) and vehEnt?.VIN then
            local vehicleData = plsr.Vehicles.Owned:GetActive(vehEnt.VIN)
            if vehicleData then
                local currentFitmentData = vehicleData:GetData("WheelFitment") or {}
                for k, v in pairs(data.fitment) do
                    currentFitmentData[k] = v
                end

                vehicleData:SetData('WheelFitment', currentFitmentData)
                plsr.Vehicles.Owned:ForceSave(vehicleData:GetData('VIN'))
                vehEnt.WheelFitment = currentFitmentData
                TriggerClientEvent('Fitment:Client:Update', -1, data.vNet, currentFitmentData)
            else
                local currentFitmentData = vehEnt.WheelFitment or {}
                for k, v in pairs(data.fitment) do
                    currentFitmentData[k] = v
                end

                vehEnt.WheelFitment = currentFitmentData
                TriggerClientEvent('Fitment:Client:Update', -1, data.vNet, currentFitmentData)
            end

            cb(true)
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:CompleteRepair', function(source, data, cb)
        local character = plsr.Fetch:CharacterSource(source)
        if not character or type(data.cost) ~= 'number' then
            cb(false)
            return
        end

        if plsr.Wallet:Modify(source, -math.abs(data.cost)) then
            local f = plsr.Banking.Accounts:GetOrganization("dgang")
            plsr.Banking.Balance:Deposit(f.Account, math.abs(data.cost), {
                type = 'deposit',
                title = 'Benny\'s Repair',
                description = string.format("Benny's Vehicle Repair For %s %s", character:GetData("First"), character:GetData("Last")),
                data = {},
            }, true)
            cb(true)
        else
            cb(false)
        end
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:CleanVehicle', function(source, data, cb)
        local veh = NetworkGetEntityFromNetworkId(data.vNet)
        local vehState = plsr.State.Entity(veh)
        if DoesEntityExist(veh) and vehState and vehState.VIN then
            if not data.bill or (data.bill and plsr.Wallet:Modify(source, -100)) then
                local vehicleData = plsr.Vehicles.Owned:GetActive(vehState.VIN)
                if vehicleData then
                    vehicleData:SetData('DirtLevel', 0.0)
                end

                SetVehicleDirtLevel(veh, 0.0)
                return cb(true)
            end
        end
        cb(false)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:RemoveFakePlate', function(source, data, cb)
        local veh = NetworkGetEntityFromNetworkId(data)
        if veh and DoesEntityExist(veh) then
            local vehState = plsr.State.Entity(veh)
            if vehState.VIN and vehState.FakePlate then
                local char = plsr.Fetch:CharacterSource(source)
                local vehicle = plsr.Vehicles.Owned:GetActive(vehState.VIN)
                if char and vehicle and vehicle:GetData('FakePlate') then
                    local fakePlateData = vehicle:GetData('FakePlateData')
                    local originalPlate = vehicle:GetData('RegisteredPlate')

                    SetVehicleNumberPlateText(veh, originalPlate)
                    vehicle:SetData('FakePlate', false)
                    vehicle:SetData('FakePlateData', false)

                    vehState.FakePlate = false

                    plsr.Vehicles.Owned:ForceSave(vehState.VIN)

                    if fakePlateData and fakePlateData.Plate then
                        plsr.Inventory:AddItem(char:GetData('SID'), 'fakeplates', 1, fakePlateData, 1)
                    end

                    cb(true, originalPlate)
                    return
                end
            end
        end
        cb(false)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:RemoveHarness', function(source, data, cb)
        local veh = NetworkGetEntityFromNetworkId(data)
        if veh and DoesEntityExist(veh) then
            local vehState = plsr.State.Entity(veh)
            if vehState.VIN and vehState.Harness and vehState.Harness > 0 then
                vehState.Harness = 0

                cb(true)
                return
            end
        end
        cb(false)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:Tranfers:CompleteTransfer', function(source, data, cb)
        local SID, VIN in data
        local char = plsr.Fetch:CharacterSource(source)

        if SID and VIN and char then
            local targetChar = plsr.Fetch:SID(SID)
            local vehicle = plsr.Vehicles.Owned:GetActive(VIN)
            if targetChar and vehicle and vehicle:GetData('Owner')?.Type == 0 and vehicle:GetData('Owner')?.Id == char:GetData('SID') and source ~= targetChar:GetData('Source') then
                local ped = GetPlayerPed(source)
                local targetPed = GetPlayerPed(targetChar:GetData('Source'))
                if #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) <= 10.0 then
                    local ownerHistory = vehicle:GetData('OwnerHistory') or {}
                    local oldOwner = vehicle:GetData('Owner')
                    table.insert(ownerHistory, {
                        Type = oldOwner.Type,
                        Id = oldOwner.Id,
                        First = char:GetData('First'),
                        Last = char:GetData('Last'),
                        Time = os.time(),
                    })

                    vehicle:SetData('Owner', {
                        Type = 0,
                        Id = targetChar:GetData('SID'),
                    })

                    vehicle:SetData('OwnerHistory', ownerHistory)

                    vehicle:SetData('Storage', GetVehicleTypeDefaultStorage(vehicle:GetData('Type')))
                    plsr.Vehicles.Owned:ForceSave(VIN)

                    plsr.Phone.Notification:Add(
                        source,
                        "Vehicle Ownership",
                        "A vehicle was just transferred out of your ownership",
                        os.time(),
                        6000,
                        "garage",
                        {}
                    )
                    plsr.Phone.Notification:Add(
                        targetChar:GetData('Source'),
                        "Vehicle Ownership",
                        "A vehicle was just transferred into your ownership",
                        os.time(),
                        6000,
                        "garage",
                        {}
                    )

                    plsr.Vehicles.Keys:Remove(source, VIN)
                    plsr.Vehicles.Keys:Add(targetChar:GetData('Source'), VIN)
                    return
                else
                    plsr.Execute:Client(source, 'Notification', 'Error', 'Cannot Transfer to Someone That Isn\'t Nearby')
                end
            end
        end
        cb(false)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:RemoveNitrous', function(source, data, cb)
        local char = plsr.Fetch:CharacterSource(source)
        local veh = NetworkGetEntityFromNetworkId(data)
        if char and veh and DoesEntityExist(veh) then
            local vehState = plsr.State.Entity(veh)
            if vehState.VIN and vehState.Nitrous then
                plsr.Inventory:AddItem(char:GetData('SID'), 'nitrous', 1, {
                    Nitrous = math.floor(vehState.Nitrous)
                }, 1, nil, nil, nil, nil, nil, nil, nil, true)

                vehState.Nitrous = false

                cb(true)
                return
            end
        end
        cb(false)
    end)

    plsr.Callbacks:RegisterServerCallback('Vehicles:GiveKeys', function(source, data, cb)
        local veh = NetworkGetEntityFromNetworkId(data.netId)
        local vehState = plsr.State.Entity(veh)
        if DoesEntityExist(veh) and vehState.VIN and not vehState.wasThermited then
            local groupKeys = vehState.GroupKeys
            if plsr.Vehicles.Keys:Has(source, vehState.VIN, vehState.GroupKeys) then
                if veh and DoesEntityExist(veh) then
                    local vehEnt = plsr.State.Entity(veh)
                    if
                        vehEnt
                        and vehEnt.VIN
                        and plsr.Vehicles.Keys:Has(source, vehEnt.VIN, false)
                    then
                        for k, v in ipairs(data.sids) do
                            plsr.Vehicles.Keys:Add(v, vehEnt.VIN)
                            plsr.Execute:Client(
                                v,
                                "Notification",
                                "Info",
                                "You Received Keys to a Vehicle",
                                3000,
                                "key"
                            )
                        end

                        plsr.Execute:Client(
                            source,
                            "Notification",
                            "Success",
                            "You Gave Everyone Nearby Keys",
                            3000,
                            "key"
                        )
                    end
                end
            end
        end
        cb(false)
    end)
end