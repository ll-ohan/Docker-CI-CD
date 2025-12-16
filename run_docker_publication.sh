#!/bin/bash

################################################################################
# SCRIPT DE PUBLICATION D'IMAGES DOCKER SÉCURISÉES
################################################################################
# Description : Script automatisé de publication d'images Docker avec
#               génération de SBOM, attestations de provenance et signature
#               cryptographique via Cosign pour garantir l'intégrité.
#
# Auteur      : Développement Infrastructure
# Version     : 2.0.0
# Date        : 2025-12-16
#
# Prérequis   : - Docker Engine 20.10+
#               - Docker Buildx
#               - Cosign (sigstore)
#               - jq (optionnel, pour mise à jour README)
#               - Variables d'environnement: DOCKER_USER, DOCKER_PASS
#
# Usage       : ./run_docker_publication.sh
# Exit codes  : 0 = succès
#               1 = erreur d'authentification/build/signature
################################################################################

set -o pipefail  # Propagation des erreurs dans les pipes

# ==============================================================================
# SECTION 1: CONFIGURATION VISUELLE & VARIABLES GLOBALES
# ==============================================================================

# ------------------------------------------------------------------------------
# 1.1 Définition des couleurs ANSI
# ------------------------------------------------------------------------------
BOLD='\033[1m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No Color / Reset

# ------------------------------------------------------------------------------
# 1.2 Symboles pour l'affichage
# ------------------------------------------------------------------------------
SYMBOL_OK="[✓]"
SYMBOL_ERROR="[✗]"
SYMBOL_INFO="[i]"
SYMBOL_ARROW="==>"
SYMBOL_WARNING="[!]"
SYMBOL_LOCK="[*]"
SYMBOL_SIGN="[#]"

# ------------------------------------------------------------------------------
# 1.3 Chargement des variables d'environnement
# ------------------------------------------------------------------------------
# Chargement du fichier .env s'il existe pour récupérer les credentials
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
fi

# ------------------------------------------------------------------------------
# 1.4 Configuration des images Docker
# ------------------------------------------------------------------------------
DOCKER_NS=${DOCKER_USER:-local}                  # Namespace Docker Hub
API_IMAGE="${DOCKER_NS}/tdocker-api:latest"      # Image de l'API
FRONT_IMAGE="${DOCKER_NS}/tdfront-front:latest"  # Image du frontend
BUILDX_BUILDER="secure_builder"                  # Nom du builder Buildx

# ==============================================================================
# SECTION 2: FONCTIONS UTILITAIRES
# ==============================================================================

