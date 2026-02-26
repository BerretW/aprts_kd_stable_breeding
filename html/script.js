let currentData = {};
let selectedMother = null;
let selectedFather = null;

// Naslouchání zprávám z LUA (Client)
window.addEventListener('message', function(event) {
    let data = event.data;
    
    if (data.action === "open") {
        currentData = data;
        document.getElementById('app').style.display = 'flex';
        
        // Resetujeme stav UI při otevření
        selectedMother = null;
        selectedFather = null;
        document.getElementById('breed-btn').disabled = true;
        resetStats();
        
        // Defaultně otevřít první tab
        switchTab('new');
        
        // Vypsat data
        populateNewBreed();
        renderActiveBreedings();
    }
});

// Funkce pro přepínání tabů
function switchTab(tab) {
    // Skryjeme všechen obsah tabů a zrušíme active class u tlačítek
    document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active-tab'));
    document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
    
    // Aktivujeme vybraný tab
    document.getElementById('tab-' + tab).classList.add('active-tab');
    
    // Bezpečné nalezení tlačítka a přidání třídy active
    let activeBtn = document.querySelector(`.tab-btn[onclick="switchTab('${tab}')"]`);
    if (activeBtn) {
        activeBtn.classList.add('active');
    }
}

// ==========================================
// TAB 1: NOVÉ MNOŽENÍ
// ==========================================
function populateNewBreed() {
    const motherSelect = document.getElementById('mother-select');
    const fatherSelect = document.getElementById('father-select');
    
    // Vyčistit staré možnosti
    motherSelect.innerHTML = '<option value="" disabled selected>Vyber klisnu...</option>';
    fatherSelect.innerHTML = '<option value="" disabled selected>Vyber hřebce...</option>';
    
    currentData.horses.forEach(horse => {
        let option = document.createElement('option');
        option.value = horse.id;
        option.text = horse.name;
        
        if (horse.isFemale == 1 || horse.isFemale === true) {
            motherSelect.appendChild(option);
        } else {
            fatherSelect.appendChild(option);
        }
    });
}

// Event Listenery pro Selecty (vybírání rodičů)
document.getElementById('mother-select').addEventListener('change', function(e) {
    let horseId = parseInt(e.target.value);
    selectedMother = currentData.horses.find(h => h.id === horseId);
    
    if (selectedMother) {
        updateStats('m', selectedMother);
        checkButton();
        fetch(`https://${GetParentResourceName()}/previewHorse`, {
            method: 'POST',
            body: JSON.stringify({ type: 'mother', horse: selectedMother })
        });
    }
});

document.getElementById('father-select').addEventListener('change', function(e) {
    let horseId = parseInt(e.target.value);
    selectedFather = currentData.horses.find(h => h.id === horseId);
    
    if (selectedFather) {
        updateStats('f', selectedFather);
        checkButton();
        fetch(`https://${GetParentResourceName()}/previewHorse`, {
            method: 'POST',
            body: JSON.stringify({ type: 'father', horse: selectedFather })
        });
    }
});

function updateStats(prefix, horse) {
    document.getElementById(`${prefix}-speed`).innerText = horse.speed || 0;
    document.getElementById(`${prefix}-accel`).innerText = horse.acceleration || 0;
    document.getElementById(`${prefix}-handling`).innerText = horse.handling || 0;
    document.getElementById(`${prefix}-stamina`).innerText = horse.stamina || 0;
    document.getElementById(`${prefix}-health`).innerText = horse.health || 0;
}

function resetStats() {['m', 'f'].forEach(prefix => {
        const els =['speed', 'accel', 'handling', 'stamina', 'health'];
        els.forEach(stat => {
            const el = document.getElementById(`${prefix}-${stat}`);
            if(el) el.innerText = "-";
        });
    });
}

function checkButton() {
    const btn = document.getElementById('breed-btn');
    btn.disabled = !(selectedMother && selectedFather);
}

document.getElementById('breed-btn').addEventListener('click', function() {
    if (!selectedMother || !selectedFather) return;
    
    fetch(`https://${GetParentResourceName()}/startBreeding`, {
        method: 'POST',
        body: JSON.stringify({ 
            motherId: selectedMother.id, 
            fatherId: selectedFather.id 
        })
    });
    closeUI();
});

