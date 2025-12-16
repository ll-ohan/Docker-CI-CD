# Mini API Containerisée

## Description

Ce projet est une API REST développée avec FastAPI et PostgreSQL. Il démontre la mise en œuvre de bonnes pratiques en matière de containerisation Docker et de développement d'applications Python robustes.

## Fonctionnalités

L'API permet de gérer une liste d'items via des opérations CRUD :

- `GET /status` : Vérification de l'état du service (Healthcheck)
- `GET /items` : Récupérer la liste des items
- `POST /items` : Créer un nouvel item
- `DELETE /items/{item_id}` : Supprimer un item par son ID

## Stack Technique

- **Langage** : Python 3.11
- **Framework** : FastAPI
- **Base de données** : PostgreSQL (via psycopg2)
- **Tests** : Pytest et Unittest Mock
- **Qualité de code** : Pylint (Score : 10.00/10)

## Architecture Docker

Le Dockerfile a été conçu en suivant les meilleures pratiques de sécurité et d'optimisation :

1. **Multi-stage Build** : Utilisation d'une étape `builder` pour compiler les dépendances et d'une étape `runner` finale pour réduire la taille de l'image finale
2. **Sécurité (Non-root)** : L'application s'exécute avec un utilisateur dédié (`appuser`, UID 1001) pour éviter l'exécution en tant que root
3. **Healthcheck Natif** : Intégration d'une instruction `HEALTHCHECK` utilisant un script Python léger pour vérifier la disponibilité de l'API sans dépendre d'outils externes comme curl
4. **Optimisation du Cache** : Les dépendances (`requirements.txt`) sont installées avant la copie du code source pour optimiser le cache des couches Docker

## Configuration

L'application se configure via des variables d'environnement :

| Variable  | Description                | Valeur par défaut |
| :-------- | :------------------------- | :---------------- |
| `DB_HOST` | Hôte de la base de données | `db`              |
| `DB_NAME` | Nom de la base de données  | `postgres`        |
| `DB_USER` | Utilisateur PostgreSQL     | `postgres`        |
| `DB_PASS` | Mot de passe PostgreSQL    | `password`        |

## Démarrage

### Avec Docker

Construire l'image :

```bash
docker build -t mini-api .
```

Lancer le conteneur (nécessite une instance PostgreSQL accessible) :

```bash
docker run -p 8000:8000 --env DB_HOST=host.docker.internal mini-api
```

## Tests

L'API dispose d'une suite de tests complète couvrant les cas nominaux et les erreurs.

```bash
# Lancer les tests
pytest
```
