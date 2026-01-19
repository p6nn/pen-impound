local function notify(src, msg, type_, dur)
    TriggerClientEvent('ox_lib:notify', src, {
        description = msg,
        type = type_ or 'inform',
        duration = dur or 5000
    })
end

local function isAuthorized(src)
    if not src or src <= 0 then return false end
    return exports.qbx_core:HasPrimaryGroup(src, Config.AuthorizedJobs or {})
end

local function parseTimestamp(ts)
    if type(ts) == 'number' then return ts end
    if type(ts) == 'table' then
        return os.time({ year = ts.year, month = ts.month, day = ts.day, hour = ts.hour, min = ts.min, sec = ts.sec })
    end
    if type(ts) == 'string' then
        local Y, m, d, H, M, S = ts:match('(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)')
        if Y then
            return os.time({
                year = tonumber(Y),
                month = tonumber(m),
                day = tonumber(d),
                hour = tonumber(H),
                min = tonumber(M),
                sec = tonumber(S)
            })
        end
    end
    return os.time()
end

function CalculateImpoundFee(timestamp)
    local start = parseTimestamp(timestamp)
    local days = math.max(0, math.floor((os.time() - start) / 86400))
    if days < 1 then return Config.ImpoundFees.earlyReleaseFee end
    return (Config.ImpoundFees.base or 0) + (Config.ImpoundFees.perDay or 0) * math.min(days, Config.ImpoundFees.maxDays or days)
end

local function nearestImpoundName(coords)
    local best, bestDist
    for _, z in ipairs(Config.ImpoundZones or {}) do
        local d = #(coords - z.coords)
        if not bestDist or d < bestDist then
            bestDist = d
            best = z.name
        end
    end
    return best
end

function GetAvailableSpawnPoint(zone)
    local points = Config.VehicleSpawnPoints and Config.VehicleSpawnPoints[zone]
    if not points then return nil end

    for i = 1, #points do
        local p = points[i]
        local occupied = false

        for _, veh in ipairs(GetAllVehicles()) do
            if #(GetEntityCoords(veh) - vector3(p.x, p.y, p.z)) < 3.0 then
                occupied = true
                break
            end
        end

        if not occupied then return p end
    end
end

local function spawnVehicle(src, props, spawnPoint)
    if not spawnPoint then
        notify(src, 'no spawnpoint', 'error')
        return false
    end

    local coords = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
    local heading = spawnPoint.w or spawnPoint.heading or 0.0
    local netId = qbx.spawnVehicle({
        model = props.model,
        spawnSource = vector4(coords.x, coords.y, coords.z, heading),
        warp = false,
        props = props
    })
    local veh = NetworkGetEntityFromNetworkId(netId)

    if not netId then
        notify(src, 'Failed to spawn vehicle', 'error')
        return false
    end

    if not veh or veh == 0 then
        notify(src, 'Failed to spawn vehicle', 'error')
        return false
    end

    if heading then
        SetEntityHeading(veh, heading)
    end

    if props.plate then
        SetVehicleNumberPlateText(veh, props.plate)
    end

    Entity(veh).state.fuel = tonumber(props.fuel) or 0
    exports.qbx_vehiclekeys:GiveKeys(src, veh, true)
    return true
end

lib.callback.register('pen-impound:server:getVehicleOwner', function(_, plate)
    if not plate or plate == '' then return nil end

    local row = MySQL.single.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not row or not row.citizenid then return nil end

    local prow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { row.citizenid })
    if not prow or not prow.charinfo then return { citizenid = row.citizenid, name = 'Unknown' } end

    local info = json.decode(prow.charinfo) or {}
    return { citizenid = row.citizenid, name = (info.firstname or 'Unknown') .. ' ' .. (info.lastname or '') }
end)

lib.callback.register('pen-impound:server:impoundVehicle', function(source, data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    if not isAuthorized(src) then return false end

    if not data or type(data) ~= 'table' then return false end
    if not data.plate or data.plate == '' then return false end
    if not data.model or data.model == '' then return false end
    if not data.vehicleProps or type(data.vehicleProps) ~= 'table' then return false end

    local ownerId = data.ownerId
    local ownerName = data.ownerName

    if not ownerId then
        local row = MySQL.single.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { data.plate })
        if row and row.citizenid then
            ownerId = row.citizenid
        end
    end

    if not ownerName or ownerName == '' or ownerName == 'Unknown' then
        if ownerId then
            local prow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { ownerId })
            if prow and prow.charinfo then
                local info = json.decode(prow.charinfo) or {}
                ownerName = (info.firstname or 'Unknown') .. ' ' .. (info.lastname or '')
            end
        end
        ownerName = ownerName or 'Unknown'
    end

    if not ownerId then
        notify(src, 'no owner for plate', 'error')
        return false
    end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local zoneName = nearestImpoundName(coords)
    local officerName = ((player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or '')):gsub('^%s*(.-)%s*$', '%1')

    if officerName == '' then officerName = 'Unknown' end

    local jobName = (player.PlayerData.job and player.PlayerData.job.name) or 'unknown'
    local id = MySQL.insert.await('INSERT INTO vehicle_impounds (plate, model, citizenid, owner_name, fuel, officer, officer_citizenid, job, reason, report_id, impound_location, vehicle_props, released) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
        {
            data.plate,
            data.model,
            ownerId,
            ownerName,
            tonumber(data.fuel) or 0,
            officerName,
            player.PlayerData.citizenid,
            jobName,
            data.reason or 'Unspecified',
            data.reportId or nil,
            zoneName,
            json.encode(data.vehicleProps)
        }
    )

    if not id then
        notify(src, 'db failed', 'error')
        return false
    end

    MySQL.update.await('UPDATE player_vehicles SET state = 2 WHERE plate = ?', { data.plate })

    if ownerId then
        local owner = exports.qbx_core:GetPlayerByCitizenId(ownerId)
        if owner and owner.PlayerData and owner.PlayerData.source then
            notify(owner.PlayerData.source, ('Your vehicle %s was impounded'):format(data.plate), 'error', (Config.NotifyDuration or 5000))
        end
    end

    return true