# ------------------------------------------------------------------------------
# Fonction: print_header
# Description: Affiche l'en-tête du script avec informations sur les fonctionnalités
# ------------------------------------------------------------------------------
print_header() {
    echo -e "${BLUE}╔═════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}DOCKER SECURE PUBLICATION PIPELINE${NC}                                                 ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                                                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Features:${NC} SBOM Generation • Provenance Attestation • Cosign Signing                ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Version:${NC}  2.0.0                                                                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}Date:${NC}     $(date '+%Y-%m-%d %H:%M:%S')                                                      ${BLUE}║${NC}"
    echo -e "${BLUE}╚═════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Fonction: print_section
# Description: Affiche un en-tête de section pour une étape de la publication
# Arguments: $1 - Titre de la section
# ------------------------------------------------------------------------------
print_section() {
    local text="$1"
    local box_width=85  # Largeur fixe du conteneur (aligné avec header)
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
# Fonction: setup_dct_keys
# Description: Initialise les clés Docker Content Trust si elles sont absentes
# Arguments: $1 - Nom de l'image Docker
# Note: Cette fonction est maintenant obsolète avec Cosign mais conservée
#       pour compatibilité avec DCT legacy si nécessaire
# ------------------------------------------------------------------------------
setup_dct_keys() {
    local img=$1
    print_info "Vérification des clés DCT pour: $img"

    # Vérification de l'existence du trust repository
    if ! docker trust inspect "$img" > /dev/null 2>&1; then
        print_warning "Initialisation du trust pour ce repository..."
        # Note: Cette étape peut nécessiter une interaction utilisateur lors
        # de la première exécution. En environnement CI/CD, les clés doivent
        # être pré-configurées sur le système hôte.
    fi
}

# ------------------------------------------------------------------------------
# Fonction: push_readme
# Description: Met à jour la documentation README sur Docker Hub via l'API
# Arguments: $1 - Nom du repository (ex: username/image-name)
#            $2 - Chemin vers le fichier README local
# Dépendances: curl, jq
# ------------------------------------------------------------------------------
push_readme() {
    local repo_name="$1"
    local readme_path="$2"

    # Vérification de la présence de jq (requis pour manipulation JSON)
    if ! command -v jq &> /dev/null; then
        print_warning "jq non installé - mise à jour README ignorée"
        return
    fi

    print_info "Mise à jour du README pour: $repo_name"

    # Vérification de l'existence du fichier README
    if [ ! -f "$readme_path" ]; then
        print_warning "Fichier README non trouvé: $readme_path"
        return
    fi

    # Authentification via l'API Docker Hub
    local token
    token=$(curl -s -H "Content-Type: application/json" -X POST \
        -d '{"username": "'"$DOCKER_USER"'", "password": "'"$DOCKER_PASS"'"}' \
        https://hub.docker.com/v2/users/login/ | jq -r .token)

    # Vérification du token
    if [ "$token" == "null" ] || [ -z "$token" ]; then
        print_warning "Impossible d'obtenir un token d'authentification Docker Hub"
        return
    fi

    # Envoi du README via l'API
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: JWT $token" \
        -H "Content-Type: application/json" \
        -X PATCH \
        --data-raw "$(jq -n --arg desc "$(cat "$readme_path")" '{"full_description": $desc}')" \
        "https://hub.docker.com/v2/repositories/$repo_name/")

    if [ "$http_code" -eq 200 ]; then
        print_success "README mis à jour avec succès"
    else
        print_warning "Échec de la mise à jour du README (HTTP $http_code)"
    fi
}

# ------------------------------------------------------------------------------
# Fonction: sign_image_cosign
# Description: Signe une image Docker avec Cosign pour garantir son intégrité
# Arguments: $1 - Nom complet de l'image (avec tag)
# Prérequis: - Cosign installé
#            - Fichier cosign.key présent
#            - Variable COSIGN_PASSWORD définie (recommandé)
# Retour: 0 si succès, 1 si échec
# ------------------------------------------------------------------------------
sign_image_cosign() {
    local img=$1
    print_info "Signature cryptographique de: ${PURPLE}${img}${NC}"

    # Vérification de l'existence de la clé privée Cosign
    if [ ! -f "cosign.key" ]; then
        print_warning "Fichier cosign.key introuvable - signature ignorée"
        print_info "Générez une paire de clés avec: cosign generate-key-pair"
        return 1
    fi

    # Vérification de la variable d'environnement COSIGN_PASSWORD
    if [ -z "$COSIGN_PASSWORD" ]; then
        print_warning "Variable COSIGN_PASSWORD non définie - signature ignorée"
        print_info "En CI/CD, définissez COSIGN_PASSWORD pour automatiser la signature"
        return 1
    fi

    # Signature de l'image (--yes pour éviter la confirmation interactive)
    # Capture de la sortie complète pour diagnostic
    local output
    local exit_code

    print_info "Exécution de: cosign sign --yes --key cosign.key $img"
    output=$(cosign sign --yes --key cosign.key "$img" 2>&1)
    exit_code=$?

    # Vérification du code de retour (0 = succès)
    if [ $exit_code -eq 0 ]; then
        print_success "Signature Cosign validée pour $img"
        return 0
    else
        # Erreur lors de la signature - affichage détaillé
        print_error "Échec de la signature Cosign pour $img (code de sortie: $exit_code)"
        echo ""
        echo -e "${YELLOW}Détails de l'erreur:${NC}"
        echo -e "${RED}────────────────────────────────────────────────────────────────────${NC}"
        echo "$output" | sed 's/^/  /'
        echo -e "${RED}────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        return 1
    fi
}

# ==============================================================================
# SECTION 3: PROCESSUS DE PUBLICATION
# ==============================================================================

print_header

# ------------------------------------------------------------------------------
# ÉTAPE 1: Authentification Docker Hub
# ------------------------------------------------------------------------------
print_section "ÉTAPE 1/5: AUTHENTIFICATION DOCKER HUB"

print_info "Connexion au Docker Hub (utilisateur: ${DOCKER_USER})..."

# Vérification de la présence des credentials
if [ -z "$DOCKER_USER" ] || [ -z "$DOCKER_PASS" ]; then
    print_error "Variables DOCKER_USER ou DOCKER_PASS non définies"
    print_info "Définissez ces variables dans le fichier .env ou en ligne de commande"
    exit 1
fi

# Authentification via stdin pour plus de sécurité (pas de password en clair dans les logs)
if echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin > /dev/null 2>&1; then
    print_success "Authentification réussie (utilisateur: $DOCKER_USER)"
else
    print_error "Échec de l'authentification Docker Hub"
    print_warning "Vérifiez vos credentials dans le fichier .env"
    exit 1
fi

# ------------------------------------------------------------------------------
# ÉTAPE 2: Configuration de Docker Buildx
# ------------------------------------------------------------------------------
print_section "ÉTAPE 2/5: CONFIGURATION DU BUILDER BUILDX"

print_info "Vérification du builder avancé pour attestations de sécurité..."

# Vérification de l'existence du builder
if ! docker buildx inspect "$BUILDX_BUILDER" > /dev/null 2>&1; then
    print_info "Création d'un nouveau builder containerisé: $BUILDX_BUILDER"

    # Création d'un builder avec driver docker-container pour supporter:
    # - Attestations SBOM (Software Bill of Materials)
    # - Attestations de provenance
    # - Build multi-plateforme
    if docker buildx create --use --name "$BUILDX_BUILDER" \
        --driver docker-container --bootstrap > /dev/null 2>&1; then
        print_success "Builder '$BUILDX_BUILDER' créé et activé"
    else
        print_error "Échec de la création du builder"
        exit 1
    fi
else
    # Le builder existe déjà, on le sélectionne
    docker buildx use "$BUILDX_BUILDER" > /dev/null 2>&1
    print_success "Builder '$BUILDX_BUILDER' sélectionné"
fi

# ------------------------------------------------------------------------------
# ÉTAPE 3: Build des images avec attestations de sécurité
# ------------------------------------------------------------------------------
print_section "ÉTAPE 3/5: BUILD & PUSH DES IMAGES (avec attestations)"

print_info "Génération des images avec métadonnées de sécurité..."
print_info "${SYMBOL_ARROW} SBOM (Software Bill of Materials) sera généré"
print_info "${SYMBOL_ARROW} Provenance attestation sera générée (mode max)"

# Build et push des images avec docker-bake.hcl
# Options importantes:
# --push                          : Push automatique vers le registry
# --set *.attest=type=sbom        : Génère un SBOM pour chaque image
# --set *.attest=type=provenance  : Génère une attestation de provenance
if docker buildx bake \
    --push \
    --set *.attest=type=sbom \
    --set *.attest=type=provenance,mode=max \
    api front > /dev/null 2>&1; then

    print_success "Images construites et publiées avec succès"
    print_success "Métadonnées de sécurité (SBOM + Provenance) attachées"
    print_info "Les SBOMs sont consultables via Docker Scout ou docker buildx imagetools"
else
    print_error "Échec de la construction ou publication des images"
    print_warning "Vérifiez les logs Docker Buildx pour plus de détails"
    exit 1
fi

# ------------------------------------------------------------------------------
# ÉTAPE 4: Signature cryptographique avec Cosign (OPTIONNEL)
# ------------------------------------------------------------------------------
print_section "ÉTAPE 4/5: SIGNATURE CRYPTOGRAPHIQUE (Cosign) - OPTIONNEL"

# Vérification de l'installation de Cosign
if ! command -v cosign &> /dev/null; then
    print_warning "Cosign n'est pas installé sur ce système"
    print_info "La signature sera ignorée - Installation: https://docs.sigstore.dev/cosign/installation/"
    print_info "Les images sont publiées mais non signées"
else
    print_success "Cosign détecté: $(cosign version 2>/dev/null | head -n1 || echo 'version inconnue')"

    # Signature des images
    SIGN_SUCCESS=0

    print_info "Tentative de signature de l'image API..."
    if sign_image_cosign "$API_IMAGE"; then
        ((SIGN_SUCCESS++))
    fi

    print_info "Tentative de signature de l'image Frontend..."
    if sign_image_cosign "$FRONT_IMAGE"; then
        ((SIGN_SUCCESS++))
    fi

    # Affichage du résumé de signature (non bloquant)
    if [ $SIGN_SUCCESS -eq 2 ]; then
        print_success "Toutes les images ont été signées avec succès"
    elif [ $SIGN_SUCCESS -eq 1 ]; then
        print_warning "Une seule image a été signée avec succès"
    else
        print_warning "Aucune image n'a été signée - publication sans signatures"
        print_info "Les images restent utilisables mais non vérifiables cryptographiquement"
    fi
fi

# ------------------------------------------------------------------------------
# ÉTAPE 5: Mise à jour de la documentation (optionnel)
# ------------------------------------------------------------------------------
print_section "ÉTAPE 5/5: PUBLICATION DE LA DOCUMENTATION"

print_info "Mise à jour des README sur Docker Hub..."
push_readme "${DOCKER_USER}/tdocker-api" "./api/README.md"
push_readme "${DOCKER_USER}/tdfront-front" "./frontend/README.md"

# ==============================================================================
# SECTION 4: RAPPORT FINAL
# ==============================================================================

echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ${SYMBOL_OK} PUBLICATION TERMINÉE AVEC SUCCÈS${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Résumé de la publication:${NC}"
echo -e "  ${CYAN}├─${NC} ${BOLD}Images publiées:${NC}      ${GREEN}${SYMBOL_OK}${NC} $API_IMAGE"
echo -e "  ${CYAN}│${NC}                        ${GREEN}${SYMBOL_OK}${NC} $FRONT_IMAGE"
echo -e "  ${CYAN}├─${NC} ${BOLD}SBOM générés:${NC}         ${GREEN}${SYMBOL_OK}${NC} Consultables via Docker Scout"
echo -e "  ${CYAN}├─${NC} ${BOLD}Provenance:${NC}           ${GREEN}${SYMBOL_OK}${NC} Mode maximal activé"

# Affichage conditionnel de l'état de signature
if [ -n "$SIGN_SUCCESS" ]; then
    if [ $SIGN_SUCCESS -eq 2 ]; then
        echo -e "  ${CYAN}└─${NC} ${BOLD}Signatures Cosign:${NC}    ${GREEN}${SYMBOL_OK}${NC} Images signées et vérifiables"
    elif [ $SIGN_SUCCESS -eq 1 ]; then
        echo -e "  ${CYAN}└─${NC} ${BOLD}Signatures Cosign:${NC}    ${YELLOW}${SYMBOL_WARNING}${NC} Une image signée seulement"
    else
        echo -e "  ${CYAN}└─${NC} ${BOLD}Signatures Cosign:${NC}    ${YELLOW}${SYMBOL_WARNING}${NC} Non signées (optionnel)"
    fi
else
    echo -e "  ${CYAN}└─${NC} ${BOLD}Signatures Cosign:${NC}    ${YELLOW}${SYMBOL_WARNING}${NC} Non disponible (Cosign absent)"
fi

echo ""
echo -e "${CYAN}${BOLD}Commandes de vérification:${NC}"

# Affichage conditionnel des commandes selon la disponibilité de la signature
if [ -n "$SIGN_SUCCESS" ] && [ $SIGN_SUCCESS -gt 0 ]; then
    echo -e "  ${YELLOW}#${NC} Vérifier la signature: ${CYAN}cosign verify --key cosign.pub $API_IMAGE${NC}"
fi
echo -e "  ${YELLOW}#${NC} Consulter le SBOM:     ${CYAN}docker buildx imagetools inspect $API_IMAGE --format '{{json .SBOM}}'${NC}"
echo ""

exit 0
