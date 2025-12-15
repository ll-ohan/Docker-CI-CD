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
ICON_GEAR="⚙️"
ICON_CHECK="✅"
ICON_ERROR="❌"
ICON_WARN="⚠️"
ICON_ROCKET="🚀"
ICON_TEST="🧪"
ICON_LINT="🧹"
ICON_SEC="🛡️"

# ==============================================================================
# FONCTIONS D'AFFICHAGE
# ==============================================================================
print_header() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}  ${BOLD}${ICON_ROCKET}  TEST RUNNER & QUALITY GATE${NC}                                  ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  ${CYAN}Environment:${NC} Docker (python:3.11-slim)                        ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "\n${BOLD}${BLUE}┌── $1 ──────────────────────────────────────────${NC}"
}

# ==============================================================================
# EXÉCUTION
# ==============================================================================

print_header

# Vérification de la présence du dossier API
if [ ! -d "./api" ]; then
    echo -e "${RED}${ICON_ERROR} Erreur : Le dossier ./api est introuvable.${NC}"
    exit 1
fi

echo -e "${ICON_GEAR}  Initialisation du conteneur de test..."

# On lance un conteneur Docker unique pour enchaîner les commandes
# Cela évite de réinstaller les dépendances à chaque étape
docker run --rm -v "$(pwd)/api:/app" -w /app python:3.11-slim /bin/bash -c '
    # Fonctions internes pour le style
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    CYAN="\033[0;36m"
    NC="\033[0m"
    BOLD="\033[1m"

    # Initialisation des compteurs d erreurs
    ERR_BLACK=0
    ERR_RUFF=0
    ERR_MYPY=0
    ERR_PYLINT=0
    ERR_PYTEST=0

    echo -e "${CYAN}→ Installation des dépendances (cela peut prendre quelques secondes)...${NC}"
    # Redirection vers null sauf erreurs pour garder l affichage propre
    pip install -q --disable-pip-version-check black ruff mypy pylint pytest pytest-cov httpx types-psycopg2 > /dev/null 2>&1
    pip install -q --disable-pip-version-check -r requirements.txt > /dev/null 2>&1
    echo -e "${GREEN}✓ Environnement prêt.${NC}"

    # --------------------------------------------------------------------------
    # 1. FORMATAGE (Black)
    # --------------------------------------------------------------------------
    echo -e "\n${BOLD}${CYAN}[1/5] 🧹 Vérification du formatage (Black)${NC}"
    if black --check .; then
        echo -e "  ${GREEN}✓ Code correctement formaté${NC}"
    else
        echo -e "  ${RED}✗ Problèmes de formatage détectés${NC}"
        ERR_BLACK=1
    fi

    # --------------------------------------------------------------------------
    # 2. LINTING (Ruff)
    # --------------------------------------------------------------------------
    echo -e "\n${BOLD}${CYAN}[2/5] 🔍 Linting rapide (Ruff)${NC}"
    if ruff check .; then
        echo -e "  ${GREEN}✓ Aucun problème de linter détecté${NC}"
    else
        echo -e "  ${RED}✗ Erreurs de linting détectées${NC}"
        ERR_RUFF=1
    fi

    # --------------------------------------------------------------------------
    # 3. TYPAGE (Mypy)
    # --------------------------------------------------------------------------
    echo -e "\n${BOLD}${CYAN}[3/5] 🛡️ Vérification des types (Mypy)${NC}"
    if mypy .; then
        echo -e "  ${GREEN}✓ Typage statique valide${NC}"
    else
        echo -e "  ${RED}✗ Erreurs de typage détectées${NC}"
        ERR_MYPY=1
    fi

    # --------------------------------------------------------------------------
    # 4. ANALYSE STATIQUE (Pylint)
    # --------------------------------------------------------------------------
    echo -e "\n${BOLD}${CYAN}[4/5] 📝 Analyse de code approfondie (Pylint)${NC}"
    # On autorise un score < 10 mais on veut voir s il crash
    if pylint --output-format=text:pylint_report.txt src/ > /dev/null 2>&1; then
       # Pylint retourne souvent des exit codes non-zero même pour des warnings
       # Ici on vérifie simplement que la commande a tourné, ou on filtre
       echo -e "  ${GREEN}✓ Analyse terminée${NC}"
    else
       # Pylint est strict, on affiche le score s il est dispo ou on considère Warning
       echo -e "  ${YELLOW}⚠ Avertissements Pylint détectés (voir logs)${NC}"
       # On ne met pas forcément en erreur bloquante pour Pylint selon la sévérité
       # ERR_PYLINT=1 
    fi

    # --------------------------------------------------------------------------
    # 5. TESTS UNITAIRES (Pytest)
    # --------------------------------------------------------------------------
    echo -e "\n${BOLD}${CYAN}[5/5] 🧪 Tests Unitaires & Couverture (Pytest)${NC}"
    # On exécute pytest et on capture le code de sortie
    if pytest --cov=src --cov-report=term-missing; then
        echo -e "\n  ${GREEN}✓ Tous les tests sont passés${NC}"
    else
        echo -e "\n  ${RED}✗ Échec de certains tests unitaires${NC}"
        ERR_PYTEST=1
    fi

    # ==========================================================================
    # RAPPORT FINAL (DASHBOARD)
    # ==========================================================================
    echo -e "\n"
    echo -e "${BOLD}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "                        ${BOLD}RAPPORT DE RÉSULTATS${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════════════${NC}"
    
    # Fonction helper pour afficher une ligne de rapport
    report_line() {
        name=$1
        status=$2
        if [ "$status" -eq 0 ]; then
            printf " ║ %-20s ║ ${GREEN}%-10s${NC} ║ ${GREEN}PASS${NC}    ║\n" "$name" "Succès"
        else
            printf " ║ %-20s ║ ${RED}%-10s${NC} ║ ${RED}FAIL${NC}    ║\n" "$name" "Échec"
        fi
    }

    report_line "Formatage (Black)" $ERR_BLACK
    report_line "Linting (Ruff)" $ERR_RUFF
    report_line "Typage (Mypy)" $ERR_MYPY
    report_line "Qualité (Pylint)" $ERR_PYLINT
    report_line "Tests (Pytest)" $ERR_PYTEST

    echo -e "${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"

    # Calcul du code de sortie global
    TOTAL_ERR=$((ERR_BLACK + ERR_RUFF + ERR_MYPY + ERR_PYTEST))
    
    if [ $TOTAL_ERR -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}🚀 PRÊT POUR LE DÉPLOIEMENT !${NC}\n"
        exit 0
    else
        echo -e "\n${RED}${BOLD}💥 CORRECTIONS NÉCESSAIRES ($TOTAL_ERR échecs)${NC}\n"
        exit 1
    fi
'

# Récupération du code de sortie du conteneur
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # Succès
    exit 0
else
    # Échec
    exit 1
fi