Config = {}
Config.Debug = false
-- Nastavení časů (neměním, nechávám tvé)
Config.DST = 1
Config.GreenTimeStart = 16
Config.GreenTimeEnd = 23
Config.ActiveTimeStart = 23
Config.ActiveTimeEnd = 3

Config.WebHook = ""
Config.ServerName = 'WestHaven ** Loger'
Config.DiscordColor = 16753920

-- Nastavení Jobů (Vet vidí HP)
Config.Jobs = {
    {job = 'police', grade = 1},
    {job = 'doctor', grade = 1} -- Veterinář/Doktor
}
Config.VetJob = "vet" -- Job, který vidí přesná čísla a může léčit

Config.AdultAgeDays = 3
Config.BreedingTimeDays = 1 -- Pro testování dej 0, jinak např. 3
Config.chanceToKeepMaleBreed = 50
Config.chanceToBeMale = 50
Config.mutationChance = 20

Config.averageStats = { max = 110, min = 90 }

-- Nastavení přežití a péče
Config.Care = {
    MaxFood = 10,               -- Kolikrát musí být kůň nakrmen pro 100% bonus k přežití
    BaseSurvivalChance = 40,    -- Základní šance na přežití hříběte (bez jídla a léčby) v %
    MotherDeathChance = 10,     -- Základní šance, že matka zemře při porodu (pokud není zdravá)
    
    Items = {
        food = "horse_treat",       -- Item pro krmení (zvyšuje food_progress)
        medicine = "horse_heal_1" -- Item pro léčení (zvyšuje health matky i hříběte)
    },
    
    HealAmount = 20,            -- Kolik HP přidá lék
    HealthDecay = 5             -- Kolik HP ztratí matka/hříbě každých X hodin (řeší server tick nebo cron, zde zjednodušeno na náhodu při claimu)
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