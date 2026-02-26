let currentData = {};
let selectedMother = null;
let selectedFather = null;

window.addEventListener('message', function(event) {
    let data = event.data;
    
    if (data.action === "open") {
        currentData = data;
        document.getElementById('app').style.display = 'flex';
        
        selectedMother = null;
        selectedFather = null;
        document.getElementById('breed-btn').disabled = true;
        resetStats();
        
        switchTab('new');
        populateNewBreed();
        renderActiveBreedings();
    } 
    // ZDE ZACHYTÁVÁME SERVEROVOU ODPOVĚĎ
    else if (data.action === "actionResult") {
        if (data.success) {
            showToast(data.message, "var(--rdr-green)");
            
            // Lokální aktualizace dat (aby nebylo nutné tahat DB znovu)
            if (data.actionType === 'feed') {
                let item = currentData.active.find(i => i.id == data.breedId);
                if (item) item.food_progress += data.value;
                currentData.inventory.food -= 1;
            } else if (data.actionType === 'heal_mother') {
                let item = currentData.active.find(i => i.id == data.breedId);
                if (item) item.mother_health = Math.min(100, item.mother_health + data.value);
                currentData.inventory.medicine -= 1;
            } else if (data.actionType === 'heal_foal') {
                let item = currentData.active.find(i => i.id == data.breedId);
                if (item) item.foal_health = Math.min(100, item.foal_health + data.value);
                currentData.inventory.medicine -= 1;
            } else if (data.actionType === 'mutate') {
                currentData.inventory.mutation -= 1;
            } else if (data.actionType === 'startBreeding' || data.actionType.startsWith('claim')) {
                // Po porodu / zahájení rovnou menu zavíráme
                setTimeout(() => closeUI(), 1500);
                return; 
            }

            renderActiveBreedings(); // Překreslí nová data, odblokuje tlačítka
        } else {
            showToast(data.message, "var(--rdr-red)");
            renderActiveBreedings(); // Odblokuje tlačítka po failu
            
            if (data.actionType === 'startBreeding') {
                let btn = document.getElementById('breed-btn');
                btn.disabled = false;
                btn.innerText = "Zahájit Množení";
            }
        }
    }
});

function switchTab(tab) {
    document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active-tab'));
    document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
    document.getElementById('tab-' + tab).classList.add('active-tab');
    
    let activeBtn = document.querySelector(`.tab-btn[onclick="switchTab('${tab}')"]`);
    if (activeBtn) activeBtn.classList.add('active');
}

