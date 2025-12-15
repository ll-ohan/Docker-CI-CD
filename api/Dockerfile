# --- Stage 1 : Builder ---
FROM python:3.11-slim as builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# --- Stage 2 : Runner ---
FROM python:3.11-slim

# Métadonnées
LABEL maintainer="Lohan Lacroix" \
      version="1.0" \
      description="API sécurisé non-root"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Plus besoin d'apt-get install curl !
# On crée juste l'utilisateur
RUN useradd -r -u 1001 -m appuser

COPY --from=builder --chown=appuser:appuser /opt/venv /opt/venv
COPY --chown=appuser:appuser ./src /app/src

# --- HEALTHCHECK PYTHON PUR ---
# On utilise un "one-liner" Python pour tester la connexion.
# Si la requête échoue ou renvoie un code != 200, le script quitte avec exit 1 (unhealthy)
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/status').getcode() == 200 else 1)"

USER appuser

EXPOSE 8000

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]