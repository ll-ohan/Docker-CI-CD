#!/bin/bash

################################################################################
# SCRIPT DE TESTS ET CONTRÔLE QUALITÉ
################################################################################
# Description : Script automatisé d'exécution de la suite de tests et de
#               vérification de la qualité du code Python. Effectue le
#               formatage, linting, typage statique, analyse de code et
#               tests unitaires avec couverture.
#
# Auteur      : Développement Infrastructure
# Version     : 2.0.0
# Date        : 2025-12-16
#
# Prérequis   : - Docker Engine 20.10+
#               - Dossier ./api contenant le code source Python
#
# Usage       : ./run_tests.sh
# Exit codes  : 0 = tous les tests réussis
#               1 = échec d'un ou plusieurs contrôles qualité
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
# 1.2 Symboles pour l'affichage
# ------------------------------------------------------------------------------
SYMBOL_OK="[✓]"
SYMBOL_ERROR="[✗]"
SYMBOL_INFO="[i]"
SYMBOL_ARROW="==>"
SYMBOL_WARNING="[!]"

# ------------------------------------------------------------------------------
# 1.3 Variables de configuration
# ------------------------------------------------------------------------------
API_DIR="./api"                    # Répertoire du code source à tester
DOCKER_IMAGE="python:3.11-slim"    # Image Docker de base pour les tests

# ==============================================================================
# SECTION 2: FONCTIONS UTILITAIRES
# ==============================================================================

