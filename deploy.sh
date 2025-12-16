#!/bin/bash

################################################################################
# SCRIPT D'ORCHESTRATION DE DÉPLOIEMENT COMPLET
################################################################################
# Description : Pipeline d'orchestration maître coordonnant l'ensemble du
#               processus de déploiement. Exécute séquentiellement les phases
#               de tests, sécurité, publication et déploiement avec gestion
#               d'erreurs et métriques de performance globales.
#
# Auteur      : Développement Infrastructure
# Version     : 2.0.0
# Date        : 2025-12-16
#
# Prérequis   : - Docker Engine 20.10+
#               - Docker Compose V2
#               - Bash 4.0+
#               - Scripts: run_tests.sh, run_safety.sh,
#                         run_docker_publication.sh, run_app.sh
#
# Usage       : ./deploy.sh
# Exit codes  : 0 = pipeline complet réussi
#               1 = échec à une étape du pipeline
################################################################################

set -o pipefail  # Propagation des erreurs dans les pipes

# ==============================================================================
# SECTION 1: CONFIGURATION VISUELLE & VARIABLES GLOBALES
# ==============================================================================

# ------------------------------------------------------------------------------
# 1.1 Définition des couleurs ANSI
# ------------------------------------------------------------------------------
# Utilise des séquences ANSI directes pour compatibilité maximale
BOLD='\033[1m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
YELLOW='\033[0;33m'
NC='\033[0m'  # Reset/No Color

# ------------------------------------------------------------------------------
# 1.2 Symboles pour l'affichage hiérarchique
# ------------------------------------------------------------------------------
SYMBOL_OK="[✓]"
SYMBOL_ERROR="[✗]"
SYMBOL_INFO="[i]"
SYMBOL_STAGE=">>>"
SYMBOL_PIPELINE="[PIPELINE]"
SYMBOL_COMPLETE="[DONE]"

# ------------------------------------------------------------------------------
# 1.3 Variables de timing global
# ------------------------------------------------------------------------------
GLOBAL_START=$(date +%s)              # Timestamp de début du pipeline
STAGE_COUNT=0                         # Compteur d'étapes complétées
TOTAL_STAGES=4                        # Nombre total d'étapes dans le pipeline

# ==============================================================================
# SECTION 2: FONCTIONS UTILITAIRES
# ==============================================================================

# ------------------------------------------------------------------------------
# Fonction: print_main_header
# Description: Affiche l'en-tête principal du pipeline d'orchestration
# ------------------------------------------------------------------------------
print_main_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║╔════════════════════════════════════════════════════════════════════════════════════╗║${NC}"
    echo -e "${BLUE}║║${NC}  ${BOLD}MASTER DEPLOYMENT ORCHESTRATION PIPELINE${NC}                                          ${BLUE}║║${NC}"
    echo -e "${BLUE}║║${NC}                                                                                    ${BLUE}║║${NC}"
    echo -e "${BLUE}║║${NC}  ${CYAN}Architecture:${NC} 4-Stage Sequential Pipeline with Failure Handling                   ${BLUE}║║${NC}"
    echo -e "${BLUE}║║${NC}  ${CYAN}Stages:${NC}       Quality Gate • Security Audit • Publication • Deployment            ${BLUE}║║${NC}"
    echo -e "${BLUE}║║${NC}  ${CYAN}Version:${NC}      2.0.0                                                               ${BLUE}║║${NC}"
    echo -e "${BLUE}║║${NC}  ${CYAN}Date:${NC}         $(date '+%Y-%m-%d %H:%M:%S')                                                 ${BLUE}║║${NC}"
    echo -e "${BLUE}║╚════════════════════════════════════════════════════════════════════════════════════╝║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"

    echo ""
}

# ------------------------------------------------------------------------------
# Fonction: print_stage_header
# Description: Affiche l'en-tête d'une étape du pipeline avec hiérarchie visuelle
# Arguments: $1 - Numéro de l'étape
#            $2 - Nom de l'étape
#            $3 - Description de l'étape
# ------------------------------------------------------------------------------
print_stage_header() {
    local stage_num="$1"
    local stage_name="$2"
    local stage_desc="$3"

    echo ""
    echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${PURPLE}---------------------------------------------------------------------------------------${NC}"
    echo -e "${BOLD}${PURPLE}  ${SYMBOL_STAGE} STAGE ${stage_num}/${TOTAL_STAGES}: ${stage_name}${NC}"
    echo -e "${BOLD}${PURPLE}---------------------------------------------------------------------------------------${NC}"
    echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e ""
    echo -e "  ${CYAN}${SYMBOL_INFO}${NC} ${stage_desc}"
    echo -e "${PURPLE}───────────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e ""
    echo ""
}

