#!/bin/bash

################################################################################
# SCRIPT DE DÉPLOIEMENT D'APPLICATION DOCKER
################################################################################
# Description : Script automatisé de déploiement pour une stack Docker composée
#               de PostgreSQL, FastAPI et Nginx. Gère la validation, le build,
#               le démarrage et fournit un rapport détaillé des métriques.
#
# Auteur      : Développement Infrastructure
# Version     : 2.0.0
# Date        : 2025-12-16
#
# Prérequis   : - Docker Engine 20.10+
#               - Docker Compose V2
#               - Bash 4.0+
#
# Usage       : ./run_app.sh
# Exit codes  : 0 = succès
#               1 = erreur de configuration/build/déploiement
################################################################################

set -o pipefail  # Propagation des erreurs dans les pipes

# ==============================================================================
# SECTION 1: CONFIGURATION VISUELLE & VARIABLES GLOBALES
# ==============================================================================

# ------------------------------------------------------------------------------
# 1.1 Définition des couleurs ANSI
# ------------------------------------------------------------------------------
# Utilise tput pour une compatibilité maximale, avec fallback sur séquences ANSI
BOLD=$(tput bold 2>/dev/null || echo -e "\033[1m")
BLUE=$(tput setaf 4 2>/dev/null || echo -e "\033[34m")
CYAN=$(tput setaf 6 2>/dev/null || echo -e "\033[36m")
GREEN=$(tput setaf 2 2>/dev/null || echo -e "\033[32m")
RED=$(tput setaf 1 2>/dev/null || echo -e "\033[31m")
PURPLE=$(tput setaf 5 2>/dev/null || echo -e "\033[35m")
YELLOW=$(tput setaf 3 2>/dev/null || echo -e "\033[33m")
NC=$(tput sgr0 2>/dev/null || echo -e "\033[0m")  # Reset/No Color

# ------------------------------------------------------------------------------
# 1.2 Symboles pour l'affichage
# ------------------------------------------------------------------------------
SYMBOL_OK="[✓]"
SYMBOL_ERROR="[✗]"
SYMBOL_INFO="[i]"
SYMBOL_ARROW="==>"
SYMBOL_WARNING="[!]"

# ------------------------------------------------------------------------------
# 1.3 Variables de timing et configuration
# ------------------------------------------------------------------------------
TOTAL_START_TIME=$(date +%s)              # Timestamp de début global
TIMEOUT=120                                # Timeout pour le healthcheck (secondes)
MIN_SERVICES_EXPECTED=3                    # Nombre minimum de services attendus
BUILD_LOG="build.log"                      # Fichier de log temporaire

# ==============================================================================
# SECTION 2: FONCTIONS UTILITAIRES
# ==============================================================================

# ------------------------------------------------------------------------------
# Fonction: human_size
# Description: Convertit une taille en octets vers un format lisible (B, KB, MB, GB)
# Arguments: $1 - Taille en octets
# Retour: Chaîne formatée (ex: "1.5GB", "256MB")
# ------------------------------------------------------------------------------
human_size() {
    local size="$1"

    # Validation: si vide, <nil> ou non-numérique => retourne 0B
    if [[ -z "$size" ]] || [[ "$size" == "<nil>" ]] || ! [[ "$size" =~ ^[0-9]+$ ]]; then
        echo "0B"
        return
    fi

    # Cas spécial: taille nulle
    if [ "$size" -eq 0 ]; then
        echo "0B"
        return
    fi

    # Calcul avec awk pour une précision maximale et portabilité
    echo "$size" | awk '{
        split("B KB MB GB TB", units);
        unit_index=1;
        while($1 > 1024) {
            $1 /= 1024;
            unit_index++
        }
        printf "%.1f%s", $1, units[unit_index]
    }'
}

# ------------------------------------------------------------------------------
# Fonction: get_rw_size
# Description: Récupère la taille de la couche d'écriture (RW Layer) d'un conteneur
# Arguments: $1 - ID du conteneur Docker
# Retour: Taille en octets (0 si erreur ou invalide)
# ------------------------------------------------------------------------------
get_rw_size() {
    local container_id="$1"

    # Validation: conteneur ID requis
    [ -z "$container_id" ] && echo "0" && return

    # Inspection Docker avec gestion d'erreur
    local raw_size
    raw_size=$(docker inspect --format='{{.SizeRw}}' "$container_id" 2>/dev/null)

    # Validation numérique stricte avant retour
    if [[ "$raw_size" =~ ^[0-9]+$ ]]; then
        echo "$raw_size"
    else
        echo "0"
    fi
}

