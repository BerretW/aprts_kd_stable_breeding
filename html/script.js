let allHorses = [];
let selectedMother = null;
let selectedFather = null;

// Naslouchání zprávám z LUA (Client)
window.addEventListener('message', function(event) {
    let data = event.data;
    
    if (data.action === "open") {
        document.getElementById('app').style.display = 'flex';
        allHorses = data.horses;
        populateDropdowns();
    }
});

// Rozdělení koní do selectů podle pohlaví
function populateDropdowns() {
    const motherSelect = document.getElementById('mother-select');
    const fatherSelect = document.getElementById('father-select');
    
    // Vyčistit staré možnosti a nechat jen placeholder
    motherSelect.innerHTML = '<option value="" disabled selected>Vyber klisnu...</option>';
    fatherSelect.innerHTML = '<option value="" disabled selected>Vyber hřebce...</option>';
    
    allHorses.forEach(horse => {
        let option = document.createElement('option');
        option.value = horse.id;
        option.text = horse.name;
        
        // OPRAVENÁ PODMÍNKA:
        // Zkontroluje, zda je hodnota 1 (number), "1" (string) nebo true (boolean)
        if (horse.isFemale == 1 || horse.isFemale === true) {
            motherSelect.appendChild(option);
        } else {
            fatherSelect.appendChild(option);
        }
    });
}

// Výběr matky
document.getElementById('mother-select').addEventListener('change', function(e) {
    let horseId = parseInt(e.target.value);
    selectedMother = allHorses.find(h => h.id === horseId);
    
    if (selectedMother) {
        updateStats('m', selectedMother);
        checkButton();
        // Pošle info zpět do hry pro spawnutí náhledu
        fetch(`https://${GetParentResourceName()}/previewHorse`, {
            method: 'POST',
            body: JSON.stringify({ type: 'mother', horse: selectedMother })
        });
    }
});

// Výběr otce
document.getElementById('father-select').addEventListener('change', function(e) {
    let horseId = parseInt(e.target.value);
    selectedFather = allHorses.find(h => h.id === horseId);
    
    if (selectedFather) {
        updateStats('f', selectedFather);
        checkButton();
        // Pošle info zpět do hry pro spawnutí náhledu
        fetch(`https://${GetParentResourceName()}/previewHorse`, {
            method: 'POST',
            body: JSON.stringify({ type: 'father', horse: selectedFather })
        });
    }
});

// Aktualizace textů se staty
function updateStats(prefix, horse) {
    // Základní staty (z tabulky kd_horses) - || 0 zajistí, že se nezobrazí "undefined"
    document.getElementById(`${prefix}-speed`).innerText = horse.speed || 0;
    document.getElementById(`${prefix}-accel`).innerText = horse.acceleration || 0;
    document.getElementById(`${prefix}-handling`).innerText = horse.handling || 0;

    // Tréninkové staty (z tabulky kd_horses_stats)
    document.getElementById(`${prefix}-stamina`).innerText = horse.stamina || 0;
    document.getElementById(`${prefix}-health`).innerText = horse.health || 0;
}

// Povolení tlačítka "Množit" pouze pokud jsou vybráni oba
function checkButton() {
    const btn = document.getElementById('breed-btn');
    if (selectedMother && selectedFather) {
        btn.disabled = false;
    } else {
        btn.disabled = true;
    }
}

// Tlačítko Zavřít (X)
document.getElementById('close-btn').addEventListener('click', function() {
    closeUI();
});

// Tlačítko Zahájit Množení
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

// Funkce pro zavření UI a reset
function closeUI() {
    document.getElementById('app').style.display = 'none';
    
    // Reset výběru
    selectedMother = null;
    selectedFather = null;
    document.getElementById('mother-select').selectedIndex = 0;
    document.getElementById('father-select').selectedIndex = 0;
    document.getElementById('breed-btn').disabled = true;

    // Reset statů na pomlčky (pro obě strany m=matka, f=otec)
    ['m', 'f'].forEach(prefix => {
        document.getElementById(`${prefix}-speed`).innerText = "-";
        document.getElementById(`${prefix}-accel`).innerText = "-";
        document.getElementById(`${prefix}-handling`).innerText = "-";
        document.getElementById(`${prefix}-stamina`).innerText = "-";
        document.getElementById(`${prefix}-health`).innerText = "-";
    });

    fetch(`https://${GetParentResourceName()}/closeUI`, { method: 'POST' });
}