# ------------------------------------------------------------------------------
# Fonction: print_stage_complete
# Description: Affiche un message de succès pour une étape complétée
# Arguments: $1 - Nom de l'étape
#            $2 - Durée de l'étape en secondes
# ------------------------------------------------------------------------------
print_stage_complete() {
    local stage_name="$1"
    local duration="$2"

    echo ""
    echo -e "${GREEN}${BOLD}${SYMBOL_OK} STAGE COMPLETED:${NC} ${stage_name} ${GREEN}(durée: ${duration}s)${NC}"
}

# ------------------------------------------------------------------------------
# Fonction: print_stage_failed
# Description: Affiche un message d'erreur pour une étape échouée
# Arguments: $1 - Nom de l'étape
#            $2 - Code de sortie
#            $3 - Durée de l'étape en secondes
# ------------------------------------------------------------------------------
print_stage_failed() {
    local stage_name="$1"
    local exit_code="$2"
    local duration="$3"

    echo ""
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}${BOLD}  ${SYMBOL_ERROR} PIPELINE HALTED - STAGE FAILURE${NC}"
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${RED}${SYMBOL_ERROR}${NC} Étape échouée: ${BOLD}${stage_name}${NC}"
    echo -e "  ${YELLOW}${SYMBOL_INFO}${NC} Code de sortie: ${exit_code}"
    echo -e "  ${YELLOW}${SYMBOL_INFO}${NC} Durée avant échec: ${duration}s"
    echo ""
}

# ------------------------------------------------------------------------------
# Fonction: run_stage
# Description: Exécute un script externe représentant une étape du pipeline
#              avec gestion d'erreurs, timing et affichage hiérarchique
# Arguments: $1 - Numéro de l'étape
#            $2 - Nom de l'étape
#            $3 - Description de l'étape
#            $4 - Chemin vers le script à exécuter
# Retour: 0 si succès, 1 si échec (avec arrêt du pipeline)
# ------------------------------------------------------------------------------
run_stage() {
    local stage_num="$1"
    local stage_name="$2"
    local stage_desc="$3"
    local script_path="$4"

    # Affichage de l'en-tête de l'étape
    print_stage_header "$stage_num" "$stage_name" "$stage_desc"

    # Vérification de l'existence du script
    if [ ! -f "$script_path" ]; then
        echo -e "  ${RED}${SYMBOL_ERROR}${NC} Erreur critique: Script introuvable: ${script_path}"
        echo -e "  ${YELLOW}${SYMBOL_INFO}${NC} Assurez-vous que tous les scripts requis sont présents"
        exit 1
    fi

    # Vérification des permissions d'exécution
    if [ ! -x "$script_path" ]; then
        echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Ajout des permissions d'exécution: ${script_path}"
        chmod +x "$script_path"
    fi

    # Démarrage du chronomètre pour cette étape
    local stage_start=$(date +%s)

    # Exécution du script
    # Le script gère son propre affichage et logs
    ./"$script_path"

    # Récupération du code de sortie
    local exit_code=$?

    # Calcul de la durée de l'étape
    local stage_end=$(date +%s)
    local stage_duration=$((stage_end - stage_start))

    # Évaluation du résultat
    if [ $exit_code -eq 0 ]; then
        # Succès - incrémentation du compteur et affichage
        ((STAGE_COUNT++))
        print_stage_complete "$stage_name" "$stage_duration"
    else
        # Échec - affichage de l'erreur et arrêt du pipeline
        print_stage_failed "$stage_name" "$exit_code" "$stage_duration"

        # Calcul du temps total avant échec
        local global_end=$(date +%s)
        local total_duration=$((global_end - GLOBAL_START))

        echo -e "${YELLOW}${BOLD}Statistiques du pipeline:${NC}"
        echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Étapes complétées: ${STAGE_COUNT}/${TOTAL_STAGES}"
        echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Durée totale: ${total_duration}s"
        echo ""

        exit 1
    fi
}

# ==============================================================================
# SECTION 3: EXÉCUTION DU PIPELINE D'ORCHESTRATION
# ==============================================================================

print_main_header

echo -e "${CYAN}${BOLD}${SYMBOL_PIPELINE} Démarrage du pipeline de déploiement automatisé${NC}"
echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Timestamp de début: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Nombre d'étapes: ${TOTAL_STAGES}"
echo ""

