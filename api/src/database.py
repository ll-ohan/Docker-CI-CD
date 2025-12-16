"""
Gestion de la connexion à la base de données PostgreSQL.
"""

import os
import time
from contextlib import contextmanager
import psycopg2
from psycopg2.extras import RealDictCursor

# Configuration réseau : résolution via DNS interne Docker (service "db" dans docker-compose)
# Les credentials sont injectés par l'orchestrateur via variables d'environnement
DB_HOST = os.getenv("DB_HOST", "db")
DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASS", "password")
DB_PORT = 5432  # Port interne au réseau Docker (non exposé sur l'hôte)


def get_db_connection():
    """
    Établit une connexion PostgreSQL avec retry automatique.
    Gère le démarrage asynchrone des conteneurs : l'API attend que le service DB soit prêt.
    """
    while True:
        try:
            conn = psycopg2.connect(
                host=DB_HOST,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASS,
                port=DB_PORT,
                cursor_factory=RealDictCursor,
            )
            return conn
        except psycopg2.OperationalError as e:
            print(f"Database is not ready ... retry in 2s. Error: {e}")
            time.sleep(2)


@contextmanager
def get_db_cursor():
    """
    Context manager avec gestion transactionnelle (commit/rollback).
    """
    conn = get_db_connection()
    try:
        yield conn.cursor()
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()
