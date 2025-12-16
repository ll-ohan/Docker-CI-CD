from fastapi.testclient import TestClient
from datetime import datetime
from unittest.mock import MagicMock, patch
from src.main import app

client = TestClient(app)

# Fixtures de test
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

# --- Nominal Cases ---


def test_read_status():
    """
    Healthcheck endpoint : validation du code HTTP 200 et payload JSON.
    """
    response = client.get("/status")
    assert response.status_code == 200
    assert response.json() == {"status": "OK"}


def test_read_items_success():
    """
    GET /items : récupération des items avec sérialisation Pydantic.
    """
    # Mock du context manager pour isoler le test sans accès PostgreSQL
    mock_cursor = MagicMock()
    mock_cursor.fetchall.return_value = MOCK_ITEMS

    mock_db_context = MagicMock()
    mock_db_context.__enter__.return_value = mock_cursor
    mock_db_context.__exit__.return_value = None

    with patch("src.main.get_db_cursor", return_value=mock_db_context):
        response = client.get("/items")

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 2
        assert data[0]["name"] == "Test Item 1"
        # Vérifie la sérialisation datetime par Pydantic
        assert "created_at" in data[0]


# --- Edge Cases ---


def test_read_items_empty():
    """
    GET /items avec table vide : retourne 200 avec liste JSON vide.
    """
    mock_cursor = MagicMock()
    mock_cursor.fetchall.return_value = []

    mock_db_context = MagicMock()
    mock_db_context.__enter__.return_value = mock_cursor

    with patch("src.main.get_db_cursor", return_value=mock_db_context):
        response = client.get("/items")

        assert response.status_code == 200
        assert response.json() == []


def test_read_items_internal_error():
    """
    Simulation d'une perte de connexion PostgreSQL : retourne HTTP 500.
    Reference: TD/test.md Section 3.B.8
    """
    # Mock side_effect pour simuler un crash réseau ou une indisponibilité DB
    with patch("src.main.get_db_cursor", side_effect=Exception("DB Connection Lost")):
        response = client.get("/items")

        assert response.status_code == 500
        assert "DB Connection Lost" in response.json()["detail"]