# ------------------------------------------------------------------------------
# STAGE 1: QUALITY GATE & UNIT TESTS
# ------------------------------------------------------------------------------
# Objectif: Vérifier la qualité du code et l'exécution des tests unitaires
# Script: run_tests.sh
# Outils: Black (formatage), Ruff (linting), Mypy (typage),
#         Pylint (analyse statique), Pytest (tests + couverture)
# ------------------------------------------------------------------------------
run_stage "1" \
    "Quality Gate & Unit Tests" \
    "Vérification de la qualité du code et exécution de la suite de tests" \
    "./run_tests.sh"

# ------------------------------------------------------------------------------
# STAGE 2: SECURITY AUDITS
# ------------------------------------------------------------------------------
# Objectif: Analyse de sécurité du code et des images Docker
# Script: run_safety.sh
# Outils: Bandit/Flake8 (SAST), Trivy/Docker Scout (scan de vulnérabilités)
# ------------------------------------------------------------------------------
run_stage "2" \
    "Security Audits" \
    "Analyse statique de sécurité et scan des vulnérabilités des images" \
    "./run_safety.sh"

# ------------------------------------------------------------------------------
# STAGE 3: DOCKER REGISTRY PUBLICATION
# ------------------------------------------------------------------------------
# Objectif: Construction finale, signature et publication des images
# Script: run_docker_publication.sh
# Outils: Docker Buildx (build multi-plateforme), SBOM, Provenance, Cosign
# ------------------------------------------------------------------------------
run_stage "3" \
    "Docker Registry Publication" \
    "Build sécurisé, génération SBOM/Provenance et publication sur Docker Hub" \
    "./run_docker_publication.sh"

# ------------------------------------------------------------------------------
# STAGE 4: PRODUCTION DEPLOYMENT
# ------------------------------------------------------------------------------
# Objectif: Déploiement de la stack et vérification de santé
# Script: run_app.sh
# Outils: Docker Compose (orchestration), Healthchecks, métriques
# ------------------------------------------------------------------------------
run_stage "4" \
    "Production Deployment" \
    "Déploiement de la stack complète avec healthchecks et métriques" \
    "./run_app.sh"

# ==============================================================================
# SECTION 4: RAPPORT FINAL DU PIPELINE
# ==============================================================================

# Calcul de la durée totale du pipeline
GLOBAL_END=$(date +%s)
TOTAL_DURATION=$((GLOBAL_END - GLOBAL_START))

# Conversion en minutes et secondes pour l'affichage
MINUTES=$((TOTAL_DURATION / 60))
SECONDS=$((TOTAL_DURATION % 60))

echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ${SYMBOL_COMPLETE} PIPELINE DEPLOYMENT SUCCESSFUL${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Récapitulatif des étapes
echo -e "${BOLD}${CYAN}Récapitulatif du pipeline:${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────────────────────────────${NC}"
printf "${BOLD}%-35s${NC} : ${GREEN}%s${NC}\n" "Étape 1 - Quality Gate" "PASS"
printf "${BOLD}%-35s${NC} : ${GREEN}%s${NC}\n" "Étape 2 - Security Audits" "PASS"
printf "${BOLD}%-35s${NC} : ${GREEN}%s${NC}\n" "Étape 3 - Registry Publication" "PASS"
printf "${BOLD}%-35s${NC} : ${GREEN}%s${NC}\n" "Étape 4 - Production Deployment" "PASS"
echo -e "${CYAN}───────────────────────────────────────────────────────────────────────────────────────${NC}"

# Métriques de performance
echo ""
echo -e "${BOLD}${CYAN}Métriques de performance:${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────────────────────────────${NC}"
printf "${BOLD}%-35s${NC} : ${CYAN}%dm %ds${NC}\n" "Durée totale du pipeline" "$MINUTES" "$SECONDS"
printf "${BOLD}%-35s${NC} : ${CYAN}%s / %s${NC}\n" "Étapes complétées" "$STAGE_COUNT" "$TOTAL_STAGES"
printf "${BOLD}%-35s${NC} : ${GREEN}%s${NC}\n" "Statut global" "ALL SYSTEMS OPERATIONAL"
echo -e "${CYAN}───────────────────────────────────────────────────────────────────────────────────────${NC}"

echo ""
echo -e "${GREEN}${BOLD}${SYMBOL_OK} L'application est maintenant déployée et opérationnelle${NC}"
echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Timestamp de fin: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

exit 0
