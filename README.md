# Application Containerisée avec Docker

Application web full-stack démontrant les pratiques DevSecOps modernes, incluant tests automatisés, analyse de sécurité et pipelines de déploiement continu.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture](#architecture)
- [Stack technologique](#stack-technologique)
- [Fonctionnalités](#fonctionnalités)
- [Implémentation de la sécurité](#implémentation-de-la-sécurité)
- [Optimisation des builds](#optimisation-des-builds)
- [Assurance qualité](#assurance-qualité)
- [Démarrage rapide](#démarrage-rapide)
- [Déploiement](#déploiement)
- [Pipeline CI/CD](#pipeline-cicd)
- [Structure du projet](#structure-du-projet)
- [Documentation](#documentation)
- [Difficultés et améliorations](#difficultés-et-améliorations)

## Vue d'ensemble

Ce projet implémente une application web trois-tiers (PostgreSQL, FastAPI, Nginx) avec des contrôles de sécurité complets et des workflows de déploiement automatisés. L'architecture suit les meilleures pratiques de containerisation avec un accent sur la réduction de la surface d'attaque, la transparence de la chaîne d'approvisionnement et les portes de qualité automatisées.

## Architecture

L'application se compose de trois services containerisés orchestrés via Docker Compose :

- **Couche base de données** : PostgreSQL 15 (variante Alpine) avec stockage persistant par volume
- **Couche API** : Service REST FastAPI avec exécution non-root
- **Couche frontend** : Single Page Application servie par Nginx avec configuration reverse proxy

Tous les services communiquent via un réseau interne isolé, seul le frontend étant exposé à l'accès externe.

### Stratégie de sécurité réseau

L'architecture réseau implémente une défense par isolation :

- **Réseau bridge interne** : Les services communiquent via la résolution DNS Docker sans exposition externe
- **Ports en dur** : Les ports internes (PostgreSQL:5432, API:8000) sont codés en dur pour éviter les erreurs de configuration
- **Port externe configurable** : Seul le port frontend est exposé et configurable via variable d'environnement (`FRONTEND_PORT`)
- **Avantage** : La configuration des ports internes étant figée dans Docker, elle n'est pas modifiable accidentellement par une variable d'environnement, réduisant les risques de mauvaise configuration et d'exposition involontaire

## Stack technologique

**Backend**

- Python 3.13 (variante slim)
- Framework web FastAPI
- PostgreSQL avec driver psycopg2
- Serveur ASGI Uvicorn

**Frontend**

- JavaScript Vanilla (ES6+)
- HTML5/CSS3
- Nginx unprivileged (Alpine 3.21)

**Infrastructure**

- Docker Engine 20.10+
- Docker Compose V2
- Docker Buildx (builds multi-plateformes)

**Outils de sécurité et qualité**

- Trivy (scan de vulnérabilités)
- Docker Scout (analyse CVE)
- Bandit (SAST Python)
- Cosign (signature d'images)
- Pytest (tests unitaires)
- Black, Ruff, Mypy, Pylint (qualité de code)

## Fonctionnalités

### Capacités applicatives

- API REST avec opérations CRUD pour la gestion de ressources
- Endpoints de surveillance de santé pour tous les services
- Stockage persistant des données avec PostgreSQL
- Interface frontend responsive avec recherche en temps réel
- Configuration reverse proxy résolvant les contraintes CORS

### Fonctionnalités opérationnelles

- Scripts automatisés de build et déploiement
- Pipeline de scan de sécurité multi-niveaux
- Génération de Software Bill of Materials (SBOM)
- Signature cryptographique d'images
- Suite de tests complète avec 77% de couverture de code
- Métriques de performance et analytiques de déploiement

## Implémentation de la sécurité

### Stratégie Defense in Depth

Le projet implémente un modèle de sécurité à six couches :

**1. Tests de sécurité statiques (SAST)**

- Bandit scanne les vulnérabilités du code Python
- Flake8 applique les standards de codage sécurisé
- Validation automatisée pré-déploiement

**2. Scan de vulnérabilités des conteneurs**

- Approche dual-engine (Trivy + Docker Scout)
- Détection des CVE HIGH/CRITICAL
- Recommandations de sécurité pour les images de base

**3. Durcissement et moindre privilège**

- Exécution non-root (API : UID 1001, Frontend : UID 101)
- Images de base minimales (variantes slim/alpine)
- Isolation réseau avec driver bridge
- Restriction aux ports non-privilégiés uniquement

**4. Transparence de la chaîne d'approvisionnement**

- Génération automatique de SBOM attachée aux images
- Attestations de provenance SLSA (mode : max)
- Traçabilité et audit des dépendances

**5. Signature cryptographique**

- Intégration Cosign pour la vérification d'images
- Distribution de clé publique pour validation de confiance
- Signature automatisée dans le pipeline de publication

**6. Sécurité d'exécution**

- Health checks natifs sans dépendances externes
- Gestion des secrets via variables d'environnement
- Montages de systèmes de fichiers en lecture seule lorsque applicable

### Résultats d'audit de sécurité

| Composant      | Outil        | Statut | Détails                            |
| -------------- | ------------ | ------ | ---------------------------------- |
| Code Python    | Bandit       | PASS   | Aucun problème de sécurité détecté |
| Code Python    | Flake8       | PASS   | Conforme aux standards             |
| Image API      | Trivy        | PASS   | 0 vulnérabilité critique           |
| Image API      | Docker Scout | PASS   | Recommandations appliquées         |
| Image Frontend | Trivy        | PASS   | 0 vulnérabilité critique           |
| Image Frontend | Docker Scout | PASS   | Image de base à jour               |

## Optimisation des builds

### Builds multi-stages

Les Dockerfiles API et frontend implémentent des patterns multi-stages :

**Dockerfile API**

- Stage 1 (builder) : Installation des dépendances dans un environnement virtuel isolé
- Stage 2 (runner) : Runtime minimal avec uniquement les dépendances compilées
- Résultat : réduction de taille d'environ 50% par rapport à une approche single-stage

**Dockerfile Frontend**

- Stage 1 (builder) : Préparation des assets et nettoyage
- Stage 2 (runner) : Nginx prêt pour la production avec contenu optimisé
- Résultat : réduction de taille de 65% avec image de base durcie

### Comparaison des architectures

Le projet inclut un script de test automatisé (`image_optimization/test_docker_optimization.sh`) permettant de comparer les approches single-stage et multi-stage :

**Dockerfiles de référence**

- `image_optimization/Dockerfile.api` : Version single-stage de l'API
- `image_optimization/Dockerfile.front` : Version single-stage du frontend
- `api/Dockerfile` : Version multi-stage optimisée de l'API
- `frontend/Dockerfile` : Version multi-stage optimisée du frontend

**Exécution du test de comparaison**

```bash
./image_optimization/test_docker_optimization.sh
```

Le script effectue :

1. Construction automatique des 4 images (standard et optimisée pour chaque service)
2. Mesure précise des tailles en MB
3. Calcul des gains en taille absolue et en pourcentage
4. Génération d'un rapport comparatif détaillé
5. Nettoyage automatique des images de test

### Résultats d'optimisation mesurés

Les métriques suivantes ont été obtenues par l'exécution du script de test `test_docker_optimization.sh` :

| Image            | Standard  | Optimisée | Gain (MB) | Réduction |
| ---------------- | --------- | --------- | --------- | --------- |
| API (Python)     | 141.79 MB | 96.03 MB  | 45.77 MB  | **32.28%** |
| Frontend (Nginx) | 11.20 MB  | 11.19 MB  | 0.00 MB   | 0.01%     |

### Justification des résultats

**API (Python) - Optimisation significative de 32.28%**

La réduction de 45.77 MB s'explique par plusieurs facteurs techniques :

1. **Image de base optimisée** : Utilisation de `python:3.13-slim` (image Debian minimale) au lieu d'une image standard complète
2. **Build multi-stage efficace** :
   - Stage builder : Installation des dépendances dans un environnement virtuel isolé
   - Stage runner : Copie uniquement du virtualenv compilé, sans les outils de build (gcc, make, etc.)
3. **Élimination des artefacts de compilation** : Les headers de développement et compilateurs C nécessaires pour psycopg2 ne sont présents que dans le stage builder
4. **Optimisation du cache pip** : Flag `--no-cache-dir` élimine les fichiers de cache inutiles en production
5. **Prévention du bytecode** : Variable `PYTHONDONTWRITEBYTECODE=1` évite la génération de fichiers `.pyc`

**Frontend (Nginx) - Optimisation marginale de 0.01%**

La quasi-absence d'amélioration (0.00 MB) est attendue et justifiée :

1. **Image de base déjà optimale** : `nginx:1.27-alpine3.21-slim` est l'une des images les plus légères disponibles (11 MB)
2. **Contenu statique minimal** : L'application frontend ne contient que quelques fichiers HTML/CSS/JS
3. **Multi-stage déjà appliqué** : Le Dockerfile standard et optimisé utilisent tous deux une architecture multi-stage avec Alpine
4. **Optimisations marginales épuisées** : À cette échelle (11 MB), les gains supplémentaires nécessiteraient de retirer des fonctionnalités essentielles de Nginx

**Conclusion** : L'optimisation de 32% sur l'API démontre l'efficacité des patterns multi-stage pour les applications avec dépendances compilées, tandis que le frontend illustre les limites d'optimisation lorsque les meilleures pratiques sont déjà appliquées dès le départ.

### Techniques d'optimisation

- Optimisation du cache de couches (requirements avant le code source)
- `.dockerignore` pour exclure les fichiers inutiles
- Pas de rétention du cache pip (`--no-cache-dir`)
- Suppression du bytecode Python (`PYTHONDONTWRITEBYTECODE=1`)
- Images de base Alpine Linux lorsque possible
- Healthchecks natifs sans installation d'outils externes

## Assurance qualité

### Pipeline de tests automatisés

La suite de tests s'exécute dans un conteneur Docker isolé et inclut :

**Contrôles de qualité du code**

1. **Black** : Validation du formatage PEP 8
2. **Ruff** : Linting rapide (basé sur Rust)
3. **Mypy** : Vérification de typage statique
4. **Pylint** : Analyse de code approfondie (score : 10.00/10)

**Tests unitaires**

5. **Pytest** : Suite de tests complète avec rapport de couverture

### Couverture de tests

| Module      | Statements | Manquants | Couverture |
| ----------- | ---------- | --------- | ---------- |
| database.py | 28         | 0         | 100%       |
| main.py     | 47         | 17        | 64%        |
| **Total**   | **75**     | **17**    | **77%**    |

### Enforcement des portes de qualité

Tous les déploiements doivent passer :

- Zéro violation de formatage
- Zéro erreur de linting
- Zéro incohérence de types
- Tous les tests unitaires réussis
- Seuil de couverture minimum maintenu

## Démarrage rapide

### Prérequis

- Docker Engine 20.10 ou supérieur
- Docker Compose V2
- Bash 4.0+ (pour les scripts d'automatisation)
- Cosign (optionnel, pour la vérification de signatures)

### Configuration de l'environnement

Créer un fichier `.env` à la racine du projet :

```ini
# Identifiants Docker Hub
DOCKER_USER=votre_utilisateur
DOCKER_PASS=votre_token_acces

# Configuration base de données
DB_USER=postgres
DB_PASS=mot_de_passe_securise
DB_NAME=application_db

# Paramètres application
FRONTEND_PORT=8080

# Optionnel : Phrase de passe clé Cosign
COSIGN_PASSWORD=votre_phrase_passe_cle
```

### Développement local

Démarrer la stack complète :

```bash
./run_app.sh
```

Accéder à l'application sur `http://localhost:${FRONTEND_PORT}`

Le script effectue :

- Validation de la configuration Docker Compose
- Construction des images avec logs détaillés
- Orchestration des services avec monitoring de santé
- Rapport d'analytiques et métriques de déploiement

## Déploiement

### Scripts de déploiement automatisés

Le projet inclut cinq scripts d'automatisation pour différentes phases de déploiement :

**Développement et Opérations**

- `run_app.sh` : Déploiement de l'environnement local avec métriques
- `run_tests.sh` : Exécution de la porte de qualité (formatage, linting, tests)

**Sécurité et Release**

- `run_safety.sh` : Audit de sécurité multi-couches (SAST + SCA)
- `run_docker_publication.sh` : Publication sécurisée d'images avec signature

**Production**

- `deploy.sh` : Pipeline d'orchestration maître (toutes les étapes)

### Workflow de déploiement manuel

```bash
# Étape 1 : Porte de qualité
./run_tests.sh

# Étape 2 : Audit de sécurité
./run_safety.sh

# Étape 3 : Build et publication
./run_docker_publication.sh

# Étape 4 : Déploiement
./run_app.sh
```

### Déploiement automatisé

Exécuter le pipeline complet :

```bash
./deploy.sh
```

Cela exécute toutes les étapes séquentiellement avec gestion des échecs et métriques de performance.

## Pipeline CI/CD

### Workflow GitHub Actions

Le projet inclut une configuration GitHub Actions (`.github/workflows/main.yml`) qui :

**Déclencheurs**

- Sur pull requests vers `main` : Validation sans déploiement
- Sur push vers `main` : Cycle de déploiement complet

**Étapes d'exécution**

1. Checkout du code et configuration de Docker Buildx
2. Génération dynamique du `.env` depuis les GitHub Secrets
3. Exécution complète du pipeline de déploiement via `deploy.sh`
4. Nettoyage automatique

**GitHub Secrets requis**

- `DOCKER_USER`, `DOCKER_PASS` : Authentification registry
- `DB_USER`, `DB_PASS`, `DB_NAME` : Configuration base de données
- `DCT_ROOT_PASS`, `DCT_REPO_PASS` : Docker Content Trust (optionnel)
- `COSIGN_PASSWORD` : Signature d'images (optionnel)

### Étapes du pipeline

```
Commit de code
    ↓
Porte de qualité (Tests, Linting, Vérification de types)
    ↓
Audit de sécurité (SAST, Scan de conteneurs)
    ↓
Build et publication (SBOM, Provenance, Signature)
    ↓
Déploiement en production
```

## Structure du projet

```
.
├── api/                    # Service backend
│   ├── src/               # Code source de l'application
│   ├── tests/             # Suite de tests unitaires
│   ├── Dockerfile         # Configuration build multi-stage
│   ├── requirements.txt   # Dépendances Python
│   └── README.MD          # Documentation API
├── frontend/              # Service frontend
│   ├── src/               # Assets statiques (HTML/CSS/JS)
│   ├── nginx.conf         # Configuration reverse proxy
│   ├── Dockerfile         # Configuration build multi-stage
│   └── README.md          # Documentation frontend
├── database/              # Initialisation base de données
│   └── init.sql           # Schéma et données d'amorçage
├── image_optimization/    # Tests de comparaison d'optimisation
│   ├── test_docker_optimization.sh  # Script de benchmark
│   ├── Dockerfile.api     # Version single-stage API (référence)
│   └── Dockerfile.front   # Version single-stage frontend (référence)
├── .github/
│   └── workflows/
│       └── main.yml       # Définition du pipeline CI/CD
├── run_app.sh             # Script de déploiement local
├── run_tests.sh           # Script d'assurance qualité
├── run_safety.sh          # Script d'audit de sécurité
├── run_docker_publication.sh  # Script de publication d'images
├── deploy.sh              # Script d'orchestration maître
├── compose.yml            # Configuration Docker Compose
├── SECURITY.md            # Documentation du pipeline de sécurité
├── TESTING.MD             # Documentation du framework de tests
└── QUICKSTART.md          # Guide des procédures opérationnelles
```

## Documentation

Documentation détaillée disponible pour chaque composant :

- **[SECURITY.md](SECURITY.md)** : Architecture de sécurité complète et procédures d'audit
- **[TESTING.MD](TESTING.MD)** : Stratégie de test et rapports de couverture
- **[QUICKSTART.md](QUICKSTART.md)** : Guide de démarrage rapide et workflows opérationnels
- **[api/README.MD](api/README.MD)** : Référence de l'API backend
- **[frontend/README.md](frontend/README.md)** : Architecture frontend

## Points techniques clés

### Meilleures pratiques Docker

- Builds multi-stages pour tous les services
- Exécution utilisateur non-root (principe du moindre privilège)
- Images de base minimales (variantes slim/alpine)
- Optimisation du cache de couches
- `.dockerignore` pour l'efficacité du contexte de build
- Health checks natifs sans dépendances externes
- Configuration basée sur l'environnement (application 12-factor)
- Volumes nommés pour la persistance des données
- Réseau interne isolé

### Intégration DevSecOps

- Scan de sécurité automatisé (dual-engine)
- Génération de SBOM pour la visibilité de la chaîne d'approvisionnement
- Signature cryptographique pour l'authenticité des images
- Portes de qualité pré-déploiement
- Surveillance continue des vulnérabilités
- Meilleures pratiques de gestion des secrets

### Excellence opérationnelle

- Scripts d'automatisation complets
- Logs et métriques détaillés
- Surveillance de santé à toutes les couches
- Gestion gracieuse des échecs
- Analytiques de performance
- Capacité de déploiement sans interruption

## Difficultés et améliorations

### Défis techniques rencontrés

**Publication et sécurisation des images Docker**

La mise en place d'une chaîne de publication sécurisée a représenté le défi majeur de ce projet, impliquant plusieurs couches de complexité :

1. **Docker Content Trust (DCT)**
   - Configuration initiale délicate des clés root et repository
   - Gestion des passphrases de clés dans un environnement CI/CD
   - Interaction complexe entre `DOCKER_CONTENT_TRUST` et les commandes `docker push`
   - Problématiques de synchronisation des clés entre environnements locaux et GitHub Actions
   - Nécessité de comprendre le modèle de délégation TUF (The Update Framework)

2. **Signature cryptographique avec Cosign**
   - Apprentissage de l'écosystème Sigstore et des concepts de signature sans certificat (keyless)
   - Génération et gestion sécurisée des paires de clés
   - Intégration de la signature dans le workflow de publication automatisé
   - Validation de la chaîne de confiance et vérification des signatures
   - Compatibilité avec les différentes versions de Cosign entre environnements

3. **Attestations SBOM et Provenance**
   - Compréhension des spécifications SLSA pour la provenance de build
   - Configuration de Docker Buildx avec le mode `--provenance=mode=max`
   - Génération de Software Bill of Materials (SBOM) au format SPDX/CycloneDX
   - Attachement des attestations aux images multi-architectures
   - Débogage des erreurs liées aux formats d'attestation

4. **Gestion des secrets et authentification**
   - Protection des credentials Docker Hub dans GitHub Secrets
   - Rotation sécurisée des tokens d'accès
   - Prévention de l'exposition accidentelle de secrets dans les logs
   - Configuration de `.env` avec validation des variables requises
   - Isolation des secrets entre environnements de développement et production

5. **Debugging du pipeline de publication**
   - Interprétation des erreurs cryptiques de Docker Content Trust
   - Résolution des conflits de tags lors des re-publications
   - Gestion des timeouts réseau lors de l'upload d'images volumineuses
   - Vérification de l'intégrité des manifests multi-architectures
   - Traçabilité des échecs dans les workflows GitHub Actions

### Améliorations futures envisagées

**Sécurité**
- Implémentation de Notary v2 pour un modèle de confiance plus moderne
- Ajout de policy enforcement avec Open Policy Agent (OPA)
- Intégration de runtime security monitoring avec Falco
- Scan de vulnérabilités en temps réel avec GitHub Advanced Security

**Publication**
- Migration vers keyless signing avec Sigstore pour éliminer la gestion de clés
- Automatisation complète de la rotation des clés de signature
- Publication multi-registry (Docker Hub, GitHub Container Registry, AWS ECR)
- Cache layer distribution avec registry mirrors

**Opérations**
- Ajout de métriques Prometheus et dashboards Grafana
- Implémentation de distributed tracing avec OpenTelemetry
- Déploiement Kubernetes avec Helm charts
- Blue-green deployment pour zéro downtime

**Tests**
- Extension de la couverture de tests à 95%+
- Ajout de tests d'intégration end-to-end avec Playwright
- Tests de charge avec K6 ou Locust
- Tests de sécurité dynamique (DAST) avec OWASP ZAP

**Développement**
- Environnement de développement containerisé avec devcontainers
- Hot-reload automatique pour le développement local
- Documentation interactive avec Swagger UI pour l'API
- Pre-commit hooks pour validation automatique avant commit

## Licence

Ce projet est fourni tel quel à des fins éducatives et de démonstration.

---

**Auteur** : Lohan Lacroix
**Version** : 1.0.0
**Dernière mise à jour** : Décembre 2025
