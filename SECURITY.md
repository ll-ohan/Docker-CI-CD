# Pipeline de Sécurité & Supply Chain

## Description

Ce projet intègre une approche **DevSecOps** rigoureuse, appliquant le principe de "Defense in Depth" (Défense en Profondeur). La sécurité est traitée comme une fonctionnalité de première classe, automatisée via des pipelines d'audit continus et de publication sécurisée. L'objectif est de garantir l'intégrité de la chaîne logistique logicielle (Supply Chain) et de minimiser la surface d'attaque des conteneurs en production.

## Fonctionnalités du Pipeline

L'architecture de sécurité repose sur deux piliers automatisés (`run_safety.sh` et `run_docker_publication.sh`) couvrant 6 niveaux de contrôle :

1.  **Analyse Statique (SAST)** : Audit du code source Python pour détecter les failles de sécurité logiques.
2.  **Linting de Sécurité** : Vérification de la conformité aux standards de codage sécurisé.
3.  **Scan de Conteneurs (SCA)** : Détection des vulnérabilités (CVE) dans les images Docker via un moteur dual (Trivy + Scout).
4.  **Durcissement (Hardening)** : Application des meilleures pratiques Docker (Non-root, images minimales).
5.  **Transparence (SBOM)** : Génération automatique de l'inventaire logiciel (Software Bill of Materials).
6.  **Authenticité** : Signature cryptographique des artefacts pour garantir leur provenance.

## Stack Technique

Des outils standards de l'industrie sont orchestrés pour assurer une couverture exhaustive :

| Outil            | Rôle                                              | Configuration  |
| :--------------- | :------------------------------------------------ | :------------- |
| **Bandit**       | Analyseur de sécurité pour code Python (SAST)     | High Severity  |
| **Trivy**        | Scanner de vulnérabilités conteneurs (AquaSec)    | CVE High/Crit  |
| **Docker Scout** | Analyse avancée et recommandations de remédiation | Latest         |
| **Cosign**       | Signature et vérification d'images (Sigstore)     | Key Pair       |
| **Buildx**       | Moteur de build supportant les attestations SLSA  | Provenance:Max |

## Architecture & Durcissement

La sécurité est intégrée dès la conception des `Dockerfile` pour réduire la surface d'attaque :

- **Principe de Moindre Privilège** :
  - **API** : Utilisation d'un utilisateur dédié `appuser` (UID 1001).
  - **Frontend** : Utilisation de l'image `nginx-unprivileged` (UID 101).
- **Images Minimales** :
  - Utilisation d'images `slim` (Python 3.13-slim, Alpine 3.21) pour réduire le nombre de paquets vulnérables.
- **Nettoyage** :
  - Pas de cache `pip` ni de fichiers `.pyc`.
  - Suppression des fichiers cachés et de la documentation dans le frontend.
- **Healthchecks Sécurisés** :
  - Implémentation native via `urllib` (API) et `wget` (Front) pour assurer la disponibilité sans installer d'outils superflus (comme curl).

## Rapport d'Audit Unifié

Les derniers tests d'intrusion et scans automatisés attestent de la robustesse de l'application.

| Composant          | Moteur       | Statut     | Détails                        |
| :----------------- | :----------- | :--------- | :----------------------------- |
| **Code Python**    | Bandit       | **SECURE** | Aucune faille logique détectée |
| **Code Python**    | Flake8       | **SECURE** | Code conforme aux standards    |
| **Image API**      | Trivy        | **SECURE** | 0 Vulnérabilités critiques     |
| **Image API**      | Docker Scout | **SECURE** | Recommandations appliquées     |
| **Image Frontend** | Trivy        | **SECURE** | 0 Vulnérabilités critiques     |
| **Image Frontend** | Docker Scout | **SECURE** | Base image à jour (Alpine)     |

> **État de la Supply Chain** :
>
> - [x] **SBOM** Généré et attaché aux images.
> - [x] **Provenance** Attestation SLSA générée.
> - [x] **Signature** Images signées cryptographiquement avec Cosign.

## Utilisation

Deux scripts permettent de valider et de sceller la sécurité du projet :

### 1. Audit de Sécurité (Local)

Lance l'analyse statique et le scan des vulnérabilités :

```bash
./run_safety.sh
```

### 2. Publication Sécurisée (CI/CD)

Construit, atteste (SBOM/Provenance), publie et signe les images :

```bash
./run_docker_publication.sh
```

### Vérification de l'Intégrité

Toute personne possédant la clé publique cosign.pub peut vérifier l'authenticité des images déployées :

```bash
cosign verify --key cosign.pub llohan/tdocker-api:latest
```
