local VORPcore = exports.vorp_core:GetCore()
local keys = { ['G'] = 0x760A9C6F, ['H'] = 0x24978A28 } 

local currentStable = nil
local previewPeds = { mother = nil, father = nil }

-- Hlavní smyčka pro interakci (stejná jako předtím)
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
                        DrawText3D(data.interaction.x, data.interaction.y, data.interaction.z, "[G] Množení koní | [H] Vyzvednout hříbě")
                        
                        if IsControlJustPressed(0, keys['G']) then
                            currentStable = stableName
                            TriggerServerEvent('aprts_kd_breeding:requestHorses', stableName)
                        elseif IsControlJustPressed(0, keys['H']) then
                            TriggerServerEvent('aprts_kd_breeding:claimFoal', stableName)
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

-- NUI Events (stejné jako předtím)
RegisterNetEvent('aprts_kd_breeding:openNUI')
AddEventHandler('aprts_kd_breeding:openNUI', function(horses)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "open", horses = horses })
end)

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
    SetNuiFocus(false, false)
    CleanupPreviews()
    TriggerServerEvent('aprts_kd_breeding:processBreeding', data.motherId, data.fatherId, currentStable)
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

RegisterNetEvent('aprts_kd_breeding:client:receiveFoal')
-- ZMĚNA: Přidány argumenty speed, acceleration, handling do funkce
AddEventHandler('aprts_kd_breeding:client:receiveFoal', function(stable, name, isFemale, model, speed, acceleration, handling, stamina, health, visual)
    
    local componentData = {
        wearableStateHash = 0,
        palette = visual.palette,
        normal = visual.normal,
        material = visual.material,
        tint2 = visual.tint2,
        albedo = visual.albedo,
        categoryHash = 0,
        hash = 0,
        wearableState = "base",
        tint0 = visual.tint0,
        drawable = visual.drawable,
        tint1 = visual.tint1
    }

    local data = {
        model = model,
        sex = isFemale,
        
        -- ZMĚNA: Zde se nyní použijí vypočítané hodnoty, ne 1
        speed = speed,
        acceleration = acceleration,
        handling = handling,
        
        bonding = 0,
        stamina = stamina,
        health = health,
        age = 0,
        distance = 0,
        
        components = {
            horse_bodies = componentData,
            horse_heads = componentData,
            horse_manes = componentData,
            horse_tails = componentData
        }
    }

    TriggerServerEvent("kd_stable:server:addHorse", stable, name, data)
    TriggerEvent("vorp:TipRight", "Hříbě bylo úspěšně předáno do stáje!", 5000)
end)