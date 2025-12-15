from fastapi.testclient import TestClient
from datetime import datetime
from unittest.mock import MagicMock, patch
from src.main import app

client = TestClient(app)

# Données factices pour les tests
MOCK_ITEMS = [
    {
        "id": 1,
        "name": "Test Item 1",
        "description": "Desc 1",
        "created_at": datetime(2023, 1, 1, 12, 0, 0),
    },
    {
        "id": 2,
        "name": "Test Item 2",
        "description": None,
        "created_at": datetime(2023, 1, 2, 12, 0, 0),
    },
]

# --- Tests Nominaux (Happy Path) ---


def test_read_status():
    """
    Test 5: Vérification du endpoint /status.
    Reference: TD/test.md Section 3.A.5
    """
    response = client.get("/status")
    assert response.status_code == 200
    assert response.json() == {"status": "OK"}


def test_read_items_success():
    """
    Test 6: Récupération des items avec succès.
    Reference: TD/test.md Section 3.A.6
    """
    # On mock le context manager get_db_cursor
    mock_cursor = MagicMock()
    mock_cursor.fetchall.return_value = MOCK_ITEMS

    # Configuration du Context Manager Mock
    mock_db_context = MagicMock()
    mock_db_context.__enter__.return_value = mock_cursor
    mock_db_context.__exit__.return_value = None

    with patch("src.main.get_db_cursor", return_value=mock_db_context):
        response = client.get("/items")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert data[0]["name"] == "Test Item 1"
        # Vérification que Pydantic a bien sérialisé la date
        assert "created_at" in data[0]


# --- Edge Cases & Erreurs (Unhappy Path) ---


def test_read_items_empty():
    """
    Test 7: Liste d'items vide.
    Reference: TD/test.md Section 3.B.7
    """
    mock_cursor = MagicMock()
    mock_cursor.fetchall.return_value = []  # Retourne liste vide

    mock_db_context = MagicMock()
    mock_db_context.__enter__.return_value = mock_cursor

    with patch("src.main.get_db_cursor", return_value=mock_db_context):
        response = client.get("/items")

        assert response.status_code == 200
        assert response.json() == []


def test_read_items_internal_error():
    """
    Test 8: Erreur interne (DB crash).
    Reference: TD/test.md Section 3.B.8
    """
    # Le context manager lève une exception inattendue
    with patch("src.main.get_db_cursor", side_effect=Exception("DB Connection Lost")):
        response = client.get("/items")

        assert response.status_code == 500
        assert "DB Connection Lost" in response.json()["detail"]
