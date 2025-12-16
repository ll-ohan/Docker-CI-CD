import pytest
import psycopg2
from unittest.mock import MagicMock, patch
from src.database import get_db_connection, get_db_cursor

# --- Nominal Cases ---


def test_get_db_connection_success():
    """
    Connexion immédiate si PostgreSQL est disponible.
    """
    # Mock de psycopg2.connect pour isoler le test sans dépendance réseau PostgreSQL
    with patch("src.database.psycopg2.connect") as mock_connect:
        mock_conn = MagicMock()
        mock_connect.return_value = mock_conn

        conn = get_db_connection()

        assert conn == mock_conn
        mock_connect.assert_called_once()


def test_get_db_cursor_success():
    """
    Cycle de vie transactionnel : commit et close appelés en sortie de contexte.
    """
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    # Mock de get_db_connection pour isoler le test sans dépendance réseau PostgreSQL
    with patch("src.database.get_db_connection", return_value=mock_conn):
        with get_db_cursor() as cur:
            cur.execute("SELECT 1")

        # Vérifie que la transaction est validée et la connexion fermée proprement
        mock_conn.commit.assert_called_once()
        mock_conn.close.assert_called_once()


# --- Edge Cases ---


def test_get_db_connection_retry():
    """
    Retry automatique en cas d'OperationalError (conteneur PostgreSQL pas encore prêt).
    Simule le démarrage asynchrone des services Docker Compose.
    """
    # Mock de connect et sleep pour simuler le retry sans attente réelle
    with patch("src.database.psycopg2.connect") as mock_connect, patch(
        "src.database.time.sleep"
    ) as mock_sleep:

        # Side effect : 1ère tentative échoue (DB non prête), 2ème réussit
        mock_connect.side_effect = [
            psycopg2.OperationalError("DB not ready"),
            MagicMock(),
        ]

        conn = get_db_connection()

        # Vérifie le comportement de retry : 2 tentatives avec sleep(2) entre les deux
        assert mock_connect.call_count == 2
        mock_sleep.assert_called_once_with(2)
        assert conn is not None


def test_get_db_cursor_rollback_on_error():
    """
    Gestion transactionnelle en cas d'erreur : rollback automatique sans commit.
    """
    mock_conn = MagicMock()

    # Mock de la connexion pour tester le comportement du context manager en cas d'exception
    with patch("src.database.get_db_connection", return_value=mock_conn):
        with pytest.raises(ValueError):
            with get_db_cursor():
                raise ValueError("Erreur simulée pendant la requête")

        # Vérifie l'atomicité : rollback sans commit, connexion fermée proprement
        mock_conn.commit.assert_not_called()
        mock_conn.rollback.assert_called_once()
        mock_conn.close.assert_called_once()
