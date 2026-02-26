local VORPcore = exports.vorp_core:GetCore()

-- ==========================================
-- POMOCNÉ FUNKCE PRO GENETIKU A STATY
-- ==========================================

local function CalculateChildStat(motherStat, fatherStat)
    local avg = (motherStat + fatherStat) / 2
    local multiplier = math.random(Config.averageStats.min, Config.averageStats.max) / 100.0
    return math.floor((avg * multiplier) + 0.5)
end

local function MutateTint(tint, mutationBoost)
    local currentChance = Config.mutationChance + (mutationBoost or 0)
    
    if Config.ExtremeMode.enabled and math.random(1, 100) <= Config.ExtremeMode.chance then
        if Config.ExtremeMode.fullRandomTint then
            local randomTint = math.random(0, 255)
            if not Config.wrongRandomColor[randomTint] then
                return randomTint
            end
        else
            local range = Config.ExtremeMode.tintRange
            local newTint = tint + math.random(-range, range)
            if newTint < 0 then newTint = 0 end
            if newTint > 255 then newTint = 255 end
            if not Config.wrongRandomColor[newTint] then
                return newTint
            end
        end
    end

    if math.random(1, 100) <= currentChance then
        local modifier = math.random(-1, 1)
        local newTint = tint + modifier
        if newTint < 0 then newTint = 0 end
        if newTint > 255 then newTint = 255 end
        if Config.wrongRandomColor[newTint] then return tint end
        return newTint
    end

    return tint
end

local function GetExtremePalette(currentPalette)
    if Config.ExtremeMode.enabled and Config.ExtremeMode.randomizePalette and math.random(1, 100) <= Config.ExtremeMode.chance then
        local count = #Config.ExtremeMode.validPalettes
        if count > 0 then
            return Config.ExtremeMode.validPalettes[math.random(1, count)]
        end
    end
    return currentPalette
end

local function GenerateVisualsFromParent(parentEntity, mutationBoost)
    return {
        drawable = parentEntity.drawable,
        albedo = parentEntity.albedo,
        normal = parentEntity.normal,
        material = parentEntity.material,
        palette = GetExtremePalette(parentEntity.palette),
        tint0 = MutateTint(parentEntity.tint0 or 0, mutationBoost),
        tint1 = MutateTint(parentEntity.tint1 or 0, mutationBoost),
        tint2 = MutateTint(parentEntity.tint2 or 0, mutationBoost)
    }
end

-- ==========================================
-- EVENTY
-- ==========================================

RegisterServerEvent('aprts_kd_breeding:openMenu')
AddEventHandler('aprts_kd_breeding:openMenu', function(stableKey, invData)
    local _source = source
    local User = VORPcore.getUser(_source)
    local Character = User.getUsedCharacter
    local job = Character.job
    local isVet = (job == Config.VetJob)

    -- Načtení březostí včetně jmen rodičů přes JOIN
    exports.oxmysql:execute([[
        SELECT b.*, (NOW() >= b.ready_time) AS isReady, m.name AS mother_name, f.name AS father_name 
        FROM aprts_kd_breeding b 
        LEFT JOIN kd_horses m ON b.mother_id = m.id 
        LEFT JOIN kd_horses f ON b.father_id = f.id 
        WHERE b.identifier = ? AND b.charid = ? AND b.stable = ?
    ]], {Character.identifier, Character.charIdentifier, stableKey}, function(activeBreedings)
        
        local busyHorses = {}
        for _, b in pairs(activeBreedings) do
            busyHorses[b.mother_id] = true
            busyHorses[b.father_id] = true
        end

        exports.oxmysql:execute([[
            SELECT h.id, h.name, h.model, h.isFemale, 
                   h.speed, h.acceleration, h.handling,
                   s.stamina, s.health,
                   c.palette, c.tint0, c.tint1, c.tint2
            FROM kd_horses h
            LEFT JOIN kd_horses_stats s ON h.id = s.horseid
            LEFT JOIN kd_stable_bought kb ON kb.equiped_on = h.id AND kb.category = 'horse_bodies'
            LEFT JOIN kd_stable_color c ON c.id = kb.id
            WHERE h.identifier = ? AND h.charid = ? AND TIMESTAMPDIFF(DAY, h.birth, NOW()) >= ? AND h.isDead = 0
        ]], {Character.identifier, Character.charIdentifier, Config.AdultAgeDays}, function(allHorses)
            
            local availableHorses = {}
            for _, horse in pairs(allHorses) do
                if not busyHorses[horse.id] then
                    table.insert(availableHorses, horse)
                end
            end

            TriggerClientEvent('aprts_kd_breeding:client:openMenu', _source, availableHorses, activeBreedings, isVet, invData)
        end)
    end)
end)

