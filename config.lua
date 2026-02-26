Config = {}
Config.Debug = false
Config.DST = 1
Config.GreenTimeStart = 16
Config.GreenTimeEnd = 23
Config.ActiveTimeStart = 23
Config.ActiveTimeEnd = 3


Config.WebHook =
    ""
Config.ServerName = 'WestHaven ** Loger'
Config.DiscordColor = 16753920
Config.Jobs = {
    {job = 'police', grade = 1},
    {job = 'doctor', grade = 3}
}



Config.AdultAgeDays = 14                  -- Kolik dní od `birth` musí uplynout, aby mohl kůň mít hříbě
Config.BreedingTimeDays = 0               -- Doba březosti ve skutečných dnech
Config.chanceToKeepMaleBreed = 50         -- Šance na plemeno otce (50 = 50%)
Config.chanceToBeMale = 50                -- Šance, že se narodí samec
Config.mutationChance = 20                -- Šance na mutaci tintu (barevný posun) v procentech

Config.averageStats = {                   
    max = 110,                            -- 110 = o 10% lepší než průměr rodičů
    min = 90                              -- 90 = o 10% horší než průměr rodičů
}

Config.previews = {
    valentine = {
        interaction = vec3(-373.65, 786.00, 116.17), -- Kde hráč mačká tlačítko
        male = vec4(-373.653, 785.386, 116.178, 273.751),
        female = vec4(-373.665, 787.145, 116.170, 271.054),
    },
    blackwater = {
        interaction = vec3(-861.00, -1366.00, 43.54),
        male = vec4(-861.050, -1365.625, 43.548, 90.004),
        female = vec4(-860.964, -1367.177, 43.548, 89.874),
    }
    -- Zde doplň další lokace podle tvé ukázky
}

Config.wrongRandomColor = {[34] = true, [70] = true, [87] = true, [157] = true, 
    [194] = true, [195] = true,[196] = true, [197] = true 
}

Config.ExtremeMode = {
    enabled = true,            -- Zapnout/Vypnout divoké mutace
    chance = 30,               -- Šance v %, že se u konkrétní barvy aktivuje extreme mode (např. 30% šance, že Tint0 bude random)
    fullRandomTint = true,     -- Pokud true, vybere tint 0-255. Pokud false, použije range níže.
    tintRange = 50,            -- O kolik se může barva posunout (pokud není fullRandom). Např. Parent 100 -> Child 50 až 150.
    
    randomizePalette = true,   -- Povolit změnu palety (materiálu/odlesku)
    validPalettes = {          -- Seznam palet, ze kterých může vybírat (aby koně nebyli neviditelní)
        -1543234321,           -- metaped_tint_horse (Standard)
        1351188960,            -- metaped_tint_leather
        -2016905004,           -- metaped_tint_cloth
    }
}