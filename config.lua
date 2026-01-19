Config = {}

Config.ImpoundZones = {
    {
        name = "police_impound",
        coords = vector3(408.95, -1625.51, 29.29),
        heading = 228.84,
        blip = {
            enabled = true,
            sprite = 68,
            color = 3,
            scale = 0.8,
            label = "Police Impound Lot"
        }
    },
    {
        name = "sandy_impound",
        coords = vector3(1651.38, 3804.84, 38.65),
        heading = 215.0,
        blip = {
            enabled = true,
            sprite = 68,
            color = 3,
            scale = 0.8,
            label = "Sandy Shores Impound"
        }
    },
    {
        name = "paleto_impound",
        coords = vector3(-234.82, 6198.65, 31.94),
        heading = 140.0,
        blip = {
            enabled = true,
            sprite = 68,
            color = 3,
            scale = 0.8,
            label = "Paleto Bay Impound"
        }
    }
}

Config.VehicleSpawnPoints = {
    ["police_impound"] = {
        vector4(420.15, -1638.85, 29.29, 180.0),
        vector4(424.67, -1638.85, 29.29, 180.0),
        vector4(429.19, -1638.85, 29.29, 180.0)
    },
    ["sandy_impound"] = {
        vector4(1642.38, 3796.84, 34.65, 215.0),
        vector4(1637.38, 3792.84, 34.65, 215.0)
    },
    ["paleto_impound"] = {
        vector4(-239.82, 6194.65, 31.49, 140.0),
        vector4(-244.82, 6190.65, 31.49, 140.0)
    }
}

Config.AuthorizedJobs = {
    'police',
    'bcso',
    'tow',
    'mechanic'
}

Config.ImpoundFees = {
    base = 500,
    perDay = 50,
    maxDays = 30,
    earlyReleaseFee = 250
}

Config.NotifyDuration = 5000
Config.UseTarget = true
Config.TargetDistance = 2.5
Config.ImpoundKeybind = 'F6'
Config.DatabaseUpdateInterval = 300000
Config.UITheme = {
    primaryColor = '#1971c2',
    darkMode = true
}