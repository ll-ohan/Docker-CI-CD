# --- Stage 1 : Préparation des assets ---
# On fixe la version d'Alpine pour la reproductibilité (éviter "latest")
FROM alpine:3.21 as builder

WORKDIR /app

# Copie des sources
COPY ./src .

# (Optionnel) Simulation d'optimisation
# Ici, on nettoie les fichiers cachés ou temporaires qui traîneraient dans src
RUN find . -type f -name ".*" -delete && \
    rm -rf *.md

# --- Stage 2 : Serveur Web Sécurisé ---
# Utilisation de l'image officielle "Unprivileged" (basée sur Alpine)
# Elle tourne nativement avec l'utilisateur 101 (nginx) et écoute sur 8080.
FROM nginxinc/nginx-unprivileged:alpine3.21-slim

USER root

RUN apk update && \
    apk upgrade --no-cache

USER 101

# Métadonnées
LABEL maintainer="Lohan Lacroix" \
      version="1.0" \
      description="Serveur statique sécurisé non-root"

# L'image unprivileged utilise le port 8080 par défaut.
# On copie notre config perso si elle existe, sinon la config par défaut suffit souvent.
COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf

# Copie des fichiers statiques depuis le builder
# On utilise --chown direct pour éviter de faire un RUN chown (lourd) ensuite
COPY --from=builder --chown=nginx:nginx /app /usr/share/nginx/html

# --- HEALTHCHECK ---
# Alpine contient "wget" par défaut (plus léger que d'installer curl).
# On vérifie que la page d'accueil répond (code 200).
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -q --spider http://127.0.0.1:8080/ || exit 1

# Pas besoin de "USER nginx" ni de "EXPOSE 8080" explicites car
# ils sont déjà définis dans l'image de base, mais on le laisse pour la documentation.
EXPOSE 8080

# Commande de lancement (optimisée pour la performance)
CMD ["nginx", "-g", "daemon off;"]