end)

lib.callback.register('pen-impound:server:getImpoundedVehicles', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return {} end
    local rows = MySQL.query.await([[SELECT * FROM vehicle_impounds WHERE citizenid = ? AND (released = 0 OR released IS NULL) ORDER BY `timestamp` DESC]], { player.PlayerData.citizenid }) or {}
    for i = 1, #rows do
        rows[i].fee = CalculateImpoundFee(rows[i].timestamp)
        if rows[i].vehicle_props and not rows[i].vehicleProps then
            rows[i].vehicleProps = rows[i].vehicle_props
        end
    end

    return rows
end)

lib.callback.register('pen-impound:server:retrieveVehicle', function(source, impoundId, zone)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return { success = false, message = 'Player not found' } end
    if not impoundId then return { success = false, message = 'Invalid request' } end

    local impound = MySQL.single.await('SELECT * FROM vehicle_impounds WHERE id = ? AND (released = 0 OR released IS NULL) LIMIT 1', { impoundId })
    if not impound then return { success = false, message = "Vehicle not found" } end
    if impound.citizenid ~= player.PlayerData.citizenid then return { success = false, message = "You don't have permission to do this" } end

    local fee = CalculateImpoundFee(impound.timestamp)
    local cash = (player.PlayerData.money and player.PlayerData.money.cash) or 0
    local bank = (player.PlayerData.money and player.PlayerData.money.bank) or 0
    if cash < fee and bank < fee then return { success = false, message = "Insufficient funds to retrieve vehicle" } end

    local point = GetAvailableSpawnPoint(zone)
    if not point then return { success = false, message = "No available spawn points at this impound lot" } end

    if cash >= fee then
        exports.qbx_core:RemoveMoney(src, 'cash', fee, 'vehicle-impound-fee')
    else
        exports.qbx_core:RemoveMoney(src, 'bank', fee, 'vehicle-impound-fee')
    end

    MySQL.update.await('UPDATE vehicle_impounds SET released = 1, released_at = NOW() WHERE id = ?', { impoundId })
    MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { impound.plate })

    local props = json.decode(impound.vehicle_props or impound.vehicleProps or 'null')
    if props then
        props.plate = impound.plate
        props.fuel = impound.fuel
        spawnVehicle(src, props, point)
    end

    return { success = true }
end)

lib.callback.register('pen-impound:server:calculateFee', function(_, timestamp)
    return CalculateImpoundFee(timestamp)
end)

lib.callback.register('pen-impound:server:getAllImpoundedVehicles', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData then return {} end
    if not exports.qbx_core:HasPrimaryGroup(src, Config.AuthorizedJobs or {}) then return {} end

    local rows = MySQL.query.await([[SELECT * FROM vehicle_impounds ORDER BY COALESCE(released_at, `timestamp`) DESC LIMIT 500]]) or {}
    for i = 1, #rows do
        rows[i].fee = CalculateImpoundFee(rows[i].timestamp)
    end

    return rows
end)

lib.callback.register('pen-impound:server:releaseVehicle', function(source, impoundId, zone)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isAuthorized(src) then return { success = false, message = "You don't have permission to do this" } end
    if not impoundId then return { success = false, message = 'Invalid request' } end

    local impound = MySQL.single.await('SELECT * FROM vehicle_impounds WHERE id = ? AND (released = 0 OR released IS NULL) LIMIT 1', { impoundId })
    if not impound then return { success = false, message = "Vehicle not found" } end

    local point = GetAvailableSpawnPoint(zone)
    if not point then return { success = false, message = "No available spawn points at this impound lot" } end

    MySQL.update.await('UPDATE vehicle_impounds SET released = 1, released_at = NOW() WHERE id = ?', { impoundId })
    MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE plate = ?', { impound.plate })

    local props = json.decode(impound.vehicle_props or impound.vehicleProps or 'null')
    if props then
        props.plate = impound.plate
        props.fuel = impound.fuel
        spawnVehicle(src, props, point)
    end

    return { success = true }
end)

lib.callback.register('pen-impound:server:getImpoundLogs', function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not isAuthorized(src) then return {} end

    local result = MySQL.query.await([[
        SELECT
            id,
            plate,
            model,
            owner_name,
            officer,
            job,
            reason,
            timestamp,
            released,
            released_at,
            IF(released = 1, 'released', 'impounded') AS action_type
        FROM vehicle_impounds
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 48 HOUR)
           OR released_at >= DATE_SUB(NOW(), INTERVAL 48 HOUR)
        ORDER BY IFNULL(released_at, timestamp) DESC
        LIMIT 50
    ]])

    return result or {}
end)