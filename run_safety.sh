#!/bin/bash

################################################################################
# SCRIPT D'AUDIT DE SÉCURITÉ MULTI-COUCHES
################################################################################
# Description : Pipeline de sécurité automatisé combinant analyse statique du
#               code (SAST) et scan de vulnérabilités des conteneurs via un
#               système dual-engine (Trivy + Docker Scout).
#
# Auteur      : Développement Infrastructure
# Version     : 2.0.0
# Date        : 2025-12-16
#
# Prérequis   : - Docker Engine 20.10+
#               - Docker Compose V2
#               - Trivy (optionnel, via conteneur si absent)
#               - Docker Scout (optionnel)
#               - Bash 4.0+
#
# Usage       : ./run_safety.sh
# Exit codes  : 0 = tous les tests passent
#               1 = échec de sécurité détecté
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
SYMBOL_SECURITY="[*]"
SYMBOL_SCAN="[@]"

# ------------------------------------------------------------------------------
# 1.3 Variables de configuration
# ------------------------------------------------------------------------------
# Chargement du fichier .env s'il existe pour récupérer les variables
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
fi

# Configuration des images Docker à analyser
DOCKER_NS=${DOCKER_USER}                  # Namespace Docker Hub
API_IMAGE="${DOCKER_NS}/tdocker-api:latest"      # Image de l'API à scanner
FRONT_IMAGE="${DOCKER_NS}/tdocker-front:latest"  # Image du frontend à scanner

# Variables de résultats pour le rapport final
RES_CODE="PENDING"         # Résultat de l'analyse statique du code
RES_TRIVY_API="PENDING"    # Résultat Trivy pour l'API
RES_TRIVY_FRONT="PENDING"  # Résultat Trivy pour le frontend
RES_SCOUT_API="SKIP"       # Résultat Docker Scout pour l'API
RES_SCOUT_FRONT="SKIP"     # Résultat Docker Scout pour le frontend

# ==============================================================================
# SECTION 2: FONCTIONS UTILITAIRES
# ==============================================================================

