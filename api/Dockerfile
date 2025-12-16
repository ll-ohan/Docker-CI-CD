# Stage 1: Builder - Installation des dépendances dans un environnement virtuel
FROM python:3.13-slim as builder 
# Utilisation d'une image Python slim pour réduire la taille et la surface d'attaque

# Configuration des variables d'environnement pour optimiser Python en production
ENV PYTHONDONTWRITEBYTECODE=1 \
# Désactive la création de fichiers .pyc (optimisation espace)
    PYTHONUNBUFFERED=1 \
# Force l'écriture directe des logs sans mise en buffer
    PATH="/opt/venv/bin:$PATH"
# Activation de l'environnement virtuel en modifiant le PATH

WORKDIR /app

# Création d'un environnement virtuel isolé pour les dépendances Python
# Permet de copier uniquement les packages nécessaires vers l'image finale
RUN python -m venv /opt/venv

# Copie du fichier de dépendances avant le code source (optimisation du cache Docker)
COPY requirements.txt .

# Installation des dépendances Python
RUN pip install --no-cache-dir --upgrade pip && \
# Assure l'utilisation de la dernière version de pip
    pip install --no-cache-dir -r requirements.txt
# Évite de stocker le cache pip, réduit la taille de l'image

# Stage 2: Runner - Image finale légère avec seulement le runtime
# Nouvelle image de base sans les dépendances de build, réduit la taille finale
FROM python:3.13-slim

# Métadonnées de l'image pour la traçabilité et la documentation
LABEL maintainer="Lohan Lacroix" \
      version="1.0" \
      description="API sécurisé non-root"

# Variables d'environnement identiques au builder pour cohérence
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Création d'un utilisateur non-privilégié pour exécuter l'application
RUN useradd -r -u 1001 -m appuser

# Copie de l'environnement virtuel depuis le stage builder
# --chown: définit appuser comme propriétaire pour éviter les problèmes de permissions
COPY --from=builder --chown=appuser:appuser /opt/venv /opt/venv

# Copie du code source de l'application avec les bonnes permissions
COPY --chown=appuser:appuser ./src /app/src

# Configuration du healthcheck pour la supervision de l'application
# Utilise urllib (bibliothèque standard Python) pour tester l'endpoint /status. Cela évite d'installer curl/wget.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/status').getcode() == 200 else 1)"

# Bascule vers l'utilisateur non-privilégié pour exécuter l'application
# Sécurise le conteneur en empêchant l'exécution en tant que root
USER appuser

# Déclaration du port exposé par l'application (documentation uniquement)
EXPOSE 8000

# Commande de démarrage de l'application FastAPI avec Uvicorn
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]