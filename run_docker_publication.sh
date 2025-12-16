#!/bin/bash

# ==============================================================================
# CONFIGURATION VISUELLE & VARIABLES
# ==============================================================================
BOLD='\033[1m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

ICON_LOCK="🔒"
ICON_KEY="🔑"
ICON_DOCKER="🐳"
ICON_SIGN="✍️"
ICON_UPLOAD="☁️"

# Chargement du .env
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
fi

# Configuration des images
DOCKER_NS=${DOCKER_USER:-local}
API_IMAGE="${DOCKER_NS}/tdocker-api:latest"
FRONT_IMAGE="${DOCKER_NS}/tdfront-front:latest"

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================
print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}${ICON_DOCKER} DOCKER PUBLICATION${NC}                                 ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Features:${NC} SBOM • Provenance • DCT Signing                        ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "\n${BOLD}${BLUE}┌── $1 ──────────────────────────────────────────${NC}"
}

# Fonction pour initialiser les clés DCT si absentes
setup_dct_keys() {
    local img=$1
    echo -e "${ICON_KEY}  Vérification des clés pour $img..."
    
    # On ajoute le signer "moi" pour le repository si ce n'est pas déjà fait
    # Note : Cela nécessite les phrases de passe dans les variables d'env
    if ! docker trust inspect "$img" > /dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠ Initialisation du trust pour ce repo...${NC}"
        # Cette étape est souvent interactive la première fois. 
        # En CI/CD automatisé, il faut que les clés root existent déjà sur la machine host.
        # Ici on suppose que l'utilisateur a ses clés ou que c'est un run local.
    fi
}

push_readme() {
    local repo_name="$1"
    local readme_path="$2"
    
    # Vérification de jq
    if ! command -v jq &> /dev/null; then return; fi

    echo -e "${ICON_DOCKER}  Update README pour $repo_name..."
    if [ ! -f "$readme_path" ]; then return; fi

    local token
    token=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'"$DOCKER_USER"'", "password": "'"$DOCKER_PASS"'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)

    [ "$token" == "null" ] && return

    curl -s -o /dev/null \
        -H "Authorization: JWT $token" \
        -H "Content-Type: application/json" \
        -X PATCH \
        --data-raw "$(jq -n --arg desc "$(cat "$readme_path")" '{"full_description": $desc}')" \
        "https://hub.docker.com/v2/repositories/$repo_name/"
}

# ==============================================================================
# EXÉCUTION
# ==============================================================================

print_header

# 1. AUTHENTIFICATION
# --------------------------------------------------------------------------
print_section "Authentification"
echo -e "${ICON_LOCK}  Connexion au Docker Hub..."
if echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Connecté en tant que $DOCKER_USER${NC}"
else
    echo -e "  ${RED}✗ Échec de la connexion${NC}"
    exit 1
fi

# 2. PRÉPARATION BUILDKIT (Pour SBOM/Provenance)
# --------------------------------------------------------------------------
print_section "Configuration Buildx (Moteur Avancé)"

# On utilise un builder containerisé pour supporter les attestations complexes
if ! docker buildx inspect secure_builder > /dev/null 2>&1; then
    docker buildx create --use --name secure_builder --driver docker-container --bootstrap > /dev/null 2>&1
else
    docker buildx use secure_builder > /dev/null 2>&1
fi
echo -e "  ${GREEN}✓ Builder 'secure_builder' actif${NC}"

# 3. BUILD & PUSH (Artifacts + Attestations)
# --------------------------------------------------------------------------
print_section "Phase 1 : Build & Push (avec Attestations)"
echo -e "${ICON_UPLOAD}  Génération des images, SBOMs et Provenance..."

# L'option --push ici envoie tout au registre, mais SANS signature DCT pour l'instant
if docker buildx bake \
    --push \
    --set *.attest=type=sbom \
    --set *.attest=type=provenance,mode=max \
    api front; then
    
    echo -e "  ${GREEN}✓ Images et métadonnées de sécurité poussées.${NC}"
else
    echo -e "  ${RED}✗ Erreur lors du build/push.${NC}"
    exit 1
fi

# 4. SIGNATURE DCT (Docker Content Trust)
# --------------------------------------------------------------------------
print_section "Phase 2: Signature Cosign (Modern)"

# Check if cosign is installed
if ! command -v cosign &> /dev/null; then
    echo -e "${RED}Error: cosign is not installed.${NC}"
    exit 1
fi

sign_image_cosign() {
    #Need Cosign installed and cosign.key available
    local img=$1
    echo -e "\n${ICON_SIGN}  Signature Cosign de : ${PURPLE}$img${NC}"
    
    # You need a cosign.key key pair generated beforehand
    # Ideally pass the password via env var COSIGN_PASSWORD
    if cosign sign --yes --key cosign.key "$img"; then
        echo -e "  ${GREEN}✓ Signature Cosign validée${NC}"
    else
        echo -e "  ${RED}✗ Échec de la signature Cosign${NC}"
        exit 1
    fi
}

ERR_SIGN=0
sign_image_cosign "$API_IMAGE" || ERR_SIGN=1
sign_image_cosign "$FRONT_IMAGE" || ERR_SIGN=1

if [ $ERR_SIGN -eq 1 ]; then
    echo -e "\n${RED}⚠️  Attention : Les images sont en ligne mais la signature a échoué.${NC}"
    exit 1
fi

# 5. DOCUMENTATION (Optionnel)
# --------------------------------------------------------------------------
print_section "Documentation"
push_readme "${DOCKER_USER}/tdocker-api" "./api/README.md"
push_readme "${DOCKER_USER}/tdfront-front" "./front/README.md"

# ==============================================================================
# CONCLUSION
# ==============================================================================
echo -e "\n${GREEN}${BOLD}🚀 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS${NC}"
echo -e "   ├─ Images  : ${GREEN}OK${NC}"
echo -e "   ├─ SBOM    : ${GREEN}OK${NC} (Visibles dans Docker Scout)"
echo -e "   └─ DCT     : ${GREEN}OK${NC} (Images signées)"
echo ""
exit 0