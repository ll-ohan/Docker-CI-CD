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
ICON_PIPELINE="🚀"
ICON_STEP="👉"
ICON_CHECK="✅"
ICON_ERROR="💥"
ICON_TIME="⏱️"
ICON_FINISH="🏁"

# Timer global
GLOBAL_START=$(date +%s)

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================

print_main_header() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}  ${BOLD}${ICON_PIPELINE}  MASTER DEPLOYMENT PIPELINE${NC}                                ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${CYAN}Stages:${NC} Test • Security • Publish • Deploy                     ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Fonction pour exécuter une étape (un script externe)
# Usage: run_stage "Nom de l'étape" "./script.sh"
run_stage() {
    local stage_name="$1"
    local script_path="$2"

    echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${ICON_STEP}  ${BOLD}STAGE: $stage_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    # Vérification de l'existence du script
    if [ ! -f "$script_path" ]; then
        echo -e "${RED}${ICON_ERROR} Erreur critique : Le script $script_path est introuvable.${NC}"
        exit 1
    fi

    # Rendre le script exécutable si nécessaire
    if [ ! -x "$script_path" ]; then
        chmod +x "$script_path"
    fi

    # Exécution du script
    # On laisse le script gérer ses propres logs/sorties
    ./"$script_path"
    
    # Récupération du code de retour
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "\n${GREEN}${ICON_CHECK} STAGE COMPLETED: $stage_name${NC}"
    else
        echo -e "\n${RED}${ICON_ERROR} PIPELINE HALTED: Failure in stage '$stage_name' (Exit Code: $exit_code)${NC}"
        
        # Calcul du temps avant de quitter
        GLOBAL_END=$(date +%s)
        DURATION=$((GLOBAL_END - GLOBAL_START))
        echo -e "${YELLOW}Durée avant échec : ${DURATION}s${NC}"
        exit 1
    fi
}

# ==============================================================================
# EXÉCUTION DU PIPELINE
# ==============================================================================

print_main_header

# 1. TESTS UNITAIRES & QUALITÉ
# ==============================================================================
# Script : run_tests.sh
# Rôle : Vérifie le formatage, le linting, le typage et les tests unitaires via Docker.
run_stage "Quality Gate & Unit Tests" "./run_tests.sh"

# 2. SÉCURITÉ (SAST + CONTAINERS)
# ==============================================================================
# Script : run_safety.sh
# Rôle : Analyse statique du code (Bandit/Flake8) et scan des vulnérabilités images (Trivy/Scout).
run_stage "Security Audits" "./run_safety.sh"

# 3. PUBLICATION & SIGNATURE
# ==============================================================================
# Script : run_docker_publication.sh
# Rôle : Build final, Signature (Docker Content Trust) et Push vers le registre.
run_stage "Docker Registry Publication" "./run_docker_publication.sh"

# 4. DÉPLOIEMENT & UP
# ==============================================================================
# Script : run_app.sh
# Rôle : Lancement de la stack (docker compose up), Healthchecks et métriques.
run_stage "Production Deployment" "./run_app.sh"

# ==============================================================================
# RAPPORT FINAL GLOBAL
# ==============================================================================

GLOBAL_END=$(date +%s)
TOTAL_DURATION=$((GLOBAL_END - GLOBAL_START))

echo -e "\n"
echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}               ${ICON_FINISH}  ${BOLD}PIPELINE SUCCESSFUL${NC}                          ${PURPLE}║${NC}"
echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${PURPLE}║${NC}  ${BOLD}Total Time:${NC} ${TOTAL_DURATION}s                                              ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}  ${BOLD}Status:${NC}     ${GREEN}ALL SYSTEMS OPERATIONAL${NC}                          ${PURPLE}║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

exit 0