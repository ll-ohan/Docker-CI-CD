# Guide de Démarrage Rapide (QuickStart)

## Vue d'ensemble

Ce document centralise les procédures d'exploitation pour le cycle de vie de l'application (Dev, QA, Sec, Ops). L'infrastructure repose sur une automatisation complète via des scripts Bash, orchestrant Docker pour garantir la portabilité, la sécurité et la reproductibilité des environnements.

## Prérequis

Avant d'exécuter les pipelines, assurez-vous que l'environnement hôte dispose de :

- **Docker Engine** (v20.10+)
- **Docker Compose** (v2.0+)
- **Bash** (v4.0+)
- **Cosign** (Optionnel, pour la signature/vérification des images)

## Scripts d'Automatisation (Catalogue)

Le projet est piloté par 5 scripts majeurs situés à la racine :

| Script                        | Catégorie        | Description                                                        |
| :---------------------------- | :--------------- | :----------------------------------------------------------------- |
| `./run_app.sh`                | **Dev / Run**    | Démarre la stack complète (API + Front + DB) en local.             |
| `./run_tests.sh`              | **QA / CI**      | Exécute la Quality Gate (Linting, Typage, Tests Unitaires).        |
| `./run_safety.sh`             | **Sec / Audit**  | Lance l'audit de sécurité multi-couches (SAST + SCA).              |
| `./run_docker_publication.sh` | **Release / CD** | Construit, atteste (SBOM), signe et publie les images sur le Hub.  |
| `./deploy.sh`                 | **Ops / Deploy** | Déploie la dernière version stable en production (Pull & Restart). |

---

## Workflows Détaillés

### 1. Développement Local

Pour lancer l'environnement de développement et accéder à l'application :

```bash
./run_app.sh
```

- Action : Monte l'infrastructure via compose.yml.
  - Accès : _le port est à définir dans le fichier.env_
    - Frontend : `http://localhost:${FRONTEND_PORT}`
    - API & Base de donnée : Non accessible afin de limiter l'exposition pour des raisons de sécurités.

### 2. Pipeline d'Intégration Continue (CI)

Avant toute fusion de code, la qualité et la sécurité doivent être validées.

#### Étape A : Qualité du Code (Quality Gate) Vérifie le style (Black/Ruff) et la logique (Pytest).

```bash
./run_tests.sh
```

> Détails complets disponibles dans [TESTING.MD](TESTING.MD)

#### Étape B : Audit de Sécurité (Security Gate) Analyse le code (Bandit) et les vulnérabilités des conteneurs (Trivy/Scout).

```bash
./run_safety.sh
```

> Détails complets disponibles dans [SECURITY.md](SECURITY.md)

### 3. Pipeline de Livraison Continue (CD)

Une fois les tests validés, la publication des artefacts est déclenchée.

**Publication Sécurisée (Registry)** Ce script génère les images, les SBOMs, les attestations de provenance, et signe le tout cryptographiquement.

```bash
# Nécessite les variables DOCKER_USER et DOCKER_PASS dans .env
./run_docker_publication.sh
```

### 4. Déploiement en Production

Mise à jour de l'environnement de production avec les dernières images sécurisées.

4. Déploiement en Production

Mise à jour de l'environnement de production avec les dernières images sécurisées.

```bash
./deploy.sh
```

- Stratégie : Rolling update (Arrêt propre -> Pull -> Démarrage).
- Nettoyage : Les images orphelines (dangling) sont purgées automatiquement.

---

## Architecture du Pipeline CI/CD

Le flux complet d'automatisation suit cette séquence logique :

```
graph TD
    A[Code Commit] --> B(./run_tests.sh);
    B -- Success --> C(./run_safety.sh);
    C -- Success --> D(./run_docker_publication.sh);
    D --> E{Registry Docker Hub};
    E -->|Images Signées & SBOM| F(./deploy.sh);
    F --> G[Production Live];

    style B fill:#f9f,stroke:#333,stroke-width:2px
    style C fill:#ff9,stroke:#333,stroke-width:2px
    style D fill:#9cf,stroke:#333,stroke-width:2px
    style F fill:#9f9,stroke:#333,stroke-width:2px
```

---

## Configuration (.env et variables d'environnement)

Créez un fichier `.env` à la racine pour configurer les secrets (ne jamais commiter ce fichier) :

```ini
# Configuration de la base de données PostgreSQL
DB_USER=appuser
DB_PASS=changeme_secure_password
DB_NAME=appdb

# Configuration du frontend
FRONTEND_PORT=80

# Docker Hub Credentials
DOCKER_USER=votre_user
DOCKER_PASS=votre_token_d_acces

# Sécurité (Signature d'images)
COSIGN_PASSWORD=phrase_de_passe_cle_privee
DOCKER_CONTENT_TRUST_ROOT_PASSPHRASE=passphrase
DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE=passphrase
```

> **Note** : Un fichier `.env.example` est fourni à la racine du projet comme modèle. Copiez-le et adaptez les valeurs selon votre environnement. Supprimez les commentaires.

## Dépannage Rapide

### Erreur "Permission denied" sur les scripts :

```bash
chmod +x *.sh
```

- Fichier `.env` ou variable d'environnement manquante : Copiez le fichier `.env.example` vers `.env` et adaptez les valeurs selon votre environnement.
- Conflit de ports : Vérifiez que le port défini pour le frontend n'est pas déjà utilisé.
- Erreur Docker "Daemon not running" : Assurez-vous que Docker Desktop ou le service Docker est lancé (sudo systemctl start docker).
