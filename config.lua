Config = {}
Config.Debug = false

Config.DST = 1
Config.GreenTimeStart = 16
Config.GreenTimeEnd = 23
Config.ActiveTimeStart = 23
Config.ActiveTimeEnd = 3

Config.WebHook = ""
Config.ServerName = 'WestHaven ** Loger'
Config.DiscordColor = 16753920


Config.VetJob = {
    {job = 'vet', grade = 1},
    {job = 'wapiti', grade = 2} 
}
Config.AdultAgeDays = 3
Config.BreedingTimeDays = 1 
Config.chanceToKeepMaleBreed = 50
Config.chanceToBeMale = 50

-- MUTACE
Config.mutationChance = 10
Config.MutationBoost = 15 -- Kolik % k šanci na mutaci přidá 1 použití mutagenu

Config.averageStats = { max = 110, min = 90 }

-- Nastavení přežití a péče
Config.Care = {
    MaxFood = 10,               
    BaseSurvivalChance = 40,    
    MotherDeathChance = 10,     
    
    Items = {
        -- Jídlo: "název_itemu" = kolik bodů do progress baru přidá
        food = {
            ["horse_treat"] = 2,
            ["horse_treat1"] = 2,["product_apple"] = 1, ["horse_apache_treat"] = 1
        },
        -- Léky: "název_itemu" = kolik % zdraví doplní
        medicine = {
            ["horse_heal_1"] = 20,["horse_heal_2"] = 50, ["shaman_horse_mix_1"] = 30, ["shaman_horse_mix_2"] = 30
        },
        -- Speciální itemy
        pheromone = "medical_pheromone_gel", -- Nutné pro zahájení
        mutation = "product_pheromone"           -- Item pro zvýšení šance na mutaci
    },
    
    HealthDecay = 5             
}

Config.previews = {
    valentine = {
        interaction = vec3(-373.65, 786.00, 116.17),
        male = vec4(-373.653, 785.386, 116.178, 273.751),
        female = vec4(-373.665, 787.145, 116.170, 271.054),
    },
    blackwater = {
        interaction = vec3(-861.00, -1366.00, 43.54),
        male = vec4(-861.050, -1365.625, 43.548, 90.004),
        female = vec4(-860.964, -1367.177, 43.548, 89.874),
    }
}

Config.wrongRandomColor = {[34] = true, [70] = true, [87] = true, [157] = true, 
    [194] = true, [195] = true,[196] = true, [197] = true 
}

Config.ExtremeMode = {
    enabled = true, chance = 30, fullRandomTint = true, tintRange = 50,
    randomizePalette = true,
    validPalettes = { -1543234321, 1351188960, -2016905004 }
}