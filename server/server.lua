local VORPcore = exports.vorp_core:GetCore()

local function CalculateChildStat(motherStat, fatherStat)
    local avg = (motherStat + fatherStat) / 2
    local multiplier = math.random(Config.averageStats.min, Config.averageStats.max) / 100.0
    -- Použijeme math.floor(x + 0.5) pro zaokrouhlování na nejbližší celé číslo, 
    -- jinak by se u malých čísel (např. Speed 3) staty nikdy nezvedly.
    return math.floor((avg * multiplier) + 0.5)
end

local function MutateTint(tint)
    -- 1. Pokud je zapnutý EXTREME MODE
    if Config.ExtremeMode.enabled and math.random(1, 100) <= Config.ExtremeMode.chance then
        if Config.ExtremeMode.fullRandomTint then
            -- Úplně náhodná barva 0-255
            local randomTint = math.random(0, 255)
            if not Config.wrongRandomColor[randomTint] then
                return randomTint
            end
        else
            -- Větší rozsah posunu (např. o 50 nahoru/dolů)
            local range = Config.ExtremeMode.tintRange
            local newTint = tint + math.random(-range, range)
            
            if newTint < 0 then newTint = 0 end
            if newTint > 255 then newTint = 255 end
            
            if not Config.wrongRandomColor[newTint] then
                return newTint
            end
        end
    end

    -- 2. Klasická mutace (pokud nepadl extreme mode nebo je vypnutý)
    if math.random(1, 100) <= Config.mutationChance then
        local modifier = math.random(-1, 1)
        local newTint = tint + modifier
        if newTint < 0 then newTint = 0 end
        if newTint > 255 then newTint = 255 end
        if Config.wrongRandomColor[newTint] then return tint end
        return newTint
    end

    -- Žádná změna
    return tint
end

-- Pomocná funkce pro Paletu
local function GetExtremePalette(currentPalette)
    if Config.ExtremeMode.enabled and Config.ExtremeMode.randomizePalette and math.random(1, 100) <= Config.ExtremeMode.chance then
        local count = #Config.ExtremeMode.validPalettes
        if count > 0 then
            return Config.ExtremeMode.validPalettes[math.random(1, count)]
        end
    end
    return currentPalette
end

-- Event 1: NUI (Beze změny, jen pro kontext)
RegisterServerEvent('aprts_kd_breeding:requestHorses')
AddEventHandler('aprts_kd_breeding:requestHorses', function(stableKey)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter

    -- PŘIDÁNO: h.speed, h.acceleration, h.handling
    exports.oxmysql:execute([[
        SELECT h.id, h.name, h.model, h.isFemale, 
               h.speed, h.acceleration, h.handling,
               s.speedTraining, s.accelerationTraining, s.handlingTraining, s.stamina, s.health,
               c.palette, c.tint0, c.tint1, c.tint2
        FROM kd_horses h
        LEFT JOIN kd_horses_stats s ON h.id = s.horseid
        LEFT JOIN kd_stable_color c ON h.id = c.id
        WHERE h.identifier = ? AND h.charid = ? AND TIMESTAMPDIFF(DAY, h.birth, NOW()) >= ?
    ]], {Character.identifier, Character.charIdentifier, Config.AdultAgeDays}, function(horses)
        if #horses == 0 then
            TriggerClientEvent("vorp:TipRight", _source, "Nemáš žádné dospělé koně!", 4000)
            return
        end
        TriggerClientEvent('aprts_kd_breeding:openNUI', _source, horses)
    end)
end)

-- Event 2: Start (Beze změny)
RegisterServerEvent('aprts_kd_breeding:processBreeding')
AddEventHandler('aprts_kd_breeding:processBreeding', function(motherId, fatherId, stableKey)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    exports.oxmysql:execute('INSERT INTO aprts_kd_breeding (identifier, charid, stable, mother_id, father_id, ready_time) VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))',
    {Character.identifier, Character.charIdentifier, stableKey, motherId, fatherId, Config.BreedingTimeDays}, function(insertId)
        if insertId then
            TriggerClientEvent("vorp:TipRight", _source, "Množení začalo! Hříbě bude připraveno za " .. Config.BreedingTimeDays .. " dny.", 5000)
        end
    end)
end)

