# Frontend Containerisé

## Description

Ce projet est une Single Page Application (SPA) développée en Vanilla JS, HTML5 et CSS3. Il fournit une interface graphique reproduisant l'interface "Dark Mode" de Docker Desktop pour interagir avec l'API backend. L'application est servie par un serveur Nginx configuré pour la performance et la sécurité.

## Fonctionnalités

L'interface offre une expérience utilisateur fluide pour la gestion des ressources :

- **Dashboard** : Visualisation des items sous forme de grille avec statut simulé
- **Recherche Instantanée** : Filtrage en temps réel par nom ou description
- **Opérations CRUD** : Création ("Run") et suppression ("Delete") d'items
- **Monitoring** : Indicateur visuel de l'état de connexion avec l'API (Engine running/stopped)
- **UX/UI** : Design réactif, thème sombre et indicateurs de chargement

## Stack Technique

- **Langage** : HTML5, CSS3, JavaScript ES6+
- **Serveur Web** : Nginx (Version Unprivileged)
- **Image de base** : Alpine Linux 3.21
- **Architecture** : SPA (Single Page Application) sans framework

## Architecture Docker

Le Dockerfile a été conçu en suivant les meilleures pratiques de sécurité et d'optimisation :

1.  **Multi-stage Build** : Séparation de l'étape de construction (`builder`) pour le nettoyage des sources et de l'étape finale (`runner`) pour minimiser la taille de l'image.
2.  **Sécurité (Non-root)** : Utilisation de l'image `nginx-unprivileged` exécutant le service avec l'utilisateur `nginx` (UID 101) et écoutant sur le port 8080.
3.  **Reverse Proxy** : Configuration Nginx intégrée pour rediriger les appels `/api/` vers le backend, résolvant les problématiques de CORS (Cross-Origin Resource Sharing).
4.  **Healthcheck Léger** : Implémentation d'une vérification d'état utilisant `wget` (natif Alpine) pour confirmer la disponibilité du serveur web.

## Configuration

Le serveur Nginx est configuré via le fichier `nginx.conf` pour assurer le service des fichiers statiques et le routage API.

| Directive    | Description                  | Valeur par défaut       |
| :----------- | :--------------------------- | :---------------------- |
| `listen`     | Port d'écoute du conteneur   | `8080`                  |
| `proxy_pass` | URL du service Backend       | `http://api:8000/`      |
| `root`       | Répertoire racine des assets | `/usr/share/nginx/html` |

> **Note** : Le frontend s'attend à ce que le service API soit accessible via le nom d'hôte `api` sur le port `8000` (configuration par défaut du Docker Compose).

## Démarrage

### Avec Docker

Construire l'image :

```bash
docker build -t mini-frontend .
```
