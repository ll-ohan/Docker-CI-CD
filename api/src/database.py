"""
Gestion de la connexion à la base de données PostgreSQL.
"""

import os
import time
from contextlib import contextmanager
import psycopg2
from psycopg2.extras import RealDictCursor

# Récupération des variables d'environnement définies dans le docker-compose ou .env
# Externalisation de la connexion via variables d'environnement
DB_HOST = os.getenv("DB_HOST", "db")
DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASS", "password")
DB_PORT = (
    5432  # Port PostgreSQL par défaut non accessible pour la sécurité donc non modifié.
)


def get_db_connection():
    """
    Tente de se connecter à la base de données.
    Inclut une logique de réessai simple car la DB peut être plus lente à démarrer que l'API.
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
    Gestionnaire de contexte pour ouvrir et fermer proprement les connexions.
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