# ------------------------------------------------------------------------------
# Fonction: get_mounted_volume_name
# Description: Extrait le nom du volume Docker monté à un chemin spécifique
# Arguments: $1 - ID du conteneur
#            $2 - Chemin de montage (ex: /var/lib/postgresql/data)
# Retour: Nom du volume ou chaîne vide
# ------------------------------------------------------------------------------
get_mounted_volume_name() {
    local container_id="$1"
    local mount_path="$2"

    # Validation: conteneur ID requis
    [ -z "$container_id" ] && return

    # Parcours des points de montage et extraction du nom du volume
    docker inspect --format='{{range .Mounts}}{{if eq .Destination "'"$mount_path"'"}}{{.Name}}{{end}}{{end}}' "$container_id" 2>/dev/null
}

# ------------------------------------------------------------------------------
# Fonction: print_header
# Description: Affiche l'en-tête du script avec informations sur la stack
# ------------------------------------------------------------------------------
print_header() {
    echo -e "${BLUE}╔═════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}APPLICATION DEPLOYMENT & ANALYTICS DASHBOARD${NC}                                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                                                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Stack Components:${NC} PostgreSQL 15 • FastAPI • Nginx                                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Version:${NC}          2.0.0                                                            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Date:${NC}             $(date '+%Y-%m-%d %H:%M:%S')                                              ${BLUE}║${NC}"
    echo -e "${BLUE}╚═════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Fonction: print_step
# Description: Affiche un en-tête de section pour une étape du déploiement
# Arguments: $1 - Titre de l'étape
# ------------------------------------------------------------------------------
print_step() {
    local text="$1"
    local box_width=85  # Largeur fixe du conteneur
    local text_length=${#text}
    local padding_length=$((box_width - text_length - 1))  # -1 pour les espaces avant/après - ajustement

    # Création de la ligne horizontale fixe
    local horizontal_line=$(printf '─%.0s' $(seq 1 $box_width))

    # Création de l'espacement dynamique après le texte
    local padding=$(printf ' %.0s' $(seq 1 $padding_length))

    echo -e "\n${BOLD}${PURPLE}┌${horizontal_line}┐${NC}"
    echo -e "${BOLD}${PURPLE}│${NC} ${text}${padding}${PURPLE}│${NC}"
    echo -e "${BOLD}${PURPLE}└${horizontal_line}┘${NC}"
}

# ------------------------------------------------------------------------------
# Fonction: print_success
# Description: Affiche un message de succès formaté
# Arguments: $1 - Message à afficher
# ------------------------------------------------------------------------------
print_success() {
    echo -e "  ${GREEN}${SYMBOL_OK}${NC} $1"
}

# ------------------------------------------------------------------------------
# Fonction: print_error
# Description: Affiche un message d'erreur formaté
# Arguments: $1 - Message à afficher
# ------------------------------------------------------------------------------
print_error() {
    echo -e "  ${RED}${SYMBOL_ERROR}${NC} $1"
}

# ------------------------------------------------------------------------------
# Fonction: print_info
# Description: Affiche un message d'information formaté
# Arguments: $1 - Message à afficher
# ------------------------------------------------------------------------------
print_info() {
    echo -e "  ${CYAN}${SYMBOL_INFO}${NC} $1"
}

# ------------------------------------------------------------------------------
# Fonction: print_warning
# Description: Affiche un message d'avertissement formaté
# Arguments: $1 - Message à afficher
# ------------------------------------------------------------------------------
print_warning() {
    echo -e "  ${YELLOW}${SYMBOL_WARNING}${NC} $1"
}

# ==============================================================================
# SECTION 3: PROCESSUS DE DÉPLOIEMENT
# ==============================================================================

# ------------------------------------------------------------------------------
# ÉTAPE 1: Validation de la configuration Docker Compose
# ------------------------------------------------------------------------------
print_header
print_step "ÉTAPE 1/4: VALIDATION DE LA CONFIGURATION"

print_info "Vérification de la syntaxe du fichier docker-compose.yml..."

if docker compose config > /dev/null 2>&1; then
    print_success "Configuration Docker Compose validée avec succès"
else
    print_error "Erreur critique: Configuration Docker Compose invalide"
    echo ""
    print_info "Détails de l'erreur:"
    docker compose config
    exit 1
fi

# ------------------------------------------------------------------------------
# ÉTAPE 2: Construction des images Docker
# ------------------------------------------------------------------------------
print_step "ÉTAPE 2/4: CONSTRUCTION DES IMAGES DOCKER"

print_info "Démarrage de la construction des images (build)..."
echo -e "  ${CYAN}${SYMBOL_ARROW}${NC} Les logs détaillés sont sauvegardés dans: ${BUILD_LOG}"

BUILD_START=$(date +%s)

# Exécution du build avec capture des logs
if ! docker compose build > "${BUILD_LOG}" 2>&1; then
    BUILD_END=$(date +%s)
    print_error "Échec de la construction des images"
    print_warning "Durée avant échec: $((BUILD_END - BUILD_START))s"
    echo ""
    print_info "Logs d'erreur:"
    echo -e "${RED}────────────────────────────────────────────────────────────────────${NC}"
    cat "${BUILD_LOG}"
    echo -e "${RED}────────────────────────────────────────────────────────────────────${NC}"
    exit 1
fi

BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

print_success "Images construites avec succès (durée: ${BUILD_DURATION}s)"
rm -f "${BUILD_LOG}"

# ------------------------------------------------------------------------------
# ÉTAPE 3: Démarrage des conteneurs et vérification de santé
# ------------------------------------------------------------------------------
print_step "ÉTAPE 3/4: DÉMARRAGE ET HEALTHCHECK DES SERVICES"

# Nettoyage préventif des conteneurs orphelins
print_info "Nettoyage des conteneurs orphelins..."
docker compose down --remove-orphans > /dev/null 2>&1

# Démarrage en mode détaché
print_info "Démarrage des conteneurs en arrière-plan..."
UP_START=$(date +%s)
docker compose up -d

# Barre de progression pour le healthcheck
print_info "Vérification de l'état de santé des services (timeout: ${TIMEOUT}s)..."

TIMEOUT_COUNT=0
HEALTHY=false
SPINNER_CHARS="/-\|"
SPINNER_INDEX=0

# Boucle de vérification avec timeout
while [ $TIMEOUT_COUNT -lt $TIMEOUT ]; do
    # Récupération des statuts de santé
    HEALTH_STATUSES=$(docker compose ps --format "{{.Health}}" 2>/dev/null | grep -v "^$")

    # Vérification si des services sont encore en démarrage ou malsains
    if [ -z "$HEALTH_STATUSES" ] || echo "$HEALTH_STATUSES" | grep -qE "starting|unhealthy"; then
        # Affichage du spinner animé
        printf "\r  ${YELLOW}[%s]${NC} Attente de disponibilité... %ds/%ds" \
            "${SPINNER_CHARS:SPINNER_INDEX:1}" "$TIMEOUT_COUNT" "$TIMEOUT"
        ((SPINNER_INDEX = (SPINNER_INDEX + 1) % ${#SPINNER_CHARS}))
        sleep 1
        ((TIMEOUT_COUNT++))
    else
        # Vérification du nombre de services actifs
        NUM_SERVICES=$(docker compose ps -q | wc -l | tr -d ' ')
        if [ "$NUM_SERVICES" -ge $MIN_SERVICES_EXPECTED ]; then
            HEALTHY=true
            break
        fi
        sleep 1
        ((TIMEOUT_COUNT++))
    fi
done

# Nettoyage de la ligne de spinner
printf "\r%80s\r" " "

UP_END=$(date +%s)
UP_DURATION=$((UP_END - UP_START))

# Évaluation du résultat du healthcheck
if [ "$HEALTHY" = true ]; then
    print_success "Tous les services sont opérationnels (durée: ${UP_DURATION}s)"
else
    print_error "Timeout atteint: Certains services ne répondent pas correctement"
    print_warning "État actuel des conteneurs:"
    echo ""
    docker compose ps
    exit 1
fi

# ==============================================================================
# SECTION 4: GÉNÉRATION DU RAPPORT DE DÉPLOIEMENT
# ==============================================================================
print_step "ÉTAPE 4/4: RAPPORT DE DÉPLOIEMENT ET MÉTRIQUES"

TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START_TIME))

# ------------------------------------------------------------------------------
# 4.1 Tableau des conteneurs
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  CONTENEURS DÉPLOYÉS${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
printf "${BOLD}%-20s %-15s %-12s %-20s %-15s${NC}\n" "NOM" "ID" "STATUT" "PORTS" "TAILLE IMAGE"
echo -e "${BOLD}───────────────────────────────────────────────────────────────────────────────────────${NC}"

# Parcours des conteneurs avec formatage JSON
docker compose ps --format json | while read -r line; do
    # Extraction des propriétés via grep (compatible avec tous les systèmes)
    NAME=$(echo "$line" | grep -o '"Name":"[^"]*' | cut -d'"' -f4)
    ID=$(echo "$line" | grep -o '"ID":"[^"]*' | cut -d'"' -f4 | cut -c1-12)
    HEALTH=$(echo "$line" | grep -o '"Health":"[^"]*' | cut -d'"' -f4)
    IMAGE=$(echo "$line" | grep -o '"Image":"[^"]*' | cut -d'"' -f4)

    # Extraction des ports exposés
    PORTS=$(docker port "$NAME" 2>/dev/null | awk '{print $3}' | tr '\n' ' ')
    [ -z "$PORTS" ] && PORTS="Internal"

    # Calcul de la taille de l'image
    IMG_SIZE=$(docker image inspect "$IMAGE" --format='{{.Size}}' 2>/dev/null)
    HUMAN_IMG_SIZE=$(human_size "$IMG_SIZE")

    # Coloration selon le statut de santé
    STATUS_COLOR=$GREEN
    [ "$HEALTH" != "healthy" ] && STATUS_COLOR=$RED

    # Affichage de la ligne du tableau
    printf "%-20s ${CYAN}%-15s${NC} ${STATUS_COLOR}%-12s${NC} %-20s %-15s\n" \
        "${NAME:0:19}" "$ID" "$HEALTH" "$PORTS" "$HUMAN_IMG_SIZE"
done

# ------------------------------------------------------------------------------
# 4.2 Analyse de l'espace disque (conteneurs et volumes)
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  ANALYSE DE L'ESPACE DISQUE${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
printf "${BOLD}%-20s %-20s %-20s %-20s${NC}\n" "SERVICE" "LAYER ÉCRITURE" "VOLUME PERSISTANT" "TOTAL"
echo -e "${BOLD}───────────────────────────────────────────────────────────────────────────────────────${NC}"

# Analyse du service de base de données
DB_ID=$(docker compose ps -q db)
DB_RW=$(get_rw_size "$DB_ID")
VOL_SIZE_BYTES=0

# Détection du volume PostgreSQL
POSTGRES_VOL_NAME=$(get_mounted_volume_name "$DB_ID" "/var/lib/postgresql/data")

if [ -n "$POSTGRES_VOL_NAME" ]; then
    # Mesure de la taille réelle du volume via conteneur temporaire Alpine
    VOL_SIZE_BYTES=$(docker run --rm -v "${POSTGRES_VOL_NAME}:/vol_data" alpine du -sb /vol_data 2>/dev/null | cut -f1)
    # Sécurité: validation numérique
    [[ ! "$VOL_SIZE_BYTES" =~ ^[0-9]+$ ]] && VOL_SIZE_BYTES=0
fi

DB_TOTAL=$((DB_RW + VOL_SIZE_BYTES))

# Affichage de la ligne pour la base de données
printf "%-20s %-20s %-20s ${BOLD}%-20s${NC}\n" \
    "db (PostgreSQL)" \
    "$(human_size "$DB_RW")" \
    "$(human_size "$VOL_SIZE_BYTES")" \
    "$(human_size "$DB_TOTAL")"

# Analyse des autres services (API et Frontend)
for service in api front; do
    CONTAINER_ID=$(docker compose ps -q "$service")
    if [ -n "$CONTAINER_ID" ]; then
        RW_SIZE=$(get_rw_size "$CONTAINER_ID")
        printf "%-20s %-20s %-20s %-20s\n" \
            "$service" \
            "$(human_size "$RW_SIZE")" \
            "-" \
            "$(human_size "$RW_SIZE")"
    fi
done

# ------------------------------------------------------------------------------
# 4.3 Récapitulatif des temps d'exécution
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  RÉCAPITULATIF DES TEMPS D'EXÉCUTION${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
printf "${BOLD}%-30s${NC} : ${CYAN}%5ds${NC}\n" "Construction des images" "$BUILD_DURATION"
printf "${BOLD}%-30s${NC} : ${CYAN}%5ds${NC}\n" "Démarrage des services" "$UP_DURATION"
echo -e "${BOLD}───────────────────────────────────────────────────────────────────────────────────────${NC}"
printf "${BOLD}%-30s${NC} : ${GREEN}%5ds${NC}\n" "DURÉE TOTALE" "$TOTAL_DURATION"

# ------------------------------------------------------------------------------
# 4.4 Message de succès final
# ------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ${SYMBOL_OK} DÉPLOIEMENT RÉUSSI - APPLICATION OPÉRATIONNELLE${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

exit 0