# ------------------------------------------------------------------------------
# Fonction: print_header
# Description: Affiche l'en-tête du script avec informations sur le pipeline
# ------------------------------------------------------------------------------
print_header() {
    echo -e "${RED}╔═════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}  ${BOLD}SECURITY AUDIT PIPELINE - MULTI-LAYER ANALYSIS${NC}                                     ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                                                     ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${CYAN}Code Analysis:${NC}      Flake8 • Bandit (SAST)                                         ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${CYAN}Container Scan:${NC}     Trivy • Docker Scout (Dual Engine)                             ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${CYAN}Version:${NC}            2.0.0                                                          ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${CYAN}Date:${NC}               $(date '+%Y-%m-%d %H:%M:%S')                                            ${RED}║${NC}"
    echo -e "${RED}╚═════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Fonction: print_step
# Description: Affiche un en-tête de section pour une étape de l'audit
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

# ------------------------------------------------------------------------------
# Fonction: run_dual_scan
# Description: Exécute un scan de sécurité dual-engine (Trivy + Docker Scout)
#              sur une image Docker spécifique
# Arguments: $1 - Nom complet de l'image Docker (avec tag)
#            $2 - Identifiant court (ex: "API", "FRONT")
# Variables globales modifiées: RES_TRIVY_*, RES_SCOUT_*
# ------------------------------------------------------------------------------
run_dual_scan() {
    local img="$1"
    local identifier="$2"
    local identifier_upper=$(echo "$identifier" | tr '[:lower:]' '[:upper:]')

    local res_trivy="SKIP"
    local res_scout="SKIP"

    echo ""
    echo -e "${BOLD}${CYAN}${SYMBOL_SCAN} Analyse de l'image: ${PURPLE}${identifier}${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

    # --------------------------------------------------------------------------
    # Moteur 1: Trivy - Analyse des vulnérabilités CVE
    # --------------------------------------------------------------------------
    print_info "Moteur 1: Trivy (CVE scanner)"

    if $TRIVY_CMD --severity HIGH,CRITICAL --no-progress --exit-code 1 "$img" > /dev/null 2>&1; then
        print_success "Trivy: Aucune vulnérabilité critique détectée"
        res_trivy="PASS"
    else
        print_error "Trivy: Vulnérabilités critiques détectées"
        echo ""
        echo -e "    ${BOLD}${RED}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "    ${BOLD}${RED}║  RAPPORT DE VULNÉRABILITÉS - TRIVY                       ║${NC}"
        echo -e "    ${BOLD}${RED}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        $TRIVY_CMD --severity HIGH,CRITICAL --no-progress --scanners vuln "$img" 2>/dev/null | sed 's/^/    /'
        echo ""
        res_trivy="FAIL"
    fi

    # --------------------------------------------------------------------------
    # Moteur 2: Docker Scout - Analyse approfondie avec recommandations
    # --------------------------------------------------------------------------
    if [ "$HAS_SCOUT" = true ]; then
        echo ""
        print_info "Moteur 2: Docker Scout (Enhanced analysis)"

        # Affichage du quickview complet
        echo ""
        echo -e "    ${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "    ${BOLD}${CYAN}║  APERÇU SÉCURITÉ - DOCKER SCOUT                          ║${NC}"
        echo -e "    ${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Capture de la sortie quickview avec gestion d'erreur
        QUICKVIEW_OUTPUT=$($SCOUT_CMD quickview "$img" 2>&1)
        QUICKVIEW_EXIT=$?

        if [ $QUICKVIEW_EXIT -eq 0 ] && [ -n "$QUICKVIEW_OUTPUT" ]; then
            echo "$QUICKVIEW_OUTPUT" | sed 's/^/    /'
        elif echo "$QUICKVIEW_OUTPUT" | grep -q "UNAUTHORIZED\|authentication required\|Pull failed"; then
            echo -e "    ${YELLOW}⚠ Image non disponible sur Docker Hub (utilisation locale uniquement)${NC}"
            echo -e "    ${CYAN}Image analysée:${NC} $img"
            echo -e "    ${CYAN}Conseil:${NC} Publiez l'image sur Docker Hub pour une analyse complète Scout"
        else
            echo "$QUICKVIEW_OUTPUT" | grep -v "New version" | sed 's/^/    /'
        fi
        echo ""

        # Analyse des CVE avec Docker Scout
        SCOUT_CVE_OUTPUT=$($SCOUT_CMD cves "$img" --only-severity critical,high 2>&1)
        SCOUT_EXIT=$?

        if [ $SCOUT_EXIT -eq 0 ]; then
            print_success "Docker Scout: Aucune vulnérabilité critique détectée"
            res_scout="PASS"
        elif echo "$SCOUT_CVE_OUTPUT" | grep -q "UNAUTHORIZED\|authentication required\|Pull failed"; then
            print_warning "Docker Scout: Analyse impossible (image non publiée sur Docker Hub)"
            echo -e "    ${CYAN}Conseil:${NC} Utilisez ${YELLOW}./run_docker_publication.sh${NC} pour publier puis réanalyser"
            res_scout="SKIP"
        else
            print_warning "Docker Scout: Vulnérabilités détectées (niveau WARNING)"
            echo ""
            echo -e "    ${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
            echo -e "    ${BOLD}${YELLOW}║  RAPPORT DÉTAILLÉ - DOCKER SCOUT                         ║${NC}"
            echo -e "    ${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo "$SCOUT_CVE_OUTPUT" | grep -v "New version" | sed 's/^/    /'
            echo ""
            res_scout="FAIL"
        fi
    fi

    # Export des résultats vers les variables globales
    eval "RES_TRIVY_${identifier_upper}='$res_trivy'"
    eval "RES_SCOUT_${identifier_upper}='$res_scout'"
}

# ==============================================================================
# SECTION 3: PROCESSUS D'AUDIT DE SÉCURITÉ
# ==============================================================================

print_header

# ------------------------------------------------------------------------------
# ÉTAPE 1: Analyse Statique du Code Python (SAST)
# ------------------------------------------------------------------------------
print_step "ÉTAPE 1/4: ANALYSE STATIQUE DU CODE (SAST)"

# Vérification de la présence du répertoire API
if [ ! -d "./api" ]; then
    print_error "Répertoire ./api introuvable"
    print_info "Assurez-vous d'exécuter ce script depuis la racine du projet"
    exit 1
fi

print_info "Lancement de l'analyse statique du code Python..."
print_info "Outils utilisés: Flake8 (linting) + Bandit (security)"

# Exécution de l'analyse dans un conteneur Python isolé
docker run --rm -v "$(pwd)/api:/app" -w /app python:3.11-slim /bin/bash -c '
    # Configuration des couleurs dans le conteneur
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    CYAN="\033[0;36m"
    NC="\033[0m"
    BOLD="\033[1m"

    ERR_FLAKE8=0
    ERR_BANDIT=0

    echo -e "  ${CYAN}[i]${NC} Installation des outils SAST (Flake8, Bandit)..."
    pip install -q --disable-pip-version-check flake8 bandit > /dev/null 2>&1

    # -------------------------------------------------------------------------
    # Test 1: Flake8 - Vérification de la syntaxe et du style de code
    # -------------------------------------------------------------------------
    echo ""
    echo -e "${BOLD}${CYAN}[1/2] Analyse de conformité du code (Flake8)${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

    FLAKE8_OUTPUT=$(flake8 src/ --count --select=E9,F63,F7,F82 --show-source --statistics 2>&1)
    FLAKE8_EXIT=$?

    if [ $FLAKE8_EXIT -eq 0 ]; then
        echo -e "  ${GREEN}[✓]${NC} Code conforme aux standards Python (erreurs critiques uniquement)"
    else
        echo -e "  ${RED}[✗]${NC} Violations de style de code détectées"
        echo ""
        echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${YELLOW}║  RAPPORT DE CONFORMITÉ - FLAKE8                             ║${NC}"
        echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "$FLAKE8_OUTPUT" | sed "s/^/  /"
        echo ""
        ERR_FLAKE8=1
    fi

    # -------------------------------------------------------------------------
    # Test 2: Bandit - Détection de failles de sécurité dans le code
    # -------------------------------------------------------------------------
    echo ""
    echo -e "${BOLD}${CYAN}[2/2] Recherche de failles de sécurité (Bandit)${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

    if bandit -r src/ -ll -q 2>&1; then
        echo -e "  ${GREEN}[✓]${NC} Aucune faille de sécurité évidente détectée"
    else
        echo -e "  ${RED}[✗]${NC} Failles de sécurité potentielles détectées"
        echo ""
        echo -e "${BOLD}${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${RED}║  RAPPORT DE SÉCURITÉ - BANDIT (SAST)                        ║${NC}"
        echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        bandit -r src/ -ll -f screen 2>&1 | sed "s/^/  /"
        echo ""
        ERR_BANDIT=1
    fi

    # Code de sortie: somme des erreurs détectées
    exit $((ERR_FLAKE8 + ERR_BANDIT))
'

# Évaluation du résultat de l'analyse statique
SAST_EXIT_CODE=$?
if [ $SAST_EXIT_CODE -eq 0 ]; then
    echo ""
    print_success "Analyse statique du code: PASS"
    RES_CODE="PASS"
else
    echo ""
    print_error "Analyse statique du code: FAIL (${SAST_EXIT_CODE} erreur(s) détectée(s))"
    RES_CODE="FAIL"
fi

# ------------------------------------------------------------------------------
# ÉTAPE 2: Construction des images Docker
# ------------------------------------------------------------------------------
print_step "ÉTAPE 2/4: CONSTRUCTION DES IMAGES DOCKER"

print_info "Construction des images pour analyse de sécurité..."

if docker compose build > /dev/null 2>&1; then
    print_success "Images construites avec succès"
else
    print_error "Échec de la construction des images"
    print_info "Vérifiez la configuration de votre docker-compose.yml"
    exit 1
fi

# ------------------------------------------------------------------------------
# ÉTAPE 3: Configuration des outils de scan de conteneurs
# ------------------------------------------------------------------------------
print_step "ÉTAPE 3/4: CONFIGURATION DES MOTEURS DE SCAN"

# Configuration de Trivy (natif ou conteneurisé)
print_info "Configuration du moteur Trivy..."
if command -v trivy &> /dev/null; then
    TRIVY_CMD="trivy image"
    print_success "Trivy natif détecté: $(trivy --version 2>/dev/null | head -n1 || echo 'version inconnue')"
else
    TRIVY_CMD="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image"
    print_warning "Trivy natif non trouvé - utilisation de la version conteneurisée"
fi

# Configuration de Docker Scout (optionnel)
print_info "Vérification de Docker Scout..."
SCOUT_CMD="docker scout"
HAS_SCOUT=true
if docker scout version &> /dev/null; then
    print_success "Docker Scout détecté: $(docker scout version 2>/dev/null | head -n1 || echo 'version inconnue')"
else
    HAS_SCOUT=false
    print_warning "Docker Scout non disponible - seul Trivy sera utilisé"
    print_info "Installation: https://docs.docker.com/scout/install/"
fi

# ------------------------------------------------------------------------------
# ÉTAPE 4: Analyse de sécurité des images (Dual Engine)
# ------------------------------------------------------------------------------
print_step "ÉTAPE 4/4: ANALYSE DE SÉCURITÉ DES CONTENEURS"

print_info "Démarrage du scan dual-engine (Trivy + Docker Scout)..."

# Scan de l'image API
run_dual_scan "$API_IMAGE" "API"

# Scan de l'image Frontend
run_dual_scan "$FRONT_IMAGE" "FRONT"

# ==============================================================================
# SECTION 4: GÉNÉRATION DU RAPPORT DE SÉCURITÉ
# ==============================================================================

echo ""
echo ""
echo -e "${RED}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${RED}  ${SYMBOL_SECURITY} RAPPORT DE SÉCURITÉ UNIFIÉ${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════════════════════════════════${NC}"

# ------------------------------------------------------------------------------
# Fonction: print_report_line
# Description: Affiche une ligne formatée du rapport de sécurité
# Arguments: $1 - Nom du composant analysé
#            $2 - Statut du test (PASS/FAIL/SKIP)
#            $3 - Nom du moteur d'analyse
# ------------------------------------------------------------------------------
print_report_line() {
    local name="$1"
    local status="$2"
    local engine="$3"

    if [ "$status" == "PASS" ]; then
        printf " ║ %-28s ║ %-10s ║ ${GREEN}%-10s${NC} ║\n" "$name" "$engine" "SECURE"
    elif [ "$status" == "SKIP" ]; then
        printf " ║ %-28s ║ %-10s ║ ${YELLOW}%-10s${NC} ║\n" "$name" "$engine" "SKIPPED"
    else
        printf " ║ %-28s ║ %-10s ║ ${RED}%-10s${NC} ║\n" "$name" "$engine" "DANGER"
    fi
}

# Tableau des résultats
echo -e "${RED}╔══════════════════════════════╦════════════╦════════════╗${NC}"
echo -e "${BOLD}${RED}║ COMPOSANT                    ║ MOTEUR     ║ RÉSULTAT   ║${NC}"
echo -e "${RED}╠══════════════════════════════╬════════════╬════════════╣${NC}"

# Résultats de l'analyse de code
print_report_line "Code Python (SAST)" "$RES_CODE" "Bandit"

echo -e "${RED}╠══════════════════════════════╬════════════╬════════════╣${NC}"

# Résultats pour l'image API
print_report_line "Image API" "$RES_TRIVY_API" "Trivy"
print_report_line "Image API" "$RES_SCOUT_API" "Scout"

echo -e "${RED}╠══════════════════════════════╬════════════╬════════════╣${NC}"

# Résultats pour l'image Frontend
print_report_line "Image Frontend" "$RES_TRIVY_FRONT" "Trivy"
print_report_line "Image Frontend" "$RES_SCOUT_FRONT" "Scout"

echo -e "${RED}╚══════════════════════════════╩════════════╩════════════╝${NC}"

# ------------------------------------------------------------------------------
# Évaluation finale et code de sortie
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${CYAN}Évaluation de la sécurité:${NC}"

# Vérification du code source
if [ "$RES_CODE" != "PASS" ]; then
    echo -e "  ${RED}${SYMBOL_ERROR}${NC} Code source: Failles de sécurité détectées"
    echo ""
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}${BOLD}  ${SYMBOL_ERROR} ÉCHEC DE L'AUDIT - CODE NON SÉCURISÉ${NC}"
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Actions recommandées:${NC}"
    echo -e "  ${CYAN}1.${NC} Consultez les rapports Flake8 et Bandit ci-dessus"
    echo -e "  ${CYAN}2.${NC} Corrigez les violations de sécurité détectées"
    echo -e "  ${CYAN}3.${NC} Relancez l'audit avec: ${YELLOW}./run_safety.sh${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} Les failles de sécurité du code source doivent être corrigées"
    echo -e "       avant de procéder au scan des conteneurs."
    echo ""
    exit 1