-- Event 3: Vyzvednutí (ZDE JE ZMĚNA)
RegisterServerEvent('aprts_kd_breeding:claimFoal')
AddEventHandler('aprts_kd_breeding:claimFoal', function(stableKey)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter

    exports.oxmysql:execute('SELECT * FROM aprts_kd_breeding WHERE identifier = ? AND charid = ? AND stable = ? AND NOW() >= ready_time', 
    {Character.identifier, Character.charIdentifier, stableKey}, function(breedings)
        if breedings[1] == nil then
            TriggerClientEvent("vorp:TipRight", _source, "Žádné hříbě není připraveno k vyzvednutí.", 4000)
            return
        end

        local breeding = breedings[1]

        -- ZMĚNA: Přidáno h.speed, h.acceleration, h.handling do SELECTU
        exports.oxmysql:execute([[
            SELECT h.id, h.model, h.speed, h.acceleration, h.handling, 
                   s.speedTraining, s.accelerationTraining, s.handlingTraining, s.stamina, s.health,
                   c.drawable, c.albedo, c.normal, c.material, c.palette, c.tint0, c.tint1, c.tint2
            FROM kd_horses h
            LEFT JOIN kd_horses_stats s ON h.id = s.horseid
            LEFT JOIN kd_stable_color c ON h.id = c.id
            WHERE h.id IN (?, ?)
        ]], {breeding.mother_id, breeding.father_id}, function(parents)
            if #parents < 2 then 
                TriggerClientEvent("vorp:TipRight", _source, "Chyba: Rodiče nebyli nalezeni.", 4000)
                return 
            end
            
            local mother, father = parents[1], parents[2]
            if mother.id == breeding.father_id then mother, father = parents[2], parents[1] end

            local isMale = math.random(1, 100) <= Config.chanceToBeMale
            local isFemaleVal = not isMale 
            local finalModel = math.random(1, 100) <= Config.chanceToKeepMaleBreed and father.model or mother.model
            local parentColor = math.random(1, 100) <= 50 and mother or father
            -- ZMĚNA: Výpočet nových statů na základě rodičů
            local newSpeed = CalculateChildStat(mother.speed, father.speed)
            local newAccel = CalculateChildStat(mother.acceleration, father.acceleration)
            local newHandling = CalculateChildStat(mother.handling, father.handling)
            
            local newStamina = CalculateChildStat(mother.stamina, father.stamina)
            local newHealth = CalculateChildStat(mother.health, father.health)
            local newPalette = GetExtremePalette(parentColor.palette)
            local parentColor = math.random(1, 100) <= 50 and mother or father
            local newTint0 = MutateTint(parentColor.tint0 or 0)
            local newTint1 = MutateTint(parentColor.tint1 or 0)
            local newTint2 = MutateTint(parentColor.tint2 or 0)

            local visualData = {
                drawable = parentColor.drawable,
                albedo = parentColor.albedo,
                normal = parentColor.normal,
                material = parentColor.material,
                palette = newPalette,
                tint0 = newTint0,
                tint1 = newTint1,
                tint2 = newTint2
            }

            -- ZMĚNA: Přidány proměnné newSpeed, newAccel, newHandling do odesílání
            TriggerClientEvent('aprts_kd_breeding:client:receiveFoal', _source, stableKey, "Hříbě", isFemaleVal, finalModel, newSpeed, newAccel, newHandling, newStamina, newHealth, visualData)

            exports.oxmysql:execute('DELETE FROM aprts_kd_breeding WHERE id = ?', {breeding.id})
        end)
    end)
end)