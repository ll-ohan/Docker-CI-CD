#!/bin/bash

# ==============================================================================
# CONFIGURATION VISUELLE & VARIABLES
# ==============================================================================
# Couleurs ANSI
BOLD='\033[1m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Icônes
ICON_SEC="🛡️"
ICON_SCAN="📡"
ICON_CHECK="✅"
ICON_ERROR="❌"
ICON_WARN="⚠️"
ICON_PYTHON="🐍"
ICON_DOCKER="🐳"
ICON_TRIVY="🔹"
ICON_SCOUT="🔸"

# Chargement du .env
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
fi

# Définition des noms d'images
DOCKER_NS=${DOCKER_USER:-local}
API_IMAGE="${DOCKER_NS}/tdocker-api:latest"
FRONT_IMAGE="${DOCKER_NS}/tdfront-front:latest"

# ==============================================================================
# FONCTIONS D'AFFICHAGE
# ==============================================================================
print_header() {
    clear
    echo -e "${RED}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}  ${BOLD}${ICON_SEC}  SECURITY PIPELINE (DUAL ENGINE)${NC}                           ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${CYAN}Code:${NC} Flake8 • Bandit                                        ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${CYAN}Container:${NC} Trivy ${ICON_TRIVY} + Docker Scout ${ICON_SCOUT}                    ${RED}║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "\n${BOLD}${BLUE}┌── $1 ──────────────────────────────────────────${NC}"
}

# ==============================================================================
# EXÉCUTION DU PIPELINE
# ==============================================================================

print_header

# --------------------------------------------------------------------------
# ÉTAPE 1 : ANALYSE STATIQUE DU CODE (SAST)
# --------------------------------------------------------------------------
if [ ! -d "./api" ]; then
    echo -e "${RED}${ICON_ERROR} Erreur : Le dossier ./api est introuvable.${NC}"
    exit 1
fi

echo -e "${ICON_PYTHON}  Démarrage de l'analyseur statique Python..."

docker run --rm -v "$(pwd)/api:/app" -w /app python:3.11-slim /bin/bash -c '
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    CYAN="\033[0;36m"
    NC="\033[0m"
    BOLD="\033[1m"

    ERR_FLAKE8=0
    ERR_BANDIT=0

    echo -e "${CYAN}→ Installation des outils SAST...${NC}"
    pip install -q --disable-pip-version-check flake8 bandit > /dev/null 2>&1

    # 1. FLAKE8
    echo -e "\n${BOLD}${CYAN}[1/2] 🧹 Analyse de style (Flake8)${NC}"
    if flake8 src/ --count --select=E9,F63,F7,F82 --show-source --statistics; then
        echo -e "  ${GREEN}✓ Code conforme (Critique)${NC}"
    else
        echo -e "  ${RED}✗ Violations de style détectées${NC}"
        ERR_FLAKE8=1
    fi

    # 2. BANDIT
    echo -e "\n${BOLD}${CYAN}[2/2] 🕵️  Recherche de failles (Bandit)${NC}"
    if bandit -r src/ -ll -q; then
        echo -e "  ${GREEN}✓ Aucune faille évidente${NC}"
    else
        echo -e "  ${RED}✗ Failles potentielles détectées${NC}"
        bandit -r src/ -ll -f screen
        ERR_BANDIT=1
    fi
    
    exit $((ERR_FLAKE8 + ERR_BANDIT))
'

SAST_EXIT_CODE=$?
if [ $SAST_EXIT_CODE -eq 0 ]; then RES_CODE="PASS"; else RES_CODE="FAIL"; fi

# --------------------------------------------------------------------------
# ÉTAPE 2 : CONSTRUCTION
# --------------------------------------------------------------------------
print_section "Construction des Images"
echo -e "${ICON_DOCKER}  Construction fraîche pour analyse..."
if docker compose build > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Build terminé${NC}"
else
    echo -e "  ${RED}✗ Echec du build${NC}"
    exit 1
fi

# --------------------------------------------------------------------------
# ÉTAPE 3 : DOUBLE SCAN (TRIVY + SCOUT)
# --------------------------------------------------------------------------
print_section "Double Scan de Sécurité (Trivy + Scout)"

# -- Préparation Trivy --
TRIVY_CMD=""
if command -v trivy &> /dev/null; then
    TRIVY_CMD="trivy image"
else
    TRIVY_CMD="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image"
fi

# -- Préparation Scout --
SCOUT_CMD="docker scout"
HAS_SCOUT=true
if ! docker scout version &> /dev/null; then
    HAS_SCOUT=false
    echo -e "${YELLOW}${ICON_WARN} Docker Scout non détecté. Seul Trivy sera utilisé.${NC}"
