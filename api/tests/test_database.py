import pytest
import psycopg2
from unittest.mock import MagicMock, patch
from src.database import get_db_connection, get_db_cursor

# --- Tests Nominaux (Happy Path) ---


def test_get_db_connection_success():
    """
    Test 1: Vérifie que la connexion est retournée immédiatement si la DB est prête.
    Reference: TD/test.md Section 3.A.1
    """
    with patch("src.database.psycopg2.connect") as mock_connect:
        # Configuration du mock pour retourner une fausse connexion
        mock_conn = MagicMock()
        mock_connect.return_value = mock_conn

        conn = get_db_connection()

        assert conn == mock_conn
        mock_connect.assert_called_once()


def test_get_db_cursor_success():
    """
    Test 2: Vérifie que le commit et close sont appelés en cas de succès.
    Reference: TD/test.md Section 3.A.2
    """
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    # On mock get_db_connection pour retourner notre fausse connexion
    with patch("src.database.get_db_connection", return_value=mock_conn):
        with get_db_cursor() as cur:
            # On simule une exécution SQL
            cur.execute("SELECT 1")

        # Vérifications
        mock_conn.commit.assert_called_once()  # Doit commit en sortie de bloc
        mock_conn.close.assert_called_once()  # Doit fermer la connexion


# --- Edge Cases & Erreurs (Unhappy Path) ---


def test_get_db_connection_retry():
    """
    Test 3: Vérifie le mécanisme de retry si la DB n'est pas prête (OperationalError).
    Reference: TD/test.md Section 3.B.3
    """
    with patch("src.database.psycopg2.connect") as mock_connect, patch(
        "src.database.time.sleep"
    ) as mock_sleep:

        # Scénario : 1er appel échoue (OperationalError), 2ème appel réussit
        mock_connect.side_effect = [
            psycopg2.OperationalError("DB not ready"),
            MagicMock(),
        ]

        conn = get_db_connection()

        # Vérifie qu'on a bien essayé 2 fois
        assert mock_connect.call_count == 2
        # Vérifie qu'on a attendu (sleep)
        mock_sleep.assert_called_once_with(2)
        assert conn is not None


def test_get_db_cursor_rollback_on_error():
    """
    Test 4: Vérifie que le rollback est effectué en cas d'erreur SQL.
    Reference: TD/test.md Section 3.B.4
    """
    mock_conn = MagicMock()

    with patch("src.database.get_db_connection", return_value=mock_conn):
        with pytest.raises(ValueError):  # On s'attend à ce que l'erreur remonte
            with get_db_cursor():
                raise ValueError("Erreur simulée pendant la requête")

        # Vérifications
        mock_conn.commit.assert_not_called()  # Ne doit PAS commit
        mock_conn.rollback.assert_called_once()  # Doit rollback
        mock_conn.close.assert_called_once()  # Doit toujours fermer
