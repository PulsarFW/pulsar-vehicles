local _vehStores = {}

-- `owner_type/id/workplace/level`, `storage_type/id`, `registered_plate`/`fake_plate` are real
-- columns since they're all actually filtered on across rows (ownership/fleet/storage/plate
-- uniqueness checks); everything else stays in `data`, including the full nested Owner/Storage
-- objects (kept in the blob too, so callers reading `vehicle.Owner.Type` etc. don't change).
local _vehiclesTableReady = false
function EnsureVehiclesTable(callback)
    if _vehiclesTableReady then
        if callback then
            callback()
        end
        return
    end
    plsr.Database:Query(
        "CREATE TABLE IF NOT EXISTS `vehicles` (`id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `vin` VARCHAR(64) NOT NULL, `type` INT NOT NULL DEFAULT 0, `owner_type` INT NULL, `owner_id` VARCHAR(191) NULL, `owner_workplace` VARCHAR(191) NULL, `owner_level` INT NULL DEFAULT 0, `storage_type` INT NULL, `storage_id` VARCHAR(191) NULL, `registered_plate` VARCHAR(20) NULL, `fake_plate` VARCHAR(20) NULL, `data` JSON NOT NULL, UNIQUE INDEX `idx_vin` (`vin`), INDEX `idx_owner` (`owner_type`, `owner_id`), INDEX `idx_owner_fleet` (`owner_type`, `owner_workplace`, `owner_level`), INDEX `idx_storage` (`storage_type`, `storage_id`), INDEX `idx_type` (`type`), INDEX `idx_registered_plate` (`registered_plate`), INDEX `idx_fake_plate` (`fake_plate`))",
        nil,
        function()
            plsr.Database:Query(
                "CREATE TABLE IF NOT EXISTS `donator_plates` (`id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `player` VARCHAR(191) NOT NULL, `pending` INT NOT NULL DEFAULT 0, `redeemed` INT NOT NULL DEFAULT 0, UNIQUE INDEX `idx_player` (`player`))",
                nil,
                function()
                    _vehiclesTableReady = true
                    if callback then
                        callback()
                    end
                end
            )
        end
    )
end

-- Derives the flat owner_* / storage_* column values from the nested Owner/Storage objects.
function VehicleOwnerColumns(owner)
    if type(owner) ~= "table" then
        return nil, nil, nil, 0
    end
    local workplace = owner.Workplace
    if workplace == false or workplace == nil then
        workplace = nil
    else
        workplace = tostring(workplace)
    end
    local ownerId = owner.Id ~= nil and tostring(owner.Id) or nil
    local level = type(owner.Level) == "number" and owner.Level or 0
    return owner.Type, ownerId, workplace, level
end

function VehicleStorageColumns(storage)
    if type(storage) ~= "table" then
        return nil, nil
    end
    local storageId = storage.Id ~= nil and tostring(storage.Id) or nil
    return storage.Type, storageId
end

function RowToVehicle(row)
    if row == nil then
        return nil
    end
    local ok, vehicle = pcall(json.decode, row.data)
    if not ok or type(vehicle) ~= "table" then
        return nil
    end
    vehicle._id = row.id
    return vehicle
end

ACTIVE_OWNED_VEHICLES = {} -- Vehicles that need synced to the DB
ACTIVE_OWNED_VEHICLES_SPAWNERS = {}

VEHICLES_PENDING_PROPERTIES = {}

LICENSE_PLATE_DATA = {}

_savedVehicleProperties = {}

CreateThread(function()
    RegisterChatCommands()
    RegisterCallbacks()
    RegisterMiddleware()
    RegisterItemUses()
    RegisterPersonalPlateCallbacks()
    Startup()
end)

function RegisterMiddleware()
    plsr.Middleware:Add('Characters:Spawning', function(source)
        local id = plsr.Fetch:CharacterSource(source):GetData('SID')
        if VEHICLE_KEYS[id] == nil then
            VEHICLE_KEYS[id] = {}
        end
        TriggerClientEvent('Vehicles:Client:UpdateKeys', source, VEHICLE_KEYS[id])
    end, 5)

    -- Middleware:Add('playerDropped', function(source)
    --     local sourceSpawnVehicles = ACTIVE_OWNED_VEHICLES_SPAWNERS[source]
    --     if sourceSpawnVehicles and #sourceSpawnVehicles > 0 then
    --         for k, v in ipairs(sourceSpawnVehicles) do
    --             Vehicles.Owned:ForceSave(v)
    --         end
            
    --         ACTIVE_OWNED_VEHICLES_SPAWNERS[source] = nil
    --     end
    -- end)
end



-- If the vehicle doesn't have it's properties saved, they are sent to the server
RegisterNetEvent('Vehicles:Server:PlayerSetProperties', function(veh, properties)
    if veh and DoesEntityExist(veh) and VEHICLES_PENDING_PROPERTIES[veh] and type(properties) == 'table' then
        local vState = plsr.State.Entity(veh)
        if vState and vState.VIN then
            local vData = plsr.Vehicles.Owned:GetActive(vState.VIN)
            if vData then
                vData:SetData('Properties', properties)
                vData:SetData('FirstSpawn', false)
                VEHICLES_PENDING_PROPERTIES[veh] = nil
                SaveVehicle(vState.VIN)
            elseif vState.PreventDelete then
                _savedVehicleProperties[vState.VIN] = properties
                VEHICLES_PENDING_PROPERTIES[veh] = nil
            end
        end
    end
end)

local tempVehicleStoreKeys = { '_id', 'VIN', 'EntityId', 'LastSave', 'Flags', 'Strikes', 'GovAssigned', 'ModelType' }

function SaveVehicle(VIN)
    local veh = plsr.Vehicles.Owned:GetActive(VIN)
    if veh then
        local p = promise.new()
        local vehEnt = veh:GetData('EntityId')
        local vehState = plsr.State.Entity(vehEnt)

        veh:SetData('DirtLevel', GetVehicleDirtLevel(vehEnt))

        veh:SetData('Fuel', vehState.Fuel)
        veh:SetData('Damage', vehState.Damage)
        veh:SetData('DamagedParts', vehState.DamagedParts)
        veh:SetData('Mileage', vehState.Mileage)
        veh:SetData('Polish', vehState.Polish)
        veh:SetData('PurgeColor', vehState.PurgeColor)
        veh:SetData('PurgeLocation', vehState.PurgeLocation)

        if vehState.Harness ~= nil then
            veh:SetData('Harness', vehState.Harness)
        end

        if vehState.Nitrous ~= nil then
            veh:SetData('Nitrous', vehState.Nitrous)
        end

        if vehState.neonsDisabled ~= nil then
            veh:SetData('NeonsDisabled', vehState.neonsDisabled)
        end

        local data = veh:GetData()
        local VIN = veh:GetData('VIN')

        for k, v in ipairs(tempVehicleStoreKeys) do
            data[v] = nil
        end

        veh:SetData('LastSave', os.time())

        EnsureVehiclesTable(function()
            plsr.Database:Single("SELECT `data` FROM `vehicles` WHERE `vin` = ?", { VIN }, function(success, row)
                if not success or row == nil then
                    p:resolve(false)
                    return
                end

                local ok, existing = pcall(json.decode, row.data)
                if not ok or type(existing) ~= "table" then
                    existing = {}
                end
                for k, v in pairs(data) do
                    existing[k] = v
                end

                local ownerType, ownerId, ownerWorkplace, ownerLevel = VehicleOwnerColumns(existing.Owner)
                local storageType, storageId = VehicleStorageColumns(existing.Storage)

                plsr.Database:Update(
                    "UPDATE `vehicles` SET `type` = ?, `owner_type` = ?, `owner_id` = ?, `owner_workplace` = ?, `owner_level` = ?, `storage_type` = ?, `storage_id` = ?, `registered_plate` = ?, `fake_plate` = ?, `data` = ? WHERE `vin` = ?",
                    {
                        existing.Type or 0,
                        ownerType,
                        ownerId,
                        ownerWorkplace,
                        ownerLevel,
                        storageType,
                        storageId,
                        existing.RegisteredPlate or nil,
                        existing.FakePlate or nil,
                        json.encode(existing),
                        VIN,
                    },
                    function(updateSuccess)
                        p:resolve(updateSuccess)
                    end
                )
            end)
        end)

        local success = Citizen.Await(p)
        return success
    else
        return false
    end
end

--[[
    ? Owner Types:
    0 = Characters
    1 = Job Fleets


    ? Storage Types:
    0 - Impound
    1 - Garage
    2 - Property

    ? Vehicle Types:
    0 - Regular Car/Truck
    1 - Boat
    2 - Aircraft
]]

VEHICLE = {
    Stores = {
        Create = function(self, id, data)
            data = data or {}
            _vehStores[id] = data
    
            return {
                Key = id,
                SetData = function(self, var, data)
                    _vehStores[self.Key][var] = data
                end,
                GetData = function(self, var)
                    if var ~= nil and var ~= "" then
                        if _vehStores[self.Key][var] ~= nil then
                            return _vehStores[self.Key][var]
                        else
                            return nil
                        end
                    else
                        return _vehStores[self.Key]
                    end
                end,
                DeleteStore = function(self)
                    plsr.Vehicles.Stores:Delete(self.Key)
                end,
            }
        end,
        Delete = function(self, id)
            if _vehStores[id] then
                _vehStores[id] = nil
                collectgarbage()
            end
        end,
    },
    RandomModel = {
        DClass = function()
            return _models.D[math.random(#_models.D)]
        end,
        CCLass = function()
            return _models.C[math.random(#_models.C)]
        end,
        BClass = function()
            return _models.B[math.random(#_models.B)]
        end,
        AClass = function()
            return _models.A[math.random(#_models.A)]
        end,
        SClass = function()
            return `taxi`
        end,
        XClass = function()
            return `taxi`
        end,
    },
    RandomName = function(self)
        return _vehNamesAll[math.random(#_vehNamesAll)]
    end,
    RandomNameByMake = function(self, make)
        local models = _vehNames[make]
        if models then
            return models[math.random(#models)]
        end
    end,
    Garages = {
        GetAll = function(self)
            local garages = {}
            for k, v in pairs(_vehicleStorage) do
                garages[k] = {
                    label = v.name,
                    location = v.coords,
                }
            end
            garages['impound'] = {
                label = _vehicleImpound.name,
                location = _vehicleImpound.coords,
            }
            return garages
        end,
        Get = function(self, id)
            return _vehicleStorage[id]
        end,
        Impound = function(self)
            return _vehicleImpound
        end,
    },
    Owned = {
        AddToCharacter = function(self, charSID, vehicleHash, vehicleType, modelType, infoData, cb, properties, defaultStorage, suppliedVIN)
            plsr.Vehicles.Owned:Add({
                Type = 0,
                Id = charSID
            }, vehicleHash, vehicleType, modelType, infoData, cb, properties, defaultStorage, suppliedVIN)
        end,
        
        AddToFleet = function(self, jobId, jobWorkplace, vehicleLevel, vehicleHash, vehicleType, modelType, infoData, cb, properties, qual)
            if not properties then
                properties = false
            end

            local defaultStorage = false
            if type(vehicleType) ~= 'number' or vehicleType < 0 or vehicleType > 2 then
                vehicleType = 0
            end

            -- Get the fleet HQ to store vehicles in by default
            for storageId, storageData in pairs(_vehicleStorage) do
                if storageData.fleet then
                    for k, v in pairs(storageData.fleet) do
                        if storageData.vehType == vehicleType and v.JobId == jobId and v.HQ then
                            defaultStorage = {
                                Type = 1,
                                Id = storageId,
                            }

                            break
                        end
                    end
                end
            end

            plsr.Vehicles.Owned:Add({
                Type = 1,
                Id = jobId,
                Workplace = jobWorkplace and jobWorkplace or false,
                Level = (type(vehicleLevel) == 'number') and vehicleLevel or 0,
                Qualification = qual,
            }, vehicleHash, vehicleType, modelType, infoData, cb, properties, defaultStorage)
        end,

        -- !!! Should not be used externally
        Add = function(self, ownerData, vehicleHash, vehicleType, modelType, infoData, cb, properties, defaultStorageData, suppliedVIN)
            if type(vehicleType) ~= 'number' or vehicleType < 0 or vehicleType > 2 then
                vehicleType = 0
            end

            if ownerData and ownerData.Type and ownerData.Id and type(vehicleHash) == 'number' and type(infoData) == 'table' then
                -- Detemining Default Storage Data
                local storageData = false
                if type(defaultStorageData) == 'table' and defaultStorageData.Type and defaultStorageData.Id then
                    storageData = defaultStorageData
                else
                    storageData = GetVehicleTypeDefaultStorage(vehicleType)
                end

                local plate = false
                if vehicleType == 0 then
                    plate = plsr.Vehicles.Identification.Plate:Generate()
                end

                local VIN = suppliedVIN
                if not VIN then
                    VIN = plsr.Vehicles.Identification.VIN:GenerateOwned()
                end

                local doc = {
                    Type = vehicleType,
                    Vehicle = vehicleHash,
                    ModelType = modelType,

                    VIN = VIN,
                    RegisteredPlate = plate,
                    FakePlate = false,
                    Fuel = math.random(90, 100),

                    Owner = ownerData,
                    Storage = storageData,

                    Make = infoData.make or 'Unknown',
                    Model = infoData.model or 'Unknown',
                    Class = infoData.class or 'Unknown',
                    Value = infoData.value or false,

                    Donator = infoData.donatorFlag,

                    FirstSpawn = true,
                    Properties = type(properties) == 'table' and properties or false,

                    RegistrationDate = os.time(),

                    Mileage = 0,

                    DirtLevel = 0.0,
                }

                local ownerType, ownerId, ownerWorkplace, ownerLevel = VehicleOwnerColumns(doc.Owner)
                local storageType, storageId = VehicleStorageColumns(doc.Storage)

                EnsureVehiclesTable(function()
                    plsr.Database:Insert(
                        "INSERT INTO `vehicles` (`vin`, `type`, `owner_type`, `owner_id`, `owner_workplace`, `owner_level`, `storage_type`, `storage_id`, `registered_plate`, `fake_plate`, `data`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        {
                            VIN,
                            vehicleType,
                            ownerType,
                            ownerId,
                            ownerWorkplace,
                            ownerLevel,
                            storageType,
                            storageId,
                            doc.RegisteredPlate or nil,
                            doc.FakePlate or nil,
                            json.encode(doc),
                        },
                        function(success, newId)
                            if success then
                                doc._id = newId
                                cb(true, doc)
                            else
                                cb(false)
                            end
                        end
                    )
                end)
            else
                cb(false)
            end
        end,

        GetActive = function(self, VIN)
            if ACTIVE_OWNED_VEHICLES[VIN] then
                return ACTIVE_OWNED_VEHICLES[VIN]
            end
            return false
        end,

        GetVIN = function(self, VIN, cb)
            EnsureVehiclesTable(function()
                plsr.Database:Single("SELECT `id`, `data` FROM `vehicles` WHERE `vin` = ?", { VIN }, function(success, row)
                    if not success or row == nil then
                        cb(false)
                        return
                    end
                    local vehicle = RowToVehicle(row)
                    if vehicle then
                        cb(vehicle)
                    else
                        cb(false)
                    end
                end)
            end)
        end,
        GetAll = function(self, vehType, ownerType, ownerId, cb, storageType, storageId, ignoreSpawned, checkFleetOwner, projection)
            local orClauses = {}
            local params = {}

            if ownerType and ownerId then
                table.insert(orClauses, "(`owner_type` = ? AND `owner_id` = ?)")
                table.insert(params, ownerType)
                table.insert(params, tostring(ownerId))
            end

            if checkFleetOwner and checkFleetOwner.Id then
                local clause = "(`owner_type` = 1 AND `owner_id` = ?"
                table.insert(params, tostring(checkFleetOwner.Id))

                if checkFleetOwner.Workplace then
                    clause = clause .. " AND (`owner_workplace` = ? OR `owner_workplace` IS NULL)"
                    table.insert(params, tostring(checkFleetOwner.Workplace))
                else
                    clause = clause .. " AND `owner_workplace` IS NULL"
                end

                clause = clause .. " AND `owner_level` <= ?)"
                table.insert(params, type(checkFleetOwner.Level) == 'number' and checkFleetOwner.Level or 0)

                table.insert(orClauses, clause)
            end

            local whereClauses = {}
            if #orClauses > 0 then
                table.insert(whereClauses, "(" .. table.concat(orClauses, " OR ") .. ")")
            end

            if storageType and storageId then
                table.insert(whereClauses, "`storage_type` = ? AND `storage_id` = ?")
                table.insert(params, storageType)
                table.insert(params, tostring(storageId))
            end

            if type(vehType) == 'number' then
                table.insert(whereClauses, "`type` = ?")
                table.insert(params, vehType)
            end

            local sql = "SELECT `id`, `data` FROM `vehicles`"
            if #whereClauses > 0 then
                sql = sql .. " WHERE " .. table.concat(whereClauses, " AND ")
            end

            EnsureVehiclesTable(function()
                plsr.Database:Query(sql, params, function(success, results)
                    if success then
                        local vehicles = {}
                        for k, row in ipairs(results) do
                            local v = RowToVehicle(row)
                            if v and (not ignoreSpawned or (ignoreSpawned and not plsr.Vehicles.Owned:GetActive(v.VIN))) then
                                v.Spawned = plsr.Vehicles.Owned:GetActive(v.VIN)
                                if v.Storage and v.Storage.Type == 2 then
                                    local prop = plsr.Properties:Get(v.Storage.Id)
                                    if prop and prop.id and prop.label then
                                        v.PropertyStorage = prop
                                    end
                                end
                                table.insert(vehicles, v)
                            end
                        end

                        cb(vehicles)
                    else
                        cb(false)
                    end
                end)
            end)
        end,

        GetAllActive = function(self)
            return ACTIVE_OWNED_VEHICLES
        end,
        
        Spawn = function(self, source, VIN, coords, heading, cb, extraData)
            plsr.Vehicles.Owned:GetVIN(VIN, function(vehicle)
                if vehicle and not plsr.Vehicles.Owned:GetActive(VIN) then
                    local spawnedVehicle = CreateVehicleFromType(vehicle.ModelType, vehicle.Vehicle, coords, (heading and heading + 0.0 or 0.0))
                    if spawnedVehicle then
                        -- Set State
                        local spawnData = {
                            ServerEntity   = spawnedVehicle,
                            Owned          = true,
                            Owner          = vehicle.Owner,
                            PlayerDriven   = true,
                            VIN            = vehicle.VIN,
                            RegisteredPlate = vehicle.RegisteredPlate,
                            Fuel           = vehicle.Fuel,
                            Locked         = true,
                            GroupKeys      = false,
                            Make           = vehicle.Make,
                            Model          = vehicle.Model,
                            Class          = vehicle.Class,
                            Value          = vehicle.Value,
                            Donator        = vehicle.Donator,
                            Damage         = vehicle.Damage,
                            DamagedParts   = vehicle.DamagedParts,
                            Mileage        = vehicle.Mileage,
                            WheelFitment   = vehicle.WheelFitment,
                        }
                        SetVehicleDoorsLocked(spawnedVehicle, 2)

                        if vehicle.Owner and vehicle.Owner.Type == 1 and ((not vehicle.Owner.Workplace) or vehicle.Owner.Id == "police" or vehicle.Owner.Id == "prison" or vehicle.Owner.Id == "ems") then
                            spawnData.GroupKeys = vehicle.Owner.Id
                        end

                        if vehicle.Polish and vehicle.Polish.Expires and vehicle.Polish.Expires > os.time() then
                            spawnData.Polish = vehicle.Polish
                        end

						if vehicle.PurgeColor then
                            spawnData.PurgeColor = vehicle.PurgeColor or {r = 255, g = 255, b = 255}
                        end

						if vehicle.PurgeLocation then
                            spawnData.PurgeLocation = vehicle.PurgeLocation or "wheel_rf"
                        end

                        if vehicle.Harness and vehicle.Harness > 0 then
                            spawnData.Harness = vehicle.Harness
                        end

                        if vehicle.Nitrous ~= nil then
                            spawnData.Nitrous = vehicle.Nitrous
                        end

                        if vehicle.RegisteredPlate then
                            if vehicle.FakePlate then
                                spawnData.Plate = vehicle.FakePlate
                                spawnData.FakePlate = vehicle.FakePlate
                                SetVehicleNumberPlateText(spawnedVehicle, vehicle.FakePlate)
                            else
                                spawnData.Plate = vehicle.RegisteredPlate
                                SetVehicleNumberPlateText(spawnedVehicle, vehicle.RegisteredPlate)
                            end
                        else -- Its a heli or boat
                            SetVehicleNumberPlateText(spawnedVehicle, '')
                        end

                        if vehicle.DirtLevel and type(vehicle.DirtLevel) == 'number' then
                            SetVehicleDirtLevel(spawnedVehicle, vehicle.DirtLevel + 0.0)
                        end

                        if vehicle.NeonsDisabled then
                            spawnData.neonsDisabled = true
                        end

                        if vehicle.ForcedAudio then
                            spawnData.ForcedAudio = vehicle.ForcedAudio
                        end

                        spawnData.Trailer = GetVehicleType(spawnedVehicle) == 'trailer'

                        if vehicle.FirstSpawn and not vehicle.Properties then
                            VEHICLES_PENDING_PROPERTIES[spawnedVehicle] = true
                            spawnData.awaitingProperties = {
                                needInit = true,
                            }
                        elseif vehicle.Properties then
                            spawnData.awaitingProperties = {
                                needInit = false,
                                properties = vehicle.Properties,
                                propertiesData = extraData,
                                damage = vehicle.Damage,
                            }
                        end

                        plsr.State.Entity:SetMulti(spawnedVehicle, spawnData)

                        local vehicleStore = plsr.Vehicles.Stores:Create(vehicle.VIN, vehicle)

                        vehicleStore:SetData('EntityId', spawnedVehicle)
                        ACTIVE_OWNED_VEHICLES[vehicle.VIN] = vehicleStore
                        cb(true, vehicle, spawnedVehicle)

                        if source and source > 0 then
                            -- Active Owner Stuff
                            if not ACTIVE_OWNED_VEHICLES_SPAWNERS[source] then
                                ACTIVE_OWNED_VEHICLES_SPAWNERS[source] = {}
                            end
                            table.insert(ACTIVE_OWNED_VEHICLES_SPAWNERS[source], vehicle.VIN)
                        end

                        -- Fix?
                        local inVeh = GetPedInVehicleSeat(spawnedVehicle, -1)
                        if inVeh and DoesEntityExist(inVeh) then
                            DeleteEntity(inVeh)
                        end
                    else
                        cb(false)
                    end
                else
                    cb(false)
                end
            end)
        end,
        Store = function(self, VIN, storageType, storageId, cb)
            local vehData = plsr.Vehicles.Owned:GetActive(VIN)
            if vehData and vehData:GetData('VIN') then
                local isSeized = vehData:GetData('Seized')
                if not isSeized then
                    vehData:SetData('Storage', {
                        Type = storageType,
                        Id = storageId,
                    })
                end

                plsr.Vehicles.Owned:Delete(vehData:GetData('VIN'), function(success)
                    cb(success)
                end)
            else
                cb(false)
            end
        end,

        Delete = function(self, VIN, cb, ignoredExists)
            local vehData = plsr.Vehicles.Owned:GetActive(VIN)
            if vehData and vehData:GetData('VIN') then
                local entity = vehData:GetData('EntityId')

                local ent = plsr.State.Entity(entity)
                if ent then
                    ent.Deleted = true
                end

                if entity and DoesEntityExist(entity) then
                    local success = SaveVehicle(vehData:GetData('VIN'))
                    if success then
                        DeleteEntity(entity)
                        ACTIVE_OWNED_VEHICLES[VIN] = nil
                        plsr.Vehicles.Stores:Delete(VIN)
                        cb(true)
                    end
                    cb(success)
                elseif ignoredExists then
                    ACTIVE_OWNED_VEHICLES[VIN] = nil
                    plsr.Vehicles.Stores:Delete(VIN)
                    cb(true, true)
                end
            else
                cb(false)
            end
        end,
        ForceSave = function(self, VIN)
            local vehicleData = plsr.Vehicles.Owned:GetActive(VIN)
            if vehicleData then
                local success = SaveVehicle(VIN)
                if success then
                    plsr.Logger:Info('Vehicles', 'Successfully Force Saved Vehicle: '.. VIN)
                end
            end
        end,

        Properties = {
            -- Character Storing Personal Vehicle in Property
            Store = function(self, source, VIN, propertyId, cb)
                local character = plsr.Fetch:CharacterSource(source)
                local vehData = plsr.Vehicles.Owned:GetActive(VIN)
                if propertyId and character and vehData and vehData:GetData('VIN') then
                    local vehOwner = vehData:GetData('Owner')
                    local stateId = character:GetData('SID')
                    if vehOwner.Type == 0 and stateId == vehOwner.Id then
                        plsr.Vehicles.Owned:Store(VIN, 2, propertyId, cb)
                    else
                        cb(false)
                    end
                else
                    cb(false)
                end
            end,
            -- Get Vehicles Stored in Property
            Get = function(self, propertyId, ownerStateId, cb)
                if ownerStateId then
                    plsr.Vehicles.Owned:GetAll(0, 0, ownerStateId, cb, 2, propertyId, true)
                else
                    plsr.Vehicles.Owned:GetAll(0, false, false, cb, 2, propertyId, true)
                end
            end,
            GetCount = function(self, propertyId, ignoreVIN)
                local p = promise.new()
                local sql = "SELECT COUNT(*) FROM `vehicles` WHERE `storage_type` = 2 AND `storage_id` = ?"
                local params = { tostring(propertyId) }

                if ignoreVIN then
                    sql = sql .. " AND `vin` <> ?"
                    table.insert(params, ignoreVIN)
                end

                EnsureVehiclesTable(function()
                    plsr.Database:Scalar(sql, params, function(success, count)
                        if success then
                            p:resolve(count)
                        else
                            p:resolve(false)
                        end
                    end)
                end)

                return Citizen.Await(p)
            end,
        },

        Seize = function(self, VIN, seizeState) -- Vehicle Siezure for Loans
            local vehicleData = plsr.Vehicles.Owned:GetActive(VIN)
            if vehicleData then -- Vehicle is currently out
                vehicleData:SetData('Seized', seizeState)
                vehicleData:SetData('SeizedTime', seizeState and os.time() or false)
                if seizeState then
                    vehicleData:SetData('Storage', {
                        Type = 0,
                        Id = 0,
                        Fine = 0,
                        TimeHold = false,
                    })
                end
                local success = SaveVehicle(VIN)
                return success
            else -- Vehicle is stored, update DB directly
                local p = promise.new()
                plsr.Vehicles.Owned:GetVIN(VIN, function(vehicle)
                    if vehicle and vehicle.VIN then
                        vehicle.Seized = seizeState
                        vehicle.SeizedTime = seizeState and os.time() or false

                        if vehicle.Storage.Type > 0 then -- Not Impounded
                            vehicle.Storage = {
                                Type = 0,
                                Id = 0,
                                Fine = 0,
                                TimeHold = false,
                            }
                        end

                        local storageType, storageId = VehicleStorageColumns(vehicle.Storage)

                        EnsureVehiclesTable(function()
                            plsr.Database:Update(
                                "UPDATE `vehicles` SET `storage_type` = ?, `storage_id` = ?, `data` = ? WHERE `vin` = ?",
                                { storageType, storageId, json.encode(vehicle), VIN },
                                function(success, updated)
                                    if success and updated > 0 then
                                        p:resolve(true)
                                    else
                                        p:resolve(false)
                                    end
                                end
                            )
                        end)
                    else
                        p:resolve(false)
                    end
                end)

                local res = Citizen.Await(p)
                return res
            end
        end,
        Track = function(self, VIN)
            local p = promise.new()

            local active = plsr.Vehicles.Owned:GetActive(VIN)
            if active then
                local wasTracked = active:GetData("TrackedLast")
                local vehLocation = GetEntityCoords(active:GetData("EntityId"))
                if wasTracked and wasTracked.time > os.time() then
                    p:resolve(wasTracked.coords)
                else
                    active:SetData("TrackedLast", {
                        time = os.time() + 120,
                        coords = vehLocation
                    })
                    p:resolve(vehLocation)
                end
            else
                plsr.Vehicles.Owned:GetVIN(VIN, function(c)
                    if c.Storage.Type == 0 then
                        p:resolve(plsr.Vehicles.Garages:Impound().coords)
                    elseif c.Storage.Type == 1 then
                        p:resolve(plsr.Vehicles.Garages:Get(c.Storage.Id).coords)
                    elseif c.Storage.Type == 2 then
                        local prop = plsr.Properties:Get(c.Storage.Id)
                        if prop?.location?.garage then
                            p:resolve(vector3(prop?.location?.garage?.x, prop?.location?.garage?.y, prop?.location?.garage?.z))
                        else
                            p:resolve(false)
                        end
                    end
                end)
            end

            return Citizen.Await(p)
        end,
    },

    SpawnTemp = function(self, source, model, modelType, coords, heading, cb, vehicleInfoData, properties, preDamage, suppliedPlate, suppliedVIN, useLegacyMethod)
        local spawnedVehicle = CreateVehicleFromType(modelType, model, coords, heading, useLegacyMethod)
        local plate = suppliedPlate or plsr.Vehicles.Identification.Plate:Generate(true)
        local vin = suppliedVIN or plsr.Vehicles.Identification.VIN:GenerateLocal()

        local spawnData = {
            VIN                       = vin,
            Owned                     = false,
            Locked                    = false,
            PlayerDriven              = true,
            Fuel                      = math.random(50, 100),
            Plate                     = plate,
            ServerEntity              = spawnedVehicle,
            PreventDelete  = true,
            Trailer                   = GetVehicleType(spawnedVehicle) == 'trailer',
            VEH_IGNITION              = false,
            SpawnTemp                 = true,
        }

        if vehicleInfoData then
            spawnData.Make = vehicleInfoData.Make
            spawnData.Model = vehicleInfoData.Model
            spawnData.Class = vehicleInfoData.Class
            spawnData.Value = vehicleInfoData.Value
        end

        if properties or preDamage then
            spawnData.awaitingProperties = {
                needInit = false,
                properties = properties,
                damage = preDamage,
            }

            if preDamage then
                spawnData.Damage = preDamage
            end
        end

        plsr.State.Entity:SetMulti(spawnedVehicle, spawnData)

        SetVehicleNumberPlateText(spawnedVehicle, plate)

        local inVeh = GetPedInVehicleSeat(spawnedVehicle, -1)
        if inVeh and DoesEntityExist(inVeh) then
            DeleteEntity(inVeh)
        end
        cb(spawnedVehicle, vin, plate)
    end,
    Delete = function(self, vehicleId, cb)
        if DoesEntityExist(vehicleId) and GetEntityType(vehicleId) == 2 then
            local vehState = plsr.State.Entity(vehicleId)
            if vehState and vehState.VIN and vehState.Owned then
                -- Its an owned vehicle, need to save
                plsr.Vehicles.Owned:Delete(vehState.VIN, function(success)
                    if success then
                        TriggerEvent("Vehicles:Server:Deleted", vehicleId, vehState.VIN)
                    end

                    cb(success)
                end)
            else
                vehState.Deleted = true
                if _savedVehicleProperties[vehState.VIN] ~= nil then
                    _savedVehicleProperties[vehState.VIN] = nil
                end

                DeleteEntity(vehicleId)
                TriggerEvent("Vehicles:Server:Deleted", vehicleId, vehState.VIN)
                cb(true)
            end
        else
            cb(false)
        end
    end,
    StopDespawn = function(self, vehicle)
        if DoesEntityExist(vehicle) then
            local ent = plsr.State.Entity(vehicle)

            if ent?.VIN and not ent.Owned then
                VEHICLES_PENDING_PROPERTIES[vehicle] = true

                ent.ServerEntity = vehicle
                ent.PreventDelete = true
                ent.awaitingProperties = {
                    stopDespawnInit = true,
                }
            end
        end
    end,
}

AddEventHandler('Proxy:Shared:RegisterReady', function()
    exports['pulsar_core']:RegisterComponent('Vehicles', VEHICLE)
end)

--[[
POPTYPE_UNKNOWN = 0, 
POPTYPE_RANDOM_PERMANENT 1
POPTYPE_RANDOM_PARKED 2
POPTYPE_RANDOM_PATROL 3
POPTYPE_RANDOM_SCENARIO 4
POPTYPE_RANDOM_AMBIENT 5
POPTYPE_PERMANENT 6
POPTYPE_MISSION 7
POPTYPE_REPLAY 8
POPTYPE_CACHE 9
POPTYPE_TOOL 10 
]]

function GenerateLocalVehicleInfo(entity)
    if not DoesEntityExist(entity) or plsr.Vehicles == nil then 
        return
    end

    local entityType = GetEntityType(entity)
    local populationType = GetEntityPopulationType(entity)

    if entityType == 2 and (populationType == 2 or populationType == 3 or populationType == 5) then
        local veh = plsr.State.Entity(entity)
        if not veh.VIN then -- Has Not Yet Been Detected/Initialised
            veh.VIN = plsr.Vehicles.Identification.VIN:GenerateLocal()
            veh.Owned = false
            veh.Hotwired = false
            veh.HotwiredSuccess = false
            veh.PlayerDriven = false
            veh.Fuel = math.random(30, 100)
            veh.Mileage = math.random(1, 100) * 100
        end
    end
end

AddEventHandler("Vehicles:Server:GenerateVehicleInfo", GenerateLocalVehicleInfo)

-- Generate Vehicle Info on Client Request
RegisterNetEvent("Vehicles:Server:RequestGenerateVehicleInfo", function(vNet)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(vNet)
    GenerateLocalVehicleInfo(veh)
end)

function ApplyOldVehicleState(veh, fuel, damage, damagedParts, mileage, engineHealth, bodyHealth, isBlownUp, localProperties, lastDriven, serverSpawnedTemp)
    local ent = plsr.State.Entity(veh)
    if ent?.VIN then
        ent.Fuel = fuel
        ent.Damage = damage
        ent.DamagedParts = damagedParts
        ent.Mileage = mileage
        ent.BlownUp = isBlownUp
        ent.awaitingEngineHealth = engineHealth

        ent.LastDriven = lastDriven
        ent.SpawnTemp = serverSpawnedTemp

        ent.awaitingBlownUp = isBlownUp

        if localProperties then
            ent.PreventDelete = true
            ent.awaitingProperties = {
                needInit = false,
                properties = localProperties,
                damage = {
                    Engine = engineHealth,
                    Body = bodyHealth
                }
            }
        end
    end
end

RegisterNetEvent('Vehicles:Server:StopDespawn', function(vNet)
    local veh = NetworkGetEntityFromNetworkId(vNet)
    plsr.Vehicles:StopDespawn(veh)
end)

AddEventHandler('entityRemoved', function(entity)
    if GetEntityType(entity) == 2 then
        local ent = plsr.State.Entity(entity)
        if ent?.VIN and (ent.Owned or ent.PreventDelete) and not ent.Deleted then
            local isLocal = ent.PreventDelete

            local vehModel = GetEntityModel(entity)
            local vehPlate = GetVehicleNumberPlateText(entity)

            local coords = GetEntityCoords(entity)
            local heading = GetEntityHeading(entity)
            local VIN = ent.VIN

            local fuel = ent.Fuel
            local damage = ent.Damage
            local damagedParts = ent.DamagedParts
            local mileage = ent.Mileage
            local isBlownUp = ent.BlownUp

            local engineHealth = GetVehicleEngineHealth(entity)
            local bodyHealth = GetVehicleBodyHealth(entity)

            local lastDriven = ent.LastDriven
            local spawnedTemp = ent.SpawnTemp

            -- Logger:Warn("Vehicles", string.format("Vehicle %s Deleted Unexpectedly - Local: %s, %s %s Engine: %s, Body: %s, Blown Up: %s", ent.VIN, isLocal, coords, heading, engineHealth, bodyHealth, isBlownUp))

            if not isLocal then
                ACTIVE_OWNED_VEHICLES[ent.VIN] = nil
                plsr.Vehicles.Stores:Delete(ent.VIN)
            end

            Wait(1000)

            if isLocal then
                plsr.Vehicles:SpawnTemp(-1, vehModel, nil, coords, heading, function(vehicleId)
                    SetVehicleBodyHealth(vehicleId, bodyHealth + 0.0)

                    ApplyOldVehicleState(vehicleId, fuel, damage, damagedParts, mileage, engineHealth, bodyHealth, isBlownUp, _savedVehicleProperties[VIN], lastDriven, spawnedTemp)
                end, false, false, false, vehPlate, VIN, true)
            else
                plsr.Vehicles.Owned:Spawn(-1, VIN, coords, heading, function(success, vehicleData, vehicleId)
                    if success then
                        SetVehicleBodyHealth(vehicleId, bodyHealth + 0.0)

                        ApplyOldVehicleState(vehicleId, fuel, damage, damagedParts, mileage, engineHealth, bodyHealth, isBlownUp)
                    end
                end)
            end
        end
    end
end)

AddEventHandler('explosionEvent', function(sender, ev)
    if ev and ev.f210 ~= 0 then
        local veh = NetworkGetEntityFromNetworkId(ev.f210)
        if veh and DoesEntityExist(veh) and GetEntityType(veh) == 2 then
            local vehEnt = plsr.State.Entity(veh)

            if vehEnt.VIN then
                -- print(sender, "Blew up Vehicle:", vehEnt.VIN)
                vehEnt.BlownUp = true
            end
        end
    end
end)

RegisterServerEvent('Vehicle:Server:InspectVIN', function(vNet)
    local src = source
    local veh = NetworkGetEntityFromNetworkId(vNet)
    if DoesEntityExist(veh) then
        local vState = plsr.State.Entity(veh)
        if vState and vState.VIN then
            plsr.Chat.Send.Server:Single(src, 'Vehicle VIN: '.. vState.VIN)
            TriggerClientEvent('Vehicles:Client:ViewVIN', src, vState.VIN)
        end
    end
end)

RegisterServerEvent('Vehicles:Server:FlipVehicle', function(netVeh, correctPitch)
    local vehicle = NetworkGetEntityFromNetworkId(netVeh)
    if vehicle and DoesEntityExist(vehicle) then
        local netOwner = NetworkGetEntityOwner(vehicle)
        if netOwner > 0 then
            TriggerClientEvent('Vehicles:Client:FlipVehicleRequest', netOwner, netVeh, correctPitch)
        end
    end
end)

AddEventHandler("Core:Server:ForceSave", function()
    local c = 0
    for VIN, _ in pairs(ACTIVE_OWNED_VEHICLES) do
        c = c + 1
        SaveVehicle(VIN)
    end
    plsr.Logger:Warn("Vehicles", string.format("Force Saved %s Vehicles", c))
end)