// ==========================================
// TAB 2: AKTIVNÍ BŘEZOSTI (PÉČE)
// ==========================================
function renderActiveBreedings() {
    const list = document.getElementById('breeding-list');
    list.innerHTML = "";

    if (!currentData.active || currentData.active.length === 0) {
        list.innerHTML = "<p style='text-align:center; padding: 20px; color:#888;'>Žádné probíhající březosti.</p>";
        return;
    }

    currentData.active.forEach(item => {
        const div = document.createElement('div');
        div.className = 'breeding-item';
        
        // Zjišťuje z DB dotazu (Server posílá isReady jako 1/0 z SQL dotazu NOW() >= ready_time)
        const isReady = (item.isReady == 1 || item.isReady === true);

        // Zobrazení zdraví (Veterinář vidí čísla, hráč jen status)
        let healthText = "";
        if (currentData.isVet) {
            healthText = `<span style="color:#ff6b6b">HP Matky: ${item.mother_health}% | HP Hříběte: ${item.foal_health}%</span>`;
        } else {
            if (item.mother_health > 80) healthText = "<span style='color:lightgreen'>Klisna vypadá naprosto zdravě.</span>";
            else if (item.mother_health > 40) healthText = "<span style='color:orange'>Klisna nevypadá nejlépe. Potřebuje péči.</span>";
            else healthText = "<span style='color:red'>Klisna je v kritickém stavu!</span>";
        }

        // Výpočet barvy a délky progress baru na jídlo
        const foodPerc = Math.min(100, (item.food_progress / currentData.config.MaxFood) * 100);

        // Vykreslení řádku
        div.innerHTML = `
            <div class="status-info">
                <strong style="color: #dcb670; font-size: 16px;">Matka #${item.mother_id} & Otec #${item.father_id}</strong><br>
                ${healthText}<br>
                Krmení: ${item.food_progress}/${currentData.config.MaxFood} 
                <div class="status-bar"><div class="bar-fill" style="width: ${foodPerc}%"></div></div>
            </div>
            <div class="action-buttons">
                <!-- Tlačítko krmení kontroluje jestli má hráč jídlo v inventáři -->
                <button class="btn-feed" onclick="doAction('feed', ${item.id})" 
                    ${currentData.inventory.food > 0 ? '' : 'disabled'} title="Máš krmení: ${currentData.inventory.food}">
                    Nakrmit
                </button>
                
                <!-- Tlačítko ošetření (je aktivní pro vety nebo pro všechny s lékem - podle zadání ho mohou použít ti co mají lék) -->
                <button class="btn-heal" onclick="doAction('heal', ${item.id})"
                    ${currentData.inventory.medicine > 0 ? '' : 'disabled'} title="Máš léků: ${currentData.inventory.medicine}">
                    Ošetřit
                </button>
                
                <!-- Tlačítko porodit je dostupné až když uplyne čas -->
                ${isReady 
                    ? `<button class="btn-claim" onclick="doAction('claim', ${item.id})">POROD</button>` 
                    : '<button disabled style="background:#444; color:#777; cursor:not-allowed; border: 1px solid #333;">Čeká...</button>'
                }
            </div>
        `;
        list.appendChild(div);
    });
}

function doAction(actionType, id) {
    fetch(`https://${GetParentResourceName()}/actionBreeding`, {
        method: 'POST',
        body: JSON.stringify({ type: actionType, id: id })
    });
    // Po provedení akce UI zavřeme, aby se aktualizovalo při příštím otevření.
    closeUI();
}

// ==========================================
// ZAVŘENÍ UI
// ==========================================
function closeUI() {
    document.getElementById('app').style.display = 'none';
    fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
}

// Tlačítko v HTML (pokud nemáš v index.html přidané 'onclick', tohle zajistí bezpečné navázání)
const closeBtn = document.querySelector('.close-btn');
if(closeBtn) {
    closeBtn.addEventListener('click', closeUI);
}