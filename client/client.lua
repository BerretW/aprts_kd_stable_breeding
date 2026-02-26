local VORPcore = exports.vorp_core:GetCore()
local keys = { ['G'] = 0x760A9C6F } 

local currentStable = nil
local previewPeds = { mother = nil, father = nil }

-- Pomocná funkce pro inventář
function GetItemCountInInventory(inventory, item)
    if inventory and type(inventory) == "table" then
        for _, invItem in pairs(inventory) do
            if invItem.name == item then
                return invItem.count
            end
        end
    end
    return 0
end

Citizen.CreateThread(function()
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for stableName, data in pairs(Config.previews) do
            if data.interaction then
                local dist = #(coords - data.interaction)
                if dist < 10.0 then
                    wait = 0
                    Citizen.InvokeNative(0x2A32FAA57B937173, -1795314153, data.interaction.x, data.interaction.y, data.interaction.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.2, 255, 255, 0, 100, 0, 0, 2, 0, 0, 0, 0)
                    if dist < 1.5 then
                        DrawText3D(data.interaction.x, data.interaction.y, data.interaction.z, "[G] Správa chovu koní")
                        
                        if IsControlJustPressed(0, keys['G']) then
                            currentStable = stableName
                            -- Získáme inventář klienta
                            local inventory = exports.vorp_inventory:getInventoryItems()
                            local foodCount = GetItemCountInInventory(inventory, Config.Care.Items.food)
                            local medCount = GetItemCountInInventory(inventory, Config.Care.Items.medicine)
                            
                            -- Pošleme požadavek na server s info o inventáři
                            TriggerServerEvent('aprts_kd_breeding:openMenu', stableName, foodCount, medCount)
                        end
                    end
                end
            end
        end
        Citizen.Wait(wait)
    end
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFontForCurrentCommand(1)
        SetTextColor(255, 255, 255, 255)
        SetTextCentre(1)
        DisplayText(CreateVarString(10, "LITERAL_STRING", text), _x, _y)
    end
end

-- Otevření menu
RegisterNetEvent('aprts_kd_breeding:client:openMenu')
AddEventHandler('aprts_kd_breeding:client:openMenu', function(availableHorses, activeBreedings, isVet, invData)
    SetNuiFocus(true, true)
    SendNUIMessage({ 
        action = "open", 
        horses = availableHorses, 
        active = activeBreedings,
        isVet = isVet,
        inventory = invData,
        config = Config.Care
    })
end)

-- Callbacky z NUI
RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    CleanupPreviews()
    cb('ok')
end)

RegisterNUICallback('previewHorse', function(data, cb)
    SpawnPreviewHorse(data.type, data.horse)
    cb('ok')
end)

RegisterNUICallback('startBreeding', function(data, cb)
    TriggerServerEvent('aprts_kd_breeding:processBreeding', data.motherId, data.fatherId, currentStable)
    -- Zavřeme UI a vyčistíme
    SetNuiFocus(false, false)
    CleanupPreviews()
    cb('ok')
end)

RegisterNUICallback('actionBreeding', function(data, cb)
    -- data.type = "feed" nebo "heal" nebo "claim"
    -- data.id = ID breeding záznamu
    TriggerServerEvent('aprts_kd_breeding:handleAction', data.type, data.id, currentStable)
    cb('ok')
end)


-- Funkce pro náhledy koní (stejná)
function SpawnPreviewHorse(type, horseData)
    if previewPeds[type] then DeleteEntity(previewPeds[type]) end

    local hash = GetHashKey(horseData.model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end

    local stableData = Config.previews[currentStable]
    local pos = type == "mother" and stableData.female or stableData.male

    local ped = CreatePed(hash, pos.x, pos.y, pos.z - 1.0, pos.w, false, false, 0, 0)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- Set ped random outfit
    
    if horseData.palette and horseData.palette ~= "" then
        local paletteHash = tonumber(horseData.palette) or GetHashKey(horseData.palette)
        local t0 = horseData.tint0 or 0
        local t1 = horseData.tint1 or 0
        local t2 = horseData.tint2 or 0
        Citizen.InvokeNative(0x704C908E9C405136, ped, paletteHash, t0, t1, t2)
    end

    TaskStandStill(ped, -1)
    previewPeds[type] = ped
    SetModelAsNoLongerNeeded(hash)
end

function CleanupPreviews()
    if previewPeds.mother then DeleteEntity(previewPeds.mother); previewPeds.mother = nil end
    if previewPeds.father then DeleteEntity(previewPeds.father); previewPeds.father = nil end
end


-- =========================================================
--  NOVÁ ČÁST: PŘÍJEM DAT O HŘÍBĚTI A ODESLÁNÍ DO STÁJE
-- =========================================================

-- client/client.lua (část)

RegisterNetEvent('aprts_kd_breeding:client:receiveFoal')
AddEventHandler('aprts_kd_breeding:client:receiveFoal', function(stable, name, isFemale, model, speed, acceleration, handling, stamina, health, bodyVisual, hairVisual)
    
    -- Pomocná funkce pro vytvoření struktury komponenty
    local function createComponent(category, visualData, defaultIndex)
        return {
            wearableStateHash = 0, -- Nebo visualData.wearableStateHash pokud bys to tahal z DB
            palette = visualData.palette,
            normal = visualData.normal,
            material = visualData.material,
            tint2 = visualData.tint2,
            category = category,
            index = defaultIndex, -- Index se může lišit, ale pro default nastavení stačí
            albedo = visualData.albedo,
            categoryHash = 0, -- Hra si dopočítá podle modelu
            hash = 0,         -- 0 = defaultní část pro daný model koně
            wearableState = "base",
            tint0 = visualData.tint0,
            drawable = visualData.drawable, -- Pro tělo důležité, pro hřívu méně (pokud je hash 0)
            tint1 = visualData.tint1
        }
    end

    -- Sestavení kompletní struktury jako ve tvém vzoru
    local componentsData = {
        -- TĚLO A HLAVA (dědí z bodyVisual)
        horse_bodies = createComponent("horse_bodies", bodyVisual, 3),
        horse_heads  = createComponent("horse_heads", bodyVisual, 2),
        
        -- HŘÍVA A OCAS (dědí z hairVisual - může být jiná barva!)
        horse_manes  = createComponent("horse_manes", hairVisual, 5),
        horse_tails  = createComponent("horse_tails", hairVisual, 6)
    }

    -- Finální data pro kd_stable
    local data = {
        model = model,
        sex = isFemale, -- true/false
        
        speed = speed,
        acceleration = acceleration,
        handling = handling,
        
        bonding = 0,
        stamina = stamina,
        health = health,
        
        age = 0,
        distance = 0,
        
        -- Zde vkládáme novou strukturu komponent
        components = componentsData
    }

    -- Odeslání do stájí
    TriggerServerEvent("kd_stable:server:addHorse", stable, name, data)
    TriggerEvent("vorp:TipRight", "Hříbě bylo úspěšně předáno do stáje!", 5000)
end)