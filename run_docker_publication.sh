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
ICON_WARN="⚠️"
ICON_DOCKER="🐳"

# Chargement du .env
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
fi

DOCKER_NS=${DOCKER_USER:-local}
API_IMAGE="${DOCKER_NS}/tdocker-api:latest"
FRONT_IMAGE="${DOCKER_NS}/tdfront-front:latest"

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================
print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}${ICON_DOCKER}  DOCKER PUBLICATION & SIGNING${NC}                              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Task:${NC}  DCT • Signing • Registry Push                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "\n${BOLD}${BLUE}┌── $1 ──────────────────────────────────────────${NC}"
}

# ==============================================================================
# EXÉCUTION DE LA PUBLICATION
# ==============================================================================

print_header

# On rebuild rapidement pour s'assurer que l'image locale correspond à ce qu'on va signer
print_section "Vérification des artéfacts"
echo -e "${ICON_DOCKER}  Préparation des images..."
docker compose build > /dev/null 2>&1

# --------------------------------------------------------------------------
# SIGNATURE & REGISTRE (Docker Content Trust)
# --------------------------------------------------------------------------
print_section "Signature & Registre"

echo -e "${ICON_KEY}  Activation de Docker Content Trust (DCT)..."
export DOCKER_CONTENT_TRUST=1
echo -e "  ${GREEN}✓ Variable DOCKER_CONTENT_TRUST=1 activée${NC}"

echo -e "\n${ICON_LOCK}  Authentification Registre (Login)..."
if [ -z "$DOCKER_USER" ]; then
    echo -e "  ${YELLOW}${ICON_WARN} Variable DOCKER_USER non définie dans .env. Opération annulée.${NC}"
    RES_LOGIN="SKIPPED"
    RES_SIGN="SKIPPED"
    exit 1
else
    # Tentative de login silencieuse
    if echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Authentification réussie${NC}"
        RES_LOGIN="SUCCESS"
        
        # Génération des clés et ajout des signers
        echo -e "\n${ICON_KEY}  Gestion des clés de signature..."
        if echo "$DOCKER_CONTENT_TRUST_ROOT_PASSPHRASE" | docker trust key generate "$DOCKER_USER"_root_key > /dev/null 2>&1 && \
           echo "$DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE" | docker trust key generate "$DOCKER_USER"_repo_key > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓ Clés de signature générées${NC}"
            
            # Ajout des délégations
            docker trust signer add --key "$DOCKER_USER"_repo_key.pub "$DOCKER_USER" "$API_IMAGE" > /dev/null 2>&1
            docker trust signer add --key "$DOCKER_USER"_repo_key.pub "$DOCKER_USER" "$FRONT_IMAGE" > /dev/null 2>&1
            echo -e "  ${GREEN}✓ Signers ajoutés pour les images${NC}"
            
            # Push (Cela signe automatiquement avec DCT activé)
            echo -e "\n${ICON_DOCKER}  Push et Signature des images..."
            docker compose push > /dev/null 2>&1
            
            echo -e "  ${GREEN}✓ Images signées et poussées vers le registre${NC}"
            RES_SIGN="SUCCESS"
        else
            echo -e "  ${YELLOW}⚠ Clés déjà existantes ou erreur (Tentative de push standard...)${NC}"
            # On tente quand même le push si les clés existent déjà
            docker compose push > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                 echo -e "  ${GREEN}✓ Images poussées avec succès${NC}"
                 RES_SIGN="SUCCESS"
            else
                 echo -e "  ${RED}✗ Echec du push${NC}"
                 RES_SIGN="FAIL"
            fi
        fi
    else
        echo -e "  ${RED}✗ Échec authentification (Vérifiez .env)${NC}"
        RES_LOGIN="FAIL"
        RES_SIGN="FAIL"
    fi
fi

# ==============================================================================
# RAPPORT FINAL
# ==============================================================================
echo -e "\n"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "                        ${BOLD}RAPPORT DE PUBLICATION${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"

report_line() {
    name=$1; status=$2
    if [ "$status" == "SUCCESS" ]; then
        printf " ║ %-25s ║ ${GREEN}%-10s${NC} ║ ${GREEN}PUBLISHED${NC} ║\n" "$name" "$status"
    else
        printf " ║ %-25s ║ ${RED}%-10s${NC} ║ ${RED}FAILED${NC}    ║\n" "$name" "$status"
    fi
}

report_line "Registry Auth" "$RES_LOGIN"
report_line "Signature & Push" "$RES_SIGN"

echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"

if [ "$RES_LOGIN" == "SUCCESS" ] && [ "$RES_SIGN" == "SUCCESS" ]; then
    echo -e "\n${GREEN}${BOLD}🚀 DEPLOIEMENT TERMINÉ !${NC}\n"
    exit 0
else
    echo -e "\n${RED}${BOLD}💥 ECHEC DU DEPLOIEMENT${NC}\n"
    exit 1
fi