RegisterServerEvent('aprts_kd_breeding:processBreeding')
AddEventHandler('aprts_kd_breeding:processBreeding', function(motherId, fatherId, stableKey)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    

    exports.oxmysql:execute('SELECT id FROM aprts_kd_breeding WHERE (mother_id = ? OR father_id = ?) AND identifier = ?', {motherId, fatherId, Character.identifier}, function(result)
        if #result > 0 then
            TriggerClientEvent("vorp:TipRight", _source, "Jeden z koní už se rozmnožuje!", 4000)
            return
        end

        exports.vorp_inventory:subItem(_source, Config.Care.Items.pheromone, 1)

        exports.oxmysql:execute('INSERT INTO aprts_kd_breeding (identifier, charid, stable, mother_id, father_id, ready_time, mother_health, foal_health, food_progress, mutation_boost) VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY), 100, 100, 0, 0)',
        {Character.identifier, Character.charIdentifier, stableKey, motherId, fatherId, Config.BreedingTimeDays}, function(insertId)
            if insertId then
                TriggerClientEvent("vorp:TipRight", _source, "Množení začalo! Nezapomeň se o klisnu starat.", 5000)
            end
        end)
    end)
end)

RegisterServerEvent('aprts_kd_breeding:handleAction')
AddEventHandler('aprts_kd_breeding:handleAction', function(actionType, breedId, stableKey)
    local _source = source
    local Character = VORPcore.getUser(_source).getUsedCharacter
    
    if actionType == "feed" then
        local consumed = false
        for itemName, feedValue in pairs(Config.Care.Items.food) do
            
                exports.vorp_inventory:subItem(_source, itemName, 1)
                exports.oxmysql:execute('UPDATE aprts_kd_breeding SET food_progress = food_progress + ? WHERE id = ?', {feedValue, breedId})
                TriggerClientEvent("vorp:TipRight", _source, "Klisna nakrmena.", 3000)
                consumed = true
                break
            
        end
        if not consumed then TriggerClientEvent("vorp:TipRight", _source, "Nemáš vhodné krmení!", 3000) end

    elseif actionType == "heal_mother" or actionType == "heal_foal" then
        if Character.job ~= Config.VetJob then
            TriggerClientEvent("vorp:TipRight", _source, "Nejsi veterinář!", 3000)
            return
        end

        local consumed = false
        for itemName, healValue in pairs(Config.Care.Items.medicine) do

                exports.vorp_inventory:subItem(_source, itemName, 1)
                
                if actionType == "heal_mother" then
                    exports.oxmysql:execute('UPDATE aprts_kd_breeding SET mother_health = LEAST(100, mother_health + ?) WHERE id = ?', {healValue, breedId})
                    TriggerClientEvent("vorp:TipRight", _source, "Klisna byla ošetřena.", 3000)
                else
                    exports.oxmysql:execute('UPDATE aprts_kd_breeding SET foal_health = LEAST(100, foal_health + ?) WHERE id = ?', {healValue, breedId})
                    TriggerClientEvent("vorp:TipRight", _source, "Hříbě bylo ošetřeno.", 3000)
                end
                
                consumed = true
                break
            
        end
        if not consumed then TriggerClientEvent("vorp:TipRight", _source, "Nemáš vhodné léky!", 3000) end

    elseif actionType == "mutate" then

            exports.vorp_inventory:subItem(_source, Config.Care.Items.mutation, 1)
            exports.oxmysql:execute('UPDATE aprts_kd_breeding SET mutation_boost = mutation_boost + ? WHERE id = ?', {Config.MutationBoost, breedId})
            TriggerClientEvent("vorp:TipRight", _source, "Mutagen byl aplikován do březosti!", 3000)

    elseif actionType == "claim" then
        ClaimFoalLogic(_source, breedId, stableKey)
    end
end)

