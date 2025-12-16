# Frontend Containerisé 🖥️

Ce projet est une interface utilisateur statique (SPA) développée en **Vanilla JS**, **HTML5** et **CSS3**. Elle reproduit l'interface visuelle de Docker Desktop ("Dark Mode") pour interagir avec l'API backend. Elle est servie par un serveur **Nginx** hautement sécurisé et optimisé.

## 🚀 Fonctionnalités

L'interface offre une expérience utilisateur fluide pour gérer les ressources :

- **Dashboard** : Visualisation sous forme de grille des "conteneurs" (items) avec statut simulé.
- **Recherche Instantanée** : Filtrage en temps réel des items (nom ou description).
- **Opérations CRUD** : Formulaire d'ajout rapide ("Run") et suppression ("Delete").
- **Monitoring API** : Indicateur visuel de l'état de connexion avec le backend (Engine running/stopped).
- **UX/UI** : Thème sombre fidèle à Docker Desktop, loader states et design réactif.

## 🛠 Stack Technique

- **Frontend** : HTML5, CSS3 (Variables & Flexbox/Grid), JavaScript ES6+ (Sans framework).
- **Serveur Web** : Nginx (version Unprivileged).
- **Image de base** : Alpine Linux 3.21.

## 📦 Points Forts Docker

Le `Dockerfile` met l'accent sur la sécurité et la légèreté :

1.  **Multi-stage Build** :
    - _Stage Builder_ : Copie des sources et nettoyage des fichiers inutiles (fichiers cachés, docs).
    - _Stage Runner_ : Image finale minimale basée sur Alpine.
2.  **Sécurité Maximale (Non-root)** : Utilisation de l'image officielle `nginxinc/nginx-unprivileged`. Le conteneur tourne avec l'utilisateur `101` (nginx) et écoute sur le port **8080** (les ports privilégiés <1024 étant interdits).
3.  **Reverse Proxy Intégré** : Configuration Nginx personnalisée pour rediriger les appels `/api/` vers le container backend (`http://api:8000`), évitant les problèmes de CORS.
4.  **Healthcheck Léger** : Utilisation de `wget` (présent dans Alpine) au lieu de `curl` pour vérifier que Nginx sert bien la page d'accueil.

## ⚙️ Configuration Nginx

Le fichier `nginx.conf` assure le rôle de serveur de fichiers statiques et de passerelle vers l'API :

```nginx
# Extrait de la configuration
location /api/ {
    proxy_pass http://api:8000/; # Redirection vers le backend
    proxy_set_header Host $host;
}
```

> Note : Le frontend s'attend à ce que l'API soit accessible via le nom d'hôte api sur le port 8000 (configuration standard Docker Compose).

## ▶️ Démarrage Rapide

### Avec Docker

Construire l'image :

```bash
docker build -t mini-frontend .
```

Lancer le conteneur :

```bash
docker run -p 8080:8080 mini-frontend
```

Accéder à l'application via `http://localhost:8080`.

_(Pour que l'application fonctionne pleinement, le conteneur API doit tourner sur le même réseau Docker)._