fi

# Fonction de scan unifiée
# Fonction de scan unifiée (Corrigée pour macOS/Bash 3.2)
run_dual_scan() {
    local img=$1
    local name=$2
    # CORRECTION ICI : Utilisation de 'tr' pour la compatibilité macOS au lieu de ${name^^}
    local name_upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
    
    local res_trivy="SKIP"
    local res_scout="SKIP"

    echo -e "\n${BOLD}🔎 Analyse de l'image : ${PURPLE}${name}${NC}"

    # 1. SCAN TRIVY
    echo -e "  ${ICON_TRIVY} ${BOLD}Moteur 1 : Trivy${NC}"
    if $TRIVY_CMD --severity HIGH,CRITICAL --no-progress --exit-code 1 "$img" > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓ Trivy : Clean${NC}"
        res_trivy="PASS"
    else
        echo -e "    ${RED}✗ Trivy : Vulnérabilités critiques détectées${NC}"
        # On affiche un résumé court en cas d'erreur
        $TRIVY_CMD --no-progress --scanners vuln "$img" | grep -E "Total|High|Critical" | head -n 5
        res_trivy="FAIL"
    fi

    # 2. SCAN SCOUT
    if [ "$HAS_SCOUT" = true ]; then
        echo -e "  ${ICON_SCOUT} ${BOLD}Moteur 2 : Docker Scout${NC}"
        
        # Quickview pour les recommandations
        echo -e "    ${CYAN}ℹ Aperçu des recommandations :${NC}"
        $SCOUT_CMD quickview "$img" | grep -A 2 "Base image" | sed 's/^/      /'
        
        # Analyse CVE
        if $SCOUT_CMD cves "$img" --only-severity critical,high --exit-code > /dev/null 2>&1; then
             echo -e "    ${GREEN}✓ Scout : Clean${NC}"
             res_scout="PASS"
        else
             echo -e "    ${RED}✗ Scout : Vulnérabilités détectées${NC}"
             res_scout="FAIL"
        fi
    fi

    # Export des résultats
    eval "RES_TRIVY_${name_upper}='$res_trivy'"
    eval "RES_SCOUT_${name_upper}='$res_scout'"
}

run_dual_scan "$API_IMAGE" "API"
run_dual_scan "$FRONT_IMAGE" "Front"

# ==============================================================================
# RAPPORT FINAL
# ==============================================================================
echo -e "\n"
echo -e "${RED}════════════════════════════════════════════════════════════════════${NC}"
echo -e "                        ${BOLD}RAPPORT DE SÉCURITÉ UNIFIÉ${NC}"
echo -e "${RED}════════════════════════════════════════════════════════════════════${NC}"

report_line() {
    name=$1; status=$2; engine=$3
    if [ "$status" == "PASS" ]; then
        printf " ║ %-25s ║ %-8s ║ ${GREEN}%-10s${NC} ║\n" "$name" "$engine" "SECURE"
    elif [ "$status" == "SKIP" ]; then
        printf " ║ %-25s ║ %-8s ║ ${YELLOW}%-10s${NC} ║\n" "$name" "$engine" "SKIPPED"
    else
        printf " ║ %-25s ║ %-8s ║ ${RED}%-10s${NC} ║\n" "$name" "$engine" "DANGER"
    fi
}

report_line "Code Python (SAST)" "$RES_CODE" "Bandit"
echo -e "${RED}╠───────────────────────────╬──────────╬════════════╣${NC}"
report_line "Image API" "$RES_TRIVY_API" "Trivy"
report_line "Image API" "$RES_SCOUT_API" "Scout"
echo -e "${RED}╠───────────────────────────╬──────────╬════════════╣${NC}"
report_line "Image Front" "$RES_TRIVY_FRONT" "Trivy"
report_line "Image Front" "$RES_SCOUT_FRONT" "Scout"

echo -e "${RED}╚════════════════════════════════════════════════════════════════════╝${NC}"

# Logique de sortie : Echec si Trivy OU Code échoue. 
# Scout est souvent mis en "Warn" seulement, mais ici on est strict.
if [ "$RES_CODE" != "PASS" ]; then
    echo -e "\n${RED}💥 ECHEC : Code non sécurisé.${NC}\n"
    exit 1
fi

if [ "$RES_TRIVY_API" == "FAIL" ] || [ "$RES_TRIVY_FRONT" == "FAIL" ]; then
    echo -e "\n${RED}💥 ECHEC : Trivy a bloqué le pipeline.${NC}\n"
    exit 1
fi

echo -e "\n${GREEN}${BOLD}🛡️  VALIDATION RÉUSSIE (Ready to Sign & Push)${NC}\n"
exit 0