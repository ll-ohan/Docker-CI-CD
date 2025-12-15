document.addEventListener("DOMContentLoaded", () => {
  document.getElementById("year").textContent = new Date().getFullYear();
  checkApiStatus();
  fetchItems();
  setupForm();
});

// Configuration du formulaire d'ajout
function setupForm() {
  const form = document.getElementById("add-item-form");
  form.addEventListener("submit", async (e) => {
    e.preventDefault();

    const nameInput = document.getElementById("item-name");
    const descInput = document.getElementById("item-desc");
    const submitBtn = form.querySelector("button");

    const payload = {
      name: nameInput.value,
      description: descInput.value || null,
    };

    try {
      submitBtn.disabled = true;
      submitBtn.textContent = "Ajout...";

      const response = await fetch("/api/items", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) throw new Error("Erreur lors de l'ajout");

      // Réinitialiser le formulaire et recharger la liste
      nameInput.value = "";
      descInput.value = "";
      fetchItems();
    } catch (error) {
      alert("Erreur: " + error.message);
    } finally {
      submitBtn.disabled = false;
      submitBtn.textContent = "Ajouter";
    }
  });
}

// Fonction de suppression appelée par le bouton dans la carte
async function deleteItem(id) {
  if (!confirm("Voulez-vous vraiment supprimer cet item ?")) return;

  try {
    const response = await fetch(`/api/items/${id}`, {
      method: "DELETE",
    });

    if (response.ok) {
      fetchItems(); // Recharger la liste
    } else {
      const error = await response.json();
      alert("Erreur de suppression: " + (error.detail || "Inconnue"));
    }
  } catch (error) {
    console.error("Erreur:", error);
    alert("Impossible de joindre l'API");
  }
}

// ... (checkApiStatus reste inchangé) ...
async function checkApiStatus() {
  // ... code existant ...
  const statusEl = document.getElementById("api-status");
  const textEl = document.getElementById("status-text");

  try {
    const response = await fetch("/api/status");
    if (response.ok) {
      statusEl.classList.remove("loading", "offline");
      statusEl.classList.add("online");
      textEl.textContent = "API en ligne";
    } else {
      throw new Error("Erreur statut");
    }
  } catch (error) {
    statusEl.classList.remove("loading", "online");
    statusEl.classList.add("offline");
    textEl.textContent = "API hors ligne";
  }
}

// Modification de fetchItems pour inclure le bouton supprimer
async function fetchItems() {
  const container = document.getElementById("items-container");

  try {
    const response = await fetch("/api/items");
    if (!response.ok) throw new Error("Impossible de récupérer les items");

    const items = await response.json();
    container.innerHTML = "";

    if (items.length === 0) {
      container.innerHTML =
        '<p style="text-align:center; grid-column: 1/-1;">Aucun item trouvé.</p>';
      return;
    }

    items.forEach((item) => {
      const date = new Date(item.created_at).toLocaleDateString("fr-FR", {
        year: "numeric",
        month: "long",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      });

      const card = document.createElement("article");
      card.className = "item-card";
      // Ajout du bouton de suppression avec un attribut onclick
      card.innerHTML = `
                <div class="card-header">
                    <h2 class="item-title">${escapeHtml(item.name)}</h2>
                    <button class="delete-btn" onclick="deleteItem(${
                      item.id
                    })">×</button>
                </div>
                <p class="item-desc">${escapeHtml(
                  item.description || "Aucune description"
                )}</p>
                <div class="item-meta">Créé le ${date}</div>
            `;
      container.appendChild(card);
    });
  } catch (error) {
    container.innerHTML = `<div class="error-msg">Erreur de chargement: ${error.message}</div>`;
  }
}

// ... (escapeHtml reste inchangé) ...
function escapeHtml(text) {
  if (!text) return text;
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