-- ==========================================
-- HLAVNÍ LOGIKA PORODU A PŘEŽITÍ
-- ==========================================
function ClaimFoalLogic(_source, breedId, stableKey)
    local Character = VORPcore.getUser(_source).getUsedCharacter

    exports.oxmysql:execute('SELECT * FROM aprts_kd_breeding WHERE id = ? AND ready_time <= NOW()', {breedId}, function(results)
        if not results[1] then
            TriggerClientEvent("vorp:TipRight", _source, "Ještě není čas nebo záznam neexistuje.", 4000)
            return
        end
        local breeding = results[1]

        local foodBonus = (breeding.food_progress / Config.Care.MaxFood) * 50
        if foodBonus > 50 then foodBonus = 50 end
        
        local healthMalus = (100 - breeding.mother_health) / 2
        
        local survivalChance = Config.Care.BaseSurvivalChance + foodBonus + (breeding.foal_health * 0.2) - healthMalus
        if survivalChance < 0 then survivalChance = 0 end
        if survivalChance > 100 then survivalChance = 100 end

        local roll = math.random(1, 100)
        
        if roll > survivalChance then
            exports.oxmysql:execute('DELETE FROM aprts_kd_breeding WHERE id = ?', {breedId})
            TriggerClientEvent("vorp:TipRight", _source, "Smutná zpráva: Hříbě nepřežilo porod.", 10000)
            
            if breeding.mother_health < 30 and math.random(1, 100) < Config.Care.MotherDeathChance then
                TriggerClientEvent("vorp:TipRight", _source, "Matka bohužel zemřela na komplikace.", 10000)
                exports.oxmysql:execute('DELETE FROM kd_horses WHERE id = ?', {breeding.mother_id})
            end
            return
        end

        exports.oxmysql:execute([[
            SELECT h.id, h.model, h.speed, h.acceleration, h.handling, 
                   s.stamina, s.health,
                   c.drawable, c.albedo, c.normal, c.material, c.palette, c.tint0, c.tint1, c.tint2
            FROM kd_horses h
            LEFT JOIN kd_horses_stats s ON h.id = s.horseid
            LEFT JOIN kd_stable_bought kb ON kb.equiped_on = h.id AND kb.category = 'horse_bodies'
            LEFT JOIN kd_stable_color c ON c.id = kb.id
            WHERE h.id IN (?, ?)
        ]], {breeding.mother_id, breeding.father_id}, function(parents)
            
            if #parents < 2 then 
                TriggerClientEvent("vorp:TipRight", _source, "Chyba: Rodiče nebyli v databázi nalezeni.", 4000)
                return 
            end
            
            local mother, father = parents[1], parents[2]
            if mother.id == breeding.father_id then mother, father = parents[2], parents[1] end

            local isMale = math.random(1, 100) <= Config.chanceToBeMale
            local isFemaleVal = not isMale 
            local finalModel = math.random(1, 100) <= Config.chanceToKeepMaleBreed and father.model or mother.model

            local newSpeed = CalculateChildStat(mother.speed, father.speed)
            local newAccel = CalculateChildStat(mother.acceleration, father.acceleration)
            local newHandling = CalculateChildStat(mother.handling, father.handling)
            local newStamina = CalculateChildStat(mother.stamina, father.stamina)
            local newHealth = CalculateChildStat(mother.health, father.health)

            local currentMutationBoost = breeding.mutation_boost or 0

            local bodyParent = (math.random(1, 100) <= 50) and mother or father
            local bodyVisuals = GenerateVisualsFromParent(bodyParent, currentMutationBoost)

            local hairParent = bodyParent
            if math.random(1, 100) <= 50 then
                hairParent = (bodyParent.id == mother.id) and father or mother
            end
            local hairVisuals = GenerateVisualsFromParent(hairParent, currentMutationBoost)

            TriggerClientEvent('aprts_kd_breeding:client:receiveFoal', _source, stableKey, "Hříbě", isFemaleVal, finalModel, newSpeed, newAccel, newHandling, newStamina, newHealth, bodyVisuals, hairVisuals)

            exports.oxmysql:execute('DELETE FROM aprts_kd_breeding WHERE id = ?', {breedId})
        end)
    end)
end