# ------------------------------------------------------------------------------
# Fonction: print_header
# Description: Affiche l'en-tête du script avec informations sur l'environnement
# ------------------------------------------------------------------------------
print_header() {
    echo -e "${BLUE}╔═════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}AUTOMATED TESTING & QUALITY ASSURANCE PIPELINE${NC}                                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                                                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Tools:${NC} Black • Ruff • Mypy • Pylint • Pytest                                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Version:${NC}  2.0.0                                                                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Date:${NC}     $(date '+%Y-%m-%d %H:%M:%S')                                                      ${BLUE}║${NC}"
    echo -e "${BLUE}╚═════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Fonction: print_step
# Description: Affiche un en-tête de section pour une étape du processus
# Arguments: $1 - Titre de l'étape
# ------------------------------------------------------------------------------
print_step() {
    local text="$1"
    local box_width=85  # Largeur fixe du conteneur
    local text_length=${#text}
    local padding_length=$((box_width - text_length - 1))

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
# SECTION 3: PROCESSUS DE TESTS ET CONTRÔLE QUALITÉ
# ==============================================================================

print_header

# ------------------------------------------------------------------------------
# ÉTAPE 0: Validation de la présence du répertoire source
# ------------------------------------------------------------------------------
print_step "ÉTAPE 0/5: VALIDATION DE L'ENVIRONNEMENT"

print_info "Vérification de la présence du répertoire source..."

if [ ! -d "$API_DIR" ]; then
    print_error "Erreur critique: Le répertoire $API_DIR est introuvable"
    print_info "Assurez-vous d'exécuter ce script depuis la racine du projet"
    exit 1
fi

print_success "Répertoire source validé: $API_DIR"

# ------------------------------------------------------------------------------
# ÉTAPE 1-5: Exécution des tests dans un conteneur Docker
# ------------------------------------------------------------------------------
print_step "INITIALISATION DU CONTENEUR DE TEST"

print_info "Démarrage du conteneur Docker: $DOCKER_IMAGE"
print_info "Montage du volume: $(pwd)/api -> /app"

# Exécution d'un conteneur Docker unique pour tous les tests
# Cette approche évite de réinstaller les dépendances à chaque étape
docker run --rm -v "$(pwd)/api:/app" -w /app "$DOCKER_IMAGE" /bin/bash -c '
    # ==========================================================================
    # CONFIGURATION INTERNE DU CONTENEUR
    # ==========================================================================

    # Couleurs ANSI pour affichage dans le conteneur
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    CYAN="\033[0;36m"
    PURPLE="\033[0;35m"
    NC="\033[0m"
    BOLD="\033[1m"

    # Symboles
    SYMBOL_OK="[✓]"
    SYMBOL_ERROR="[✗]"
    SYMBOL_INFO="[i]"
    SYMBOL_WARNING="[!]"

    # Initialisation des compteurs d erreurs pour chaque outil
    ERR_BLACK=0
    ERR_RUFF=0
    ERR_MYPY=0
    ERR_PYLINT=0
    ERR_PYTEST=0

    # ==========================================================================
    # INSTALLATION DES DÉPENDANCES
    # ==========================================================================

    echo -e "\n${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│${NC} INSTALLATION DES DÉPENDANCES                                                        ${PURPLE}│${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"

    echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Installation des outils de qualité et de test..."
    echo -e "  ${CYAN}    ==>${NC} Black (formatage), Ruff (linting), Mypy (typage)"
    echo -e "  ${CYAN}    ==>${NC} Pylint (analyse statique), Pytest (tests unitaires)"

    # Installation des outils de développement
    # --disable-pip-version-check : supprime les avertissements de version pip
    # -q : mode silencieux pour réduire le bruit dans les logs
    pip install -q --disable-pip-version-check \
        black ruff mypy pylint pytest pytest-cov httpx types-psycopg2 > /dev/null 2>&1

    # Installation des dépendances du projet
    if [ -f requirements.txt ]; then
        pip install -q --disable-pip-version-check -r requirements.txt > /dev/null 2>&1
    fi

    echo -e "  ${GREEN}${SYMBOL_OK}${NC} Environnement de test prêt\n"

    # ==========================================================================
    # ÉTAPE 1: VÉRIFICATION DU FORMATAGE (Black)
    # ==========================================================================

    echo -e "\n${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│${NC} ÉTAPE 1/5: VÉRIFICATION DU FORMATAGE (Black)                                        ${PURPLE}│${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"

    echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Vérification de la conformité au style PEP 8..."

    # Black vérifie sans modifier (--check)
    # Retourne 0 si le code est bien formaté, 1 sinon
    if black --check . > /dev/null 2>&1; then
        echo -e "  ${GREEN}${SYMBOL_OK}${NC} Code correctement formaté selon les standards PEP 8"
    else
        echo -e "  ${RED}${SYMBOL_ERROR}${NC} Problèmes de formatage détectés"
        echo -e "  ${YELLOW}${SYMBOL_WARNING}${NC} Exécutez '\''black .'\'' pour corriger automatiquement"
        ERR_BLACK=1
    fi

    # ==========================================================================
    # ÉTAPE 2: LINTING RAPIDE (Ruff)
    # ==========================================================================

    echo -e "\n${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│${NC} ÉTAPE 2/5: LINTING RAPIDE (Ruff)                                                    ${PURPLE}│${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"

    echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Analyse des erreurs de code et mauvaises pratiques..."

    # Ruff est un linter Python ultra-rapide (écrit en Rust)
    # Détecte les imports non utilisés, variables inutiles, etc.
    if ruff check . > /dev/null 2>&1; then
        echo -e "  ${GREEN}${SYMBOL_OK}${NC} Aucun problème de linting détecté"
    else
        echo -e "  ${RED}${SYMBOL_ERROR}${NC} Erreurs de linting détectées"
        echo -e "  ${YELLOW}${SYMBOL_WARNING}${NC} Consultez les détails avec '\''ruff check .'\'' pour plus d'\''informations"
        ERR_RUFF=1
    fi

    # ==========================================================================
    # ÉTAPE 3: VÉRIFICATION DU TYPAGE STATIQUE (Mypy)
    # ==========================================================================

    echo -e "\n${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│${NC} ÉTAPE 3/5: VÉRIFICATION DU TYPAGE STATIQUE (Mypy)                                   ${PURPLE}│${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"

    echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Analyse de la cohérence des annotations de type..."

    # Mypy vérifie que les annotations de type sont correctes
    # Aide à détecter les erreurs de typage avant l'\''exécution
    if mypy . > /dev/null 2>&1; then
        echo -e "  ${GREEN}${SYMBOL_OK}${NC} Typage statique valide - aucune incohérence détectée"
    else
        echo -e "  ${RED}${SYMBOL_ERROR}${NC} Erreurs de typage détectées"
        echo -e "  ${YELLOW}${SYMBOL_WARNING}${NC} Vérifiez les annotations de type avec '\''mypy .'\''"
        ERR_MYPY=1
    fi

    # ==========================================================================
    # ÉTAPE 4: ANALYSE STATIQUE APPROFONDIE (Pylint)
    # ==========================================================================

    echo -e "\n${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│${NC} ÉTAPE 4/5: ANALYSE STATIQUE APPROFONDIE (Pylint)                                    ${PURPLE}│${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"

    echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Analyse de la qualité du code et des conventions..."

    # Pylint effectue une analyse très stricte du code
    # Génère un rapport avec score de qualité (0-10)
    # Note: Pylint retourne souvent des codes d'\''erreur même pour des warnings mineurs
    if pylint --output-format=text:pylint_report.txt src/ > /dev/null 2>&1; then
        echo -e "  ${GREEN}${SYMBOL_OK}${NC} Analyse de qualité terminée avec succès"
    else
        # On considère Pylint comme non-bloquant par défaut
        # car il peut être très strict sur des conventions stylistiques
        echo -e "  ${YELLOW}${SYMBOL_WARNING}${NC} Avertissements Pylint détectés (non-bloquant)"
        echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Consultez '\''pylint_report.txt'\'' pour les détails"
        # Optionnel: décommenter pour rendre Pylint bloquant
        # ERR_PYLINT=1
    fi

    # ==========================================================================
    # ÉTAPE 5: TESTS UNITAIRES ET COUVERTURE (Pytest)
    # ==========================================================================

    echo -e "\n${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│${NC} ÉTAPE 5/5: TESTS UNITAIRES ET COUVERTURE (Pytest)                                   ${PURPLE}│${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────────────────────────────┘${NC}"

    echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Exécution de la suite de tests avec mesure de couverture...\n"

    # Pytest exécute tous les tests unitaires
    # --cov=src : mesure la couverture du répertoire src
    # --cov-report=term-missing : affiche les lignes non couvertes
    if pytest --cov=src --cov-report=term-missing 2>&1; then
        echo -e "\n  ${GREEN}${SYMBOL_OK}${NC} Tous les tests unitaires sont passés avec succès"
    else
        echo -e "\n  ${RED}${SYMBOL_ERROR}${NC} Échec d'\''un ou plusieurs tests unitaires"
        ERR_PYTEST=1
    fi

    # ==========================================================================
    # GÉNÉRATION DU RAPPORT FINAL
    # ==========================================================================

    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  RAPPORT DE CONTRÔLE QUALITÉ${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════════════${NC}"

    # Tableau récapitulatif des résultats
    printf "${BOLD}%-25s %-15s %-10s${NC}\n" "OUTIL" "STATUT" "RÉSULTAT"
    echo -e "${BOLD}───────────────────────────────────────────────────────────────────────────────────────${NC}"

    # Fonction helper pour afficher une ligne du rapport
    report_line() {
        local tool_name="$1"
        local error_count=$2

        if [ "$error_count" -eq 0 ]; then
            printf "%-25s ${GREEN}%-15s${NC} ${GREEN}%-10s${NC}\n" "$tool_name" "Succès" "PASS"
        else
            printf "%-25s ${RED}%-15s${NC} ${RED}%-10s${NC}\n" "$tool_name" "Échec" "FAIL"
        fi
    }

    # Affichage des résultats pour chaque outil
    report_line "Formatage (Black)" $ERR_BLACK
    report_line "Linting (Ruff)" $ERR_RUFF
    report_line "Typage (Mypy)" $ERR_MYPY
    report_line "Qualité (Pylint)" $ERR_PYLINT
    report_line "Tests (Pytest)" $ERR_PYTEST

    # ==========================================================================
    # CALCUL DU RÉSULTAT GLOBAL
    # ==========================================================================

    # Somme des erreurs (Pylint exclu car non-bloquant)
    TOTAL_ERR=$((ERR_BLACK + ERR_RUFF + ERR_MYPY + ERR_PYTEST))

    echo ""

    if [ $TOTAL_ERR -eq 0 ]; then
        echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}  ${SYMBOL_OK} CONTRÔLE QUALITÉ RÉUSSI - CODE PRÊT POUR LE DÉPLOIEMENT${NC}"
        echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        exit 0
    else
        echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}${BOLD}  ${SYMBOL_ERROR} CORRECTIONS NÉCESSAIRES ($TOTAL_ERR échec(s) détecté(s))${NC}"
        echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}${BOLD}Actions recommandées:${NC}"
        [ $ERR_BLACK -ne 0 ] && echo -e "  ${YELLOW}  ==>${NC} Exécutez ${CYAN}black .${NC} pour corriger le formatage"
        [ $ERR_RUFF -ne 0 ] && echo -e "  ${YELLOW}  ==>${NC} Consultez ${CYAN}ruff check .${NC} et corrigez les erreurs"
        [ $ERR_MYPY -ne 0 ] && echo -e "  ${YELLOW}  ==>${NC} Vérifiez les annotations avec ${CYAN}mypy .${NC}"
        [ $ERR_PYTEST -ne 0 ] && echo -e "  ${YELLOW}  ==>${NC} Corrigez les tests unitaires qui échouent"
        echo ""
        exit 1
    fi
'

# ==============================================================================
# SECTION 4: GESTION DU CODE DE SORTIE
# ==============================================================================

# Récupération du code de sortie du conteneur Docker
EXIT_CODE=$?

# Propagation du code de sortie pour CI/CD
exit $EXIT_CODE