fi

# Vérification des images avec Trivy (moteur principal)
if [ "$RES_TRIVY_API" == "FAIL" ] || [ "$RES_TRIVY_FRONT" == "FAIL" ]; then
    echo -e "  ${RED}${SYMBOL_ERROR}${NC} Conteneurs: Vulnérabilités critiques détectées par Trivy"
    echo ""
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}${BOLD}  ${SYMBOL_ERROR} ÉCHEC DE L'AUDIT - VULNÉRABILITÉS CRITIQUES${NC}"
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Images affectées:${NC}"
    [ "$RES_TRIVY_API" == "FAIL" ] && echo -e "  ${RED}${SYMBOL_ERROR}${NC} API: $API_IMAGE"
    [ "$RES_TRIVY_FRONT" == "FAIL" ] && echo -e "  ${RED}${SYMBOL_ERROR}${NC} Frontend: $FRONT_IMAGE"
    echo ""
    echo -e "${BOLD}Actions recommandées:${NC}"
    echo -e "  ${CYAN}1.${NC} Consultez les rapports Trivy détaillés ci-dessus"
    echo -e "  ${CYAN}2.${NC} Mettez à jour les dépendances vulnérables dans vos Dockerfile"
    echo -e "  ${CYAN}3.${NC} Utilisez des images de base plus récentes (ex: alpine:latest)"
    echo -e "  ${CYAN}4.${NC} Consultez les CVE sur ${YELLOW}https://cve.mitre.org${NC}"
    echo -e "  ${CYAN}5.${NC} Relancez l'audit après corrections: ${YELLOW}./run_safety.sh${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} Les vulnérabilités critiques (HIGH/CRITICAL) bloquent le déploiement."
    echo ""
    exit 1