function populateNewBreed() {
    const motherSelect = document.getElementById('mother-select');
    const fatherSelect = document.getElementById('father-select');
    
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

document.getElementById('mother-select').addEventListener('change', function(e) {
    let horseId = parseInt(e.target.value);
    selectedMother = currentData.horses.find(h => h.id === horseId);
    
    if (selectedMother) {
        updateStats('m', selectedMother);
        checkButton();
        fetch(`https://${GetParentResourceName()}/previewHorse`, {
            method: 'POST', body: JSON.stringify({ type: 'mother', horse: selectedMother })
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
            method: 'POST', body: JSON.stringify({ type: 'father', horse: selectedFather })
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

function resetStats() {
    ['m', 'f'].forEach(prefix => {
        const els =['speed', 'accel', 'handling', 'stamina', 'health'];
        els.forEach(stat => {
            const el = document.getElementById(`${prefix}-${stat}`);
            if(el) el.innerText = "-";
        });
    });
}

function checkButton() {
    const btn = document.getElementById('breed-btn');
    if (!selectedMother || !selectedFather) {
        btn.disabled = true;
        btn.innerText = "Zahájit Množení";
    } else if (currentData.inventory.pheromone <= 0) {
        btn.disabled = true;
        btn.innerText = "Chybí Pheromone Gel";
    } else {
        btn.disabled = false;
        btn.innerText = "Zahájit Množení";
    }
}

document.getElementById('breed-btn').addEventListener('click', function() {
    if (!selectedMother || !selectedFather) return;
    
    let btn = document.getElementById('breed-btn');
    btn.disabled = true;
    btn.innerText = "Zpracovávám...";

    fetch(`https://${GetParentResourceName()}/startBreeding`, {
        method: 'POST',
        body: JSON.stringify({ motherId: selectedMother.id, fatherId: selectedFather.id })
    });
});

function renderActiveBreedings() {
    const list = document.getElementById('breeding-list');
    list.innerHTML = "";

    if (!currentData.active || currentData.active.length === 0) {
        list.innerHTML = "<p style='text-align:center; padding: 40px; color:var(--rdr-text-muted); font-style: italic;'>Žádné probíhající březosti nebyly nalezeny.</p>";
        return;
    }

    currentData.active.forEach(item => {
        const div = document.createElement('div');
        div.className = 'breeding-item';
        
        const isReady = (item.isReady == 1 || item.isReady === true);

        let mHText = currentData.isVet ? `${item.mother_health}%` : (item.mother_health > 80 ? "Zdravá" : (item.mother_health > 40 ? "Nemocná" : "Kritická"));
        let fHText = currentData.isVet ? `${item.foal_health}%` : (item.foal_health > 80 ? "Zdravé" : (item.foal_health > 40 ? "Ohrožené" : "Kritické"));
        let mCol = item.mother_health > 40 ? (item.mother_health > 80 ? '#8fbc63' : '#dcb670') : '#cc4444';
        let fCol = item.foal_health > 40 ? (item.foal_health > 80 ? '#8fbc63' : '#dcb670') : '#cc4444';

        const foodPerc = Math.min(100, (item.food_progress / currentData.config.MaxFood) * 100);

        let actionHtml = `<button class="btn-feed" onclick="doAction(event, 'feed', ${item.id})" ${currentData.inventory.food > 0 ? '' : 'disabled'}>Nakrmit</button>`;

        if (currentData.isVet) {
            actionHtml += `
                <button class="btn-heal" onclick="doAction(event, 'heal_mother', ${item.id})" ${currentData.inventory.medicine > 0 ? '' : 'disabled'}>Léčit klisnu</button>
                <button class="btn-heal" onclick="doAction(event, 'heal_foal', ${item.id})" ${currentData.inventory.medicine > 0 ? '' : 'disabled'}>Léčit hříbě</button>
            `;
        }

        actionHtml += `<button class="btn-mutate" onclick="doAction(event, 'mutate', ${item.id})" ${currentData.inventory.mutation > 0 ? '' : 'disabled'}>Mutagen</button>`;

        if (isReady) {
            actionHtml += `<button class="btn-claim" onclick="doAction(event, 'claim', ${item.id})">POROD</button>`;
        } else {
            actionHtml += `<button disabled style="opacity: 0.5;">Čeká se...</button>`;
        }

        div.innerHTML = `
            <div class="status-info">
                <div class="horse-names">Matka: ${item.mother_name} &bull; Otec: ${item.father_name}</div>
                <div class="health-stats">
                    <span>Klisna: <span style="color:${mCol}; font-weight:bold;">${mHText}</span></span>
                    <span>Hříbě: <span style="color:${fCol}; font-weight:bold;">${fHText}</span></span>
                </div>
                <div class="status-bar-container">
                    Krmení: ${item.food_progress} / ${currentData.config.MaxFood}
                    <div class="status-bar"><div class="bar-fill" style="width: ${foodPerc}%"></div></div>
                </div>
            </div>
            <div class="action-buttons">
                ${actionHtml}
            </div>
        `;
        list.appendChild(div);
    });
}

function doAction(event, actionType, id) {
    let btn = event.target;
    btn.disabled = true;
    btn.innerText = "⏳..."; // Indikátor zpracování na tlačítku

    fetch(`https://${GetParentResourceName()}/actionBreeding`, {
        method: 'POST',
        body: JSON.stringify({ type: actionType, id: id })
    });
}

function showToast(text, color) {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.style.borderLeftColor = color || "var(--rdr-gold)";
    toast.innerText = text;
    
    container.appendChild(toast);
    setTimeout(() => {
        if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 3000);
}

function closeUI() {
    document.getElementById('app').style.display = 'none';
    fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
}

document.addEventListener('keydown', function(event) {
    if (event.key === "Escape") closeUI();
});