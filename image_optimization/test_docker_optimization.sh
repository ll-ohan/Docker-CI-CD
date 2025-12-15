#!/bin/bash

# Arrêter le script en cas d'erreur
set -e

# ==============================================================================
# CONFIGURATION
# ==============================================================================
BOLD='\033[1m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Noms des images temporaires pour le test
IMG_API_STD="test-api:standard"
IMG_API_OPT="test-api:optimized"
IMG_FRONT_STD="test-front:standard"
IMG_FRONT_OPT="test-front:optimized"

# Chemins des Dockerfiles
DF_API_STD="./image_optimization/Dockerfile.api"
DF_API_OPT="./api/Dockerfile"
DF_FRONT_STD="./image_optimization/Dockerfile.front"
DF_FRONT_OPT="./frontend/Dockerfile"

# Contextes de build (Où se trouvent les sources)
CTX_API="./api"
CTX_FRONT="./frontend"

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================
print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}⚖️  COMPARATEUR D'OPTIMISATION DOCKER${NC}                              ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

get_image_size() {
    # Récupère la taille en octets
    docker inspect -f "{{ .Size }}" "$1" 2>/dev/null || echo "0"
}

to_mb() {
    # Convertit octets en MB (2 décimales) via awk
    echo "$1" | awk '{printf "%.2f", $1/1024/1024}'
}

calc_diff_mb() {
    # Différence (Std - Opt)
    echo | awk "{printf \"%.2f\", ($1 - $2)/1024/1024}"
}

calc_percent() {
    # Pourcentage de réduction
    if [ "$1" -eq 0 ]; then echo "0"; return; fi
    echo | awk "{printf \"%.2f\", (($1 - $2) / $1) * 100}"
}

build_image() {
    local name=$1
    local dockerfile=$2
    local context=$3
    
    echo -e -n "  🔨 Build ${BOLD}${name}${NC}..."
    # Redirection des logs de build vers null pour garder la sortie propre
    if docker build -t "$name" -f "$dockerfile" "$context" > /dev/null 2>&1; then
        echo -e " ${GREEN}OK${NC}"
    else
        echo -e " ${RED}ÉCHEC${NC}"
        echo -e "${RED}Erreur lors du build de $name avec $dockerfile${NC}"
        exit 1
    fi
}

# ==============================================================================
# EXÉCUTION
# ==============================================================================
print_header

# 1. Vérification des fichiers
echo -e "${BOLD}1. Vérification des fichiers Dockerfiles...${NC}"
for f in "$DF_API_STD" "$DF_API_OPT" "$DF_FRONT_STD" "$DF_FRONT_OPT"; do
    if [ ! -f "$f" ]; then
        echo -e "${RED}❌ Fichier introuvable : $f${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ Tous les fichiers sont présents.${NC}\n"

# 2. Construction des images
echo -e "${BOLD}2. Construction des images (cela peut prendre un moment)...${NC}"

# API
build_image "$IMG_API_STD" "$DF_API_STD" "$CTX_API"
build_image "$IMG_API_OPT" "$DF_API_OPT" "$CTX_API" # Contexte ./api car requirements.txt y est

# FRONTEND
build_image "$IMG_FRONT_STD" "$DF_FRONT_STD" "$CTX_FRONT"
build_image "$IMG_FRONT_OPT" "$DF_FRONT_OPT" "$CTX_FRONT" # Contexte ./frontend car src/ y est

# 3. Récupération des tailles
SIZE_API_STD=$(get_image_size "$IMG_API_STD")
SIZE_API_OPT=$(get_image_size "$IMG_API_OPT")

SIZE_FRONT_STD=$(get_image_size "$IMG_FRONT_STD")
SIZE_FRONT_OPT=$(get_image_size "$IMG_FRONT_OPT")

# 4. Affichage du rapport
echo -e "\n${BOLD}3. Résultats de l'optimisation${NC}"
echo -e "${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
printf "${BOLD}%-15s %-15s %-15s %-15s %-10s${NC}\n" "IMAGE" "STANDARD" "OPTIMISÉE" "GAIN (MB)" "GAIN (%)"
echo -e "${BLUE}──────────────────────────────────────────────────────────────────────${NC}"

# Fonction d'affichage de ligne
print_row() {
    local name=$1
    local s_std=$2
    local s_opt=$3
    
    local mb_std=$(to_mb $s_std)
    local mb_opt=$(to_mb $s_opt)
    local diff=$(calc_diff_mb $s_std $s_opt)
    local perc=$(calc_percent $s_std $s_opt)
    
    # Couleur du gain : Vert si positif, Rouge si négatif (régression)
    local color=$GREEN
    if (( $(echo "$diff < 0" | bc -l) )); then color=$RED; fi
    
    printf "%-15s %-15s %-15s ${color}%-15s %-10s${NC}\n" \
        "$name" "${mb_std} MB" "${mb_opt} MB" "${diff} MB" "${perc}%"
}

print_row "API (Python)" "$SIZE_API_STD" "$SIZE_API_OPT"
print_row "Front (Nginx)" "$SIZE_FRONT_STD" "$SIZE_FRONT_OPT"

echo -e "${BLUE}──────────────────────────────────────────────────────────────────────${NC}"

# 5. Nettoyage
echo -e "\n${BOLD}4. Nettoyage des images de test...${NC}"
docker rmi "$IMG_API_STD" "$IMG_API_OPT" "$IMG_FRONT_STD" "$IMG_FRONT_OPT" > /dev/null 2>&1
echo -e "${GREEN}✓ Nettoyage terminé.${NC}"

echo -e "\n"