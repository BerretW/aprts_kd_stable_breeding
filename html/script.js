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
    
    fetch(`https://${GetParentResourceName()}/startBreeding`, {
        method: 'POST',
        body: JSON.stringify({ motherId: selectedMother.id, fatherId: selectedFather.id })
    });
    closeUI();
});

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
        
        const isReady = (item.isReady == 1 || item.isReady === true);

        // Zobrazení zdraví
        let mHText = currentData.isVet ? `${item.mother_health}%` : (item.mother_health > 80 ? "Zdravá" : (item.mother_health > 40 ? "Nemocná" : "Kritická"));
        let fHText = currentData.isVet ? `${item.foal_health}%` : (item.foal_health > 80 ? "Zdravé" : (item.foal_health > 40 ? "Ohrožené" : "Kritické"));
        let mCol = item.mother_health > 40 ? (item.mother_health > 80 ? 'lightgreen' : 'orange') : 'red';
        let fCol = item.foal_health > 40 ? (item.foal_health > 80 ? 'lightgreen' : 'orange') : 'red';

        const foodPerc = Math.min(100, (item.food_progress / currentData.config.MaxFood) * 100);

        let actionHtml = `<button class="btn-feed" onclick="doAction('feed', ${item.id})" ${currentData.inventory.food > 0 ? '' : 'disabled'}>Nakrmit</button>`;

        if (currentData.isVet) {
            actionHtml += `
                <button class="btn-heal" onclick="doAction('heal_mother', ${item.id})" ${currentData.inventory.medicine > 0 ? '' : 'disabled'}>Léčit klisnu</button>
                <button class="btn-heal" onclick="doAction('heal_foal', ${item.id})" ${currentData.inventory.medicine > 0 ? '' : 'disabled'}>Léčit hříbě</button>
            `;
        }

        actionHtml += `<button class="btn-mutate" onclick="doAction('mutate', ${item.id})" ${currentData.inventory.mutation > 0 ? '' : 'disabled'}>Mutagen</button>`;

        if (isReady) {
            actionHtml += `<button class="btn-claim" onclick="doAction('claim', ${item.id})">POROD</button>`;
        } else {
            actionHtml += `<button disabled style="background:#444; color:#777; cursor:not-allowed; border: 1px solid #333;">Čeká...</button>`;
        }

        div.innerHTML = `
            <div class="status-info">
                <strong style="color: #dcb670; font-size: 16px;">Matka: ${item.mother_name} & Otec: ${item.father_name}</strong><br>
                <div style="margin: 5px 0;">
                    <span style="color:${mCol}">Matka: ${mHText}</span> | 
                    <span style="color:${fCol}">Hříbě: ${fHText}</span>
                </div>
                Krmení: ${item.food_progress}/${currentData.config.MaxFood} 
                <div class="status-bar"><div class="bar-fill" style="width: ${foodPerc}%"></div></div>
            </div>
            <div class="action-buttons">
                ${actionHtml}
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
    closeUI();
}

function closeUI() {
    document.getElementById('app').style.display = 'none';
    fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
}

const closeBtn = document.querySelector('.close-btn');
if(closeBtn) {
    closeBtn.addEventListener('click', closeUI);
}