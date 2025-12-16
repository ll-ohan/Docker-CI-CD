// Variable globale pour stocker les items récupérés (pour le filtre)
let allItemsData = [];

document.addEventListener("DOMContentLoaded", () => {
  checkApiStatus();
  fetchItems();
  setupForm();
  setupSearch();
  setupSelectAll();
});

// 1. CONFIGURATION DE LA RECHERCHE INSTANTANÉE
function setupSearch() {
  const searchInput = document.getElementById("app-search");

  // Vérification de sécurité
  if (!searchInput) {
    console.error(
      "ERREUR : L'élément <input id='app-search'> est introuvable dans le HTML."
    );
    return;
  }

  console.log("Recherche initialisée avec succès");

  searchInput.addEventListener("input", (e) => {
    const searchTerm = e.target.value.toLowerCase();
    console.log("Recherche en cours :", searchTerm); // Pour voir si ça réagit
    console.log("Données disponibles :", allItemsData.length); // Vérifie qu'on a des items

    const filteredItems = allItemsData.filter(
      (item) =>
        item.name.toLowerCase().includes(searchTerm) ||
        (item.description &&
          item.description.toLowerCase().includes(searchTerm))
    );

    renderItems(filteredItems);
  });
}

// ... (setupForm et checkApiStatus restent identiques) ...

// 2. RÉCUPÉRATION DES DONNÉES
async function fetchItems() {
  const container = document.getElementById("items-container");

  try {
    const response = await fetch("/api/items");
    if (!response.ok) throw new Error("Erreur API");

    // On stocke les données dans la variable globale
    allItemsData = await response.json();

    // On lance l'affichage initial avec toutes les données
    renderItems(allItemsData);
  } catch (e) {
    container.innerHTML = `<div style="color:red; padding:20px; text-align:center;">
            Impossible de charger les conteneurs.<br>
            <small>${e.message}</small>
        </div>`;
  }
}

// 3. FONCTION D'AFFICHAGE (RENDER)
function renderItems(items) {
  const container = document.getElementById("items-container");
  container.innerHTML = "";

  if (items.length === 0) {
    container.innerHTML = `
            <div style="padding:40px; text-align:center; color:var(--text-secondary);">
                <p style="font-size:1.1em; margin-bottom:5px;">No containers found</p>
                <small>Try adjusting your search filters</small>
            </div>`;
    return;
  }

  items.forEach((item) => {
    const row = document.createElement("div");
    row.className = "item-row";

    // --- GESTION DE LA DATE ---
    const dateObj = new Date(item.created_at);
    const formattedDate = dateObj.toLocaleDateString("fr-FR", {
      day: "numeric",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    // --- GESTION DU STATUT ---
    // Simule un statut "Running" pour les ID pairs, "Exited" pour les impairs
    const isRunning = item.id % 2 === 0;
    const statusClass = isRunning ? "running" : "stopped";
    const statusTooltip = isRunning ? "Running" : "Exited";
    // Simule un port aléatoire si running
    const port = Math.floor(Math.random() * (9000 - 3000) + 3000);

    row.innerHTML = `
            <div class="col-check"><input type="checkbox"></div>
            
            <div class="col-status">
                <span class="status-icon ${statusClass}" title="${statusTooltip}"></span>
            </div>

            <div class="col-name item-name" title="${escapeHtml(item.name)}">
                ${escapeHtml(item.name)}
            </div>
            
            <div class="col-img" style="color:var(--text-secondary)" title="${escapeHtml(
              item.description
            )}">
                ${escapeHtml(item.description || "image:latest")}
            </div>
            
            <div class="col-port" style="font-family:monospace; color:var(--text-secondary);">
                ${isRunning ? `${port}:80` : "-"}
            </div>
            
            <div class="col-created" style="font-size:12px; color:var(--text-secondary);">
                ${formattedDate}
            </div>
            
            <div class="col-actions">
                <button class="delete-btn-wrapper" onclick="deleteItem(${
                  item.id
                })" title="Delete">
                    <img src="assets/bin.svg" class="action-icon bin-icon" alt="Delete">
                </button>
            </div>
        `;
    container.appendChild(row);
  });
}

// Setup Form (inchangé)
function setupForm() {
  const form = document.getElementById("add-item-form");
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const nameInput = document.getElementById("item-name");
    const descInput = document.getElementById("item-desc");
    const submitBtn = form.querySelector("button");
    const originalText = submitBtn.innerHTML;

    const payload = {
      name: nameInput.value,
      description: descInput.value || "latest",
    };

    try {
      submitBtn.disabled = true;
      submitBtn.innerHTML = "⏳";

      const response = await fetch("/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (!response.ok) throw new Error("API Error");

      nameInput.value = "";
      descInput.value = "";
      fetchItems();
    } catch (error) {
      alert(error.message);
    } finally {
      submitBtn.disabled = false;
      submitBtn.innerHTML = originalText;
    }
  });
}

// 4. GESTION DU "SELECT ALL"
function setupSelectAll() {
  // On cible la checkbox dans le header
  const headerCheckbox = document.querySelector(
    '.grid-header .col-check input[type="checkbox"]'
  );

  if (!headerCheckbox) return;

  headerCheckbox.addEventListener("change", (e) => {
    const isChecked = e.target.checked;

    // On récupère toutes les checkboxes visibles dans la liste
    const rowCheckboxes = document.querySelectorAll(
      '#items-container .item-row .col-check input[type="checkbox"]'
    );

    // On applique l'état du header à toutes les lignes
    rowCheckboxes.forEach((box) => {
      box.checked = isChecked;
    });
  });
}

// Check API Status (Mise à jour pour le footer)
async function checkApiStatus() {
  const statusEl = document.getElementById("api-status");
  const textEl = document.getElementById("status-text");

  try {
    const response = await fetch("/api/status");
    if (response.ok) {
      statusEl.className = "engine-badge online";
      textEl.innerHTML = "Engine running";
    } else {
      throw new Error("Offline");
    }
  } catch (error) {
    statusEl.className = "engine-badge offline";
    textEl.innerHTML = "Engine stopped";
  }
}

async function deleteItem(id) {
  if (!confirm("Stop and remove this container?")) return;
  try {
    await fetch(`/api/items/${id}`, { method: "DELETE" });
    fetchItems();
  } catch (e) {
    console.error(e);
  }
}

function escapeHtml(text) {
  if (!text) return text;
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}