fi

# Avertissement sur Docker Scout (non bloquant)
if [ "$RES_SCOUT_API" == "FAIL" ] || [ "$RES_SCOUT_FRONT" == "FAIL" ]; then
    echo -e "  ${YELLOW}${SYMBOL_WARNING}${NC} Conteneurs: Docker Scout a détecté des vulnérabilités (non bloquant)"
    echo ""
    echo -e "${BOLD}Images avec avertissements Scout:${NC}"
    [ "$RES_SCOUT_API" == "FAIL" ] && echo -e "  ${YELLOW}${SYMBOL_WARNING}${NC} API: $API_IMAGE"
    [ "$RES_SCOUT_FRONT" == "FAIL" ] && echo -e "  ${YELLOW}${SYMBOL_WARNING}${NC} Frontend: $FRONT_IMAGE"
    echo ""
    echo -e "${YELLOW}Recommandation:${NC} Consultez les rapports Docker Scout ci-dessus pour des"
    echo -e "                recommandations d'optimisation de sécurité."
    echo ""
fi

# ------------------------------------------------------------------------------
# Message de succès final
# ------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ${SYMBOL_OK} AUDIT DE SÉCURITÉ RÉUSSI - READY FOR PRODUCTION${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Récapitulatif des tests réussis
echo -e "${BOLD}Récapitulatif de l'audit:${NC}"
echo -e "  ${GREEN}${SYMBOL_OK}${NC} Analyse statique du code (SAST)      : ${GREEN}${BOLD}PASS${NC}"
echo -e "  ${GREEN}${SYMBOL_OK}${NC} Scan Trivy - Image API                : ${GREEN}${BOLD}PASS${NC}"
echo -e "  ${GREEN}${SYMBOL_OK}${NC} Scan Trivy - Image Frontend           : ${GREEN}${BOLD}PASS${NC}"

# Affichage conditionnel pour Docker Scout
if [ "$HAS_SCOUT" = true ]; then
    if [ "$RES_SCOUT_API" == "PASS" ] && [ "$RES_SCOUT_FRONT" == "PASS" ]; then
        echo -e "  ${GREEN}${SYMBOL_OK}${NC} Scan Docker Scout - Toutes les images : ${GREEN}${BOLD}PASS${NC}"
    elif [ "$RES_SCOUT_API" == "FAIL" ] || [ "$RES_SCOUT_FRONT" == "FAIL" ]; then
        echo -e "  ${YELLOW}${SYMBOL_WARNING}${NC} Scan Docker Scout                     : ${YELLOW}${BOLD}WARNING${NC} (non bloquant)"
    elif [ "$RES_SCOUT_API" == "SKIP" ] || [ "$RES_SCOUT_FRONT" == "SKIP" ]; then
        echo -e "  ${CYAN}${SYMBOL_INFO}${NC} Scan Docker Scout                     : ${CYAN}${BOLD}SKIPPED${NC} (images non publiées)"
    fi
fi

exit 0
