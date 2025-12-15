#!/bin/bash

# ==============================================================================
# CONFIGURATION VISUELLE & VARIABLES
# ==============================================================================
# Définition des couleurs (séquences ANSI standard)
BOLD=$(tput bold 2>/dev/null || echo -e "\033[1m")
BLUE=$(tput setaf 4 2>/dev/null || echo -e "\033[34m")
CYAN=$(tput setaf 6 2>/dev/null || echo -e "\033[36m")
GREEN=$(tput setaf 2 2>/dev/null || echo -e "\033[32m")
RED=$(tput setaf 1 2>/dev/null || echo -e "\033[31m")
PURPLE=$(tput setaf 5 2>/dev/null || echo -e "\033[35m")
NC=$(tput sgr0 2>/dev/null || echo -e "\033[0m") # Reset

# Icônes
ICON_DOCKER="🐳"
ICON_BUILD="🔨"
ICON_TIME="⏱️"
ICON_CHECK="✅"
ICON_HEALTH="❤️"
ICON_INFO="📊"
ICON_DISK="💾"

# Début du chronomètre global
TOTAL_START_TIME=$(date +%s)

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================

# Conversion octets -> format lisible (0B, 12MB, 1GB)
human_size() {
    local size="$1"
    # Nettoyage : si vide, <nil> ou non-numérique => 0
    if [[ -z "$size" ]] || [[ "$size" == "<nil>" ]] || ! [[ "$size" =~ ^[0-9]+$ ]]; then
        echo "0B"
        return
    fi
    
    if [ "$size" -eq 0 ]; then
        echo "0B"
        return
    fi

    # Calcul awk portable
    echo "$size" | awk '{ split( "B KB MB GB TB", v ); s=1; while( $1>1024 ){ $1/=1024; s++ } printf "%.1f%s", $1, v[s] }'
}

# Récupération sécurisée de la taille RW (Layer écriture)
get_rw_size() {
    local container_id="$1"
    [ -z "$container_id" ] && echo "0" && return
    
    local raw_size
    raw_size=$(docker inspect --format='{{.SizeRw}}' "$container_id" 2>/dev/null)
    
    # Validation numérique stricte
    if [[ "$raw_size" =~ ^[0-9]+$ ]]; then
        echo "$raw_size"
    else
        echo "0"
    fi
}

# Récupération sécurisée du volume monté sur un path spécifique
get_mounted_volume_name() {
    local container_id="$1"
    local mount_path="$2"
    [ -z "$container_id" ] && return
    
    # On cherche le nom du volume qui est monté à l'emplacement indiqué (ex: /var/lib/postgresql/data)
    docker inspect --format='{{range .Mounts}}{{if eq .Destination "'"$mount_path"'"}}{{.Name}}{{end}}{{end}}' "$container_id" 2>/dev/null
}

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}${ICON_DOCKER}  APPLICATION DEPLOYMENT & ANALYTICS${NC}                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Stack:${NC} Postgres • FastAPI • Nginx                                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "\n${BOLD}${PURPLE}┌── $1 ──────────────────────────────────────────${NC}"
}

# ==============================================================================
# 1. VALIDATION
# ==============================================================================
print_header
print_step "[1/4] Validation de la configuration Docker"

if docker compose config > /dev/null 2>&1; then
    echo -e "  ${GREEN}${ICON_CHECK} Syntaxe docker-compose.yml valide.${NC}"
else
    echo -e "  ${RED}❌ Erreur de configuration dans docker-compose.yml${NC}"
    docker compose config
    exit 1
fi

# ==============================================================================
# 2. CONSTRUCTION
# ==============================================================================
print_step "[2/4] Construction des images (Build)"
echo -e "  ${ICON_BUILD} Démarrage du build..."

BUILD_START=$(date +%s)
if ! docker compose build > build.log 2>&1; then
    echo -e "  ${RED}❌ Échec du build. Voir build.log.${NC}"
    cat build.log
    exit 1
fi
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))

echo -e "  ${GREEN}${ICON_CHECK} Build terminé avec succès (${BUILD_DURATION}s)${NC}"
rm -f build.log

# ==============================================================================
# 3. DÉMARRAGE & HEALTHCHECK
# ==============================================================================
print_step "[3/4] Démarrage des conteneurs"

docker compose down --remove-orphans > /dev/null 2>&1
UP_START=$(date +%s)
docker compose up -d
echo -e "  ${ICON_TIME} Attente de la disponibilité des services..."

TIMEOUT=120
COUNT=0
HEALTHY=false
sp="/-\|"
sc=0

