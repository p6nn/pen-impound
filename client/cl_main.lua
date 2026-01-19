local currentZone, isUIOpen, radialItemAdded = nil, false, false

local function notify(msg, type_, dur)
    lib.notify({ description = msg, type = type_ or 'inform', duration = dur or 5000 })
end

local function isAuthorizedJob()
    return exports.qbx_core:HasPrimaryGroup(Config.AuthorizedJobs or {})
end

local function getVehicleNearby()
    local p = PlayerPedId()
    local c = GetEntityCoords(p)
    local v, vCoords = lib.getClosestVehicle(c, 3.0, true)
    
    if not v or not DoesEntityExist(v) or not IsEntityAVehicle(v) or not vCoords then
        return
    end
    if #(c - vCoords) <= 3.0 then
        return v
    end
end

local function setFocus(open)
    isUIOpen = open
    SetNuiFocus(open, open)
end

local function setupBlips()
    for _, zone in pairs(Config.ImpoundZones or {}) do
        local blipCfg = zone.blip
        if blipCfg and blipCfg.enabled then
            local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
            SetBlipSprite(blip, blipCfg.sprite)
            SetBlipColour(blip, blipCfg.color)
            SetBlipScale(blip, blipCfg.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(blipCfg.label or 'Impound')
            EndTextCommandSetBlipName(blip)
        end
    end
end

local function registerRetrieveZones()
    for _, z in pairs(Config.ImpoundZones or {}) do
        lib.zones.sphere({
            coords = z.coords,
            radius = 3.0,
            onEnter = function()
                if not isUIOpen then
                    notify('Press [E] to open Impound', 'inform', 3000)
                end
            end,
            inside = function()
                if IsControlJustReleased(0, 38) then
                    currentZone = z.name
                    OpenRetrieveUI()
                end
            end
        })
    end
end

local function addRadial()
    if radialItemAdded then return end

    lib.addRadialItem({
        id = 'impound_vehicle',
        label = 'Impound Vehicle',
        icon = 'truck-loading',
        onSelect = function()
            if not isAuthorizedJob() then
                notify("You don't have permission to do this", 'error')
                return
            end

            local v = getVehicleNearby()
            if not v then
                notify('No vehicle found', 'error')
                return
            end

            OpenImpoundUI(v)
        end
    })

    radialItemAdded = true
end

local function setupCommandMapping()
    RegisterCommand('impoundvehicle', function()
        if not isAuthorizedJob() then
            notify("You don't have permission to do this", 'error')
            return
        end

        local v = getVehicleNearby()
        if not v then
            notify('No vehicle found', 'error')
            return
        end

        OpenImpoundUI(v)
    end, false)

    RegisterKeyMapping('impoundvehicle', 'Impound Vehicle', 'keyboard', Config.ImpoundKeybind or 'F6')
end

function OpenImpoundUI(vehicle)
    if isUIOpen or not vehicle or not DoesEntityExist(vehicle) then return end

    local plate = GetVehicleNumberPlateText(vehicle)
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local fuel = 0
    local state = Entity(vehicle).state
    local props = lib.getVehicleProperties(vehicle)
    local ownerData = lib.callback.await('pen-impound:server:getVehicleOwner', nil, plate)

    if not plate or plate == '' then
        notify('Invalid plate', 'error')
        return
    end

    if state and state.fuel then
        fuel = tonumber(state.fuel) or 0
    end

    if not props then
        notify('Failed to read vehicle properties', 'error')
        return
    end
    
    setFocus(true)
    SendNUIMessage({
        action = 'openImpound',
        data = {
            plate = plate,
            model = displayName,
            fuel = math.floor(fuel),
            ownerName = ownerData and ownerData.name or 'Unknown',
            ownerId = ownerData and ownerData.citizenid or nil,
            vehicleProps = props,
            vehicle = VehToNet(vehicle)
        }
    })
end

function OpenRetrieveUI()
    if isUIOpen then return end

    local vehicles = lib.callback.await('pen-impound:server:getImpoundedVehicles', nil)
    local authorizedJob = isAuthorizedJob()

    if not authorizedJob and (not vehicles or #vehicles == 0) then
        notify('You have no impounded vehicles', 'info')
        return
    end

    setFocus(true)
    SendNUIMessage({
        action = 'openRetrieve',
        data = {
            vehicles = vehicles or {},
            zone = currentZone,
            isAuthorized = authorizedJob
        }
    })
end

RegisterNUICallback('close', function(_, cb)
    setFocus(false)
    cb('ok')
end)

RegisterNUICallback('impoundVehicle', function(data, cb)
    local success = lib.callback.await('pen-impound:server:impoundVehicle', nil, data)

    if success then
        local v = NetToVeh(data.vehicle)
        if v and v ~= 0 and DoesEntityExist(v) then
            SetEntityAsMissionEntity(v, true, true)
            DeleteEntity(v)
            if DoesEntityExist(v) then
                DeleteVehicle(v)
            end
        end

        notify("Vehicle impounded successfully", 'success')
        setFocus(false)
    else
        notify("Vehicle impounded successfully", 'error')
    end

    SendNUIMessage({ action = 'impoundResult', data = { success = success == true } })
    cb({ ok = true, success = success == true })
end)

RegisterNUICallback('retrieveVehicle', function(data, cb)
    local result = lib.callback.await('pen-impound:server:retrieveVehicle', nil, data.id, currentZone)

    if result and result.success then
        notify("Vehicle retrieved successfully", 'success')
        setFocus(false)
    else
        notify("Failed to retrieve vehicle", 'error')
    end

    SendNUIMessage({
        action = 'retrieveResult',
        data = { success = result and result.success == true }
    })

    cb({ ok = true, success = result and result.success == true })
end)

RegisterNUICallback('releaseVehicle', function(data, cb)
    local result = lib.callback.await('pen-impound:server:releaseVehicle', nil, data.id, currentZone)

    if result and result.success then
        notify('Vehicle released successfully', 'success')
        SendNUIMessage({ action = 'refreshVehicles' })
    else
        notify((result and result.message) or 'Failed to release vehicle', 'error')
    end

    cb({ ok = true, success = result and result.success == true })
end)

RegisterNUICallback('getAllImpounded', function(_, cb)
    local vehicles = lib.callback.await('pen-impound:server:getAllImpoundedVehicles', nil)
    cb(vehicles or {})
end)

RegisterNUICallback('getMyImpounded', function(_, cb)
    local vehicles = lib.callback.await('pen-impound:server:getImpoundedVehicles', nil)
    cb(vehicles or {})
end)

RegisterNUICallback('getImpoundLogs', function(_, cb)
    local logs = lib.callback.await('pen-impound:server:getImpoundLogs', nil)
    cb(logs or {})
end)

RegisterNUICallback('calculateFee', function(data, cb)
    local fee = lib.callback.await('pen-impound:server:calculateFee', nil, data.timestamp)
    cb(fee or 0)
end)

RegisterNetEvent('pen-impound:client:checkVehicle', function()
    if not isAuthorizedJob() then
        notify("You don't have permission to do this", 'error')
        return
    end

    local v = getVehicleNearby()
    if not v then
        notify('No vehicle found', 'error')
        return
    end

    OpenImpoundUI(v)
end)

CreateThread(function()
    setupBlips()
    registerRetrieveZones()
    addRadial()
    setupCommandMapping()
end)