while [ $COUNT -lt $TIMEOUT ]; do
    STATUSES=$(docker compose ps --format "{{.Health}}" 2>/dev/null | grep -v "^$")
    
    # Si on détecte "starting" ou "unhealthy" ou vide
    if [ -z "$STATUSES" ] || echo "$STATUSES" | grep -qE "starting|unhealthy"; then
        printf "\r  ⏳ En attente... [%s] %ds/%ds" "${sp:sc++:1}" "$COUNT" "$TIMEOUT"
        ((sc==${#sp})) && sc=0
        sleep 1
        ((COUNT++))
    else
        # Si tout le monde est là (au moins 3 services)
        NUM_SERVICES=$(docker compose ps -q | wc -l | tr -d ' ')
        if [ "$NUM_SERVICES" -ge 3 ]; then
            HEALTHY=true
            break
        fi
        sleep 1
        ((COUNT++))
    fi
done
printf "\r                                                        \r"

UP_END=$(date +%s)
UP_DURATION=$((UP_END - UP_START))

if [ "$HEALTHY" = true ]; then
    echo -e "  ${GREEN}${ICON_HEALTH} Tous les services sont 'Healthy' en ${UP_DURATION}s !${NC}"
else
    echo -e "  ${RED}❌ Timeout : Certains services ne sont pas prêts.${NC}"
    docker compose ps
    exit 1
fi

# ==============================================================================
# 4. RAPPORT & MÉTRIQUES
# ==============================================================================
print_step "[4/4] Rapport de déploiement"

TOTAL_END=$(date +%s)
TOTAL_DURATION=$((TOTAL_END - TOTAL_START_TIME))

# En-tête Tableau 1 (Conteneurs)
printf "${BOLD}%-20s %-15s %-12s %-20s %-15s${NC}\n" "NOM" "ID" "STATUS" "PORTS" "IMAGE SIZE"
echo -e "${BOLD}────────────────────────────────────────────────────────────────────────────────────────${NC}"

docker compose ps --format json | while read line; do
    NAME=$(echo $line | grep -o '"Name":"[^"]*' | cut -d'"' -f4)
    ID=$(echo $line | grep -o '"ID":"[^"]*' | cut -d'"' -f4 | cut -c1-12)
    HEALTH=$(echo $line | grep -o '"Health":"[^"]*' | cut -d'"' -f4)
    IMAGE=$(echo $line | grep -o '"Image":"[^"]*' | cut -d'"' -f4)
    
    PORTS=$(docker port $NAME 2>/dev/null | awk '{print $3}' | tr '\n' ' ' )
    [ -z "$PORTS" ] && PORTS="Internal"

    IMG_SIZE=$(docker image inspect $IMAGE --format='{{.Size}}' 2>/dev/null)
    HUMAN_IMG_SIZE=$(human_size "$IMG_SIZE")

    COLOR=$GREEN
    [ "$HEALTH" != "healthy" ] && COLOR=$RED
    
    printf "%-20s ${CYAN}%-15s${NC} ${COLOR}%-12s${NC} %-20s %-15s\n" \
        "${NAME:0:19}" "$ID" "$HEALTH" "$PORTS" "$HUMAN_IMG_SIZE"
done

echo ""
echo -e "${BOLD}${ICON_DISK} ANALYSE DE L'ESPACE DISQUE (Conteneurs & Volumes)${NC}"
echo -e "${BOLD}──────────────────────────────────────────────────────────────────────${NC}"
printf "${BOLD}%-20s %-20s %-20s %-20s${NC}\n" "SERVICE" "LAYER ECRITURE" "VOLUME PERSISTANT" "TOTAL RÉEL"

# --- DB ---
DB_ID=$(docker compose ps -q db)
DB_RW=$(get_rw_size "$DB_ID")
VOL_SIZE_BYTES=0

# Récupération intelligente du nom du volume monté sur /var/lib/postgresql/data
REAL_VOL_NAME=$(get_mounted_volume_name "$DB_ID" "/var/lib/postgresql/data")

if [ ! -z "$REAL_VOL_NAME" ]; then
    # On mesure le volume
    VOL_SIZE_BYTES=$(docker run --rm -v "${REAL_VOL_NAME}:/vol_data" alpine du -sb /vol_data 2>/dev/null | cut -f1)
    # Sécurité si échec
    [[ ! "$VOL_SIZE_BYTES" =~ ^[0-9]+$ ]] && VOL_SIZE_BYTES=0
fi

DB_TOTAL=$((DB_RW + VOL_SIZE_BYTES))

printf "%-20s %-20s %-20s ${BOLD}%-20s${NC}\n" \
    "db (Postgres)" \
    "$(human_size $DB_RW)" \
    "$(human_size $VOL_SIZE_BYTES)" \
    "$(human_size $DB_TOTAL)"

# --- API & FRONT ---
for svc in api front; do
    CID=$(docker compose ps -q $svc)
    if [ ! -z "$CID" ]; then
        RW=$(get_rw_size "$CID")
        printf "%-20s %-20s %-20s %-20s\n" \
            "$svc" \
            "$(human_size $RW)" \
            "-" \
            "$(human_size $RW)"
    fi
done

echo -e "\n${BOLD}${ICON_INFO} RÉCAPITULATIF DES TEMPS${NC}"
echo -e "├─ Construction : ${CYAN}${BUILD_DURATION}s${NC}"
echo -e "├─ Démarrage    : ${CYAN}${UP_DURATION}s${NC}"
echo -e "└─ ${BOLD}TOTAL        : ${GREEN}${TOTAL_DURATION}s${NC}"

echo -e "\n${GREEN}${BOLD}🚀 Application accessible !${NC}"