"""
Gestion des routes de l'API FastAPI.
"""

from typing import List, Optional
from datetime import datetime
from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel
from .database import get_db_cursor

app = FastAPI(title="TD Containerized API")


class ItemCreate(BaseModel):
    """Payload de création (id et created_at auto-générés par PostgreSQL)."""

    name: str
    description: Optional[str] = None


class Item(BaseModel):
    """Modèle de réponse complet."""

    id: int
    name: str
    description: Optional[str] = None
    created_at: datetime


@app.get("/status")
def read_status():
    """Healthcheck endpoint pour orchestrateur (Docker Compose, K8s)."""
    return {"status": "OK"}


@app.get("/items", response_model=List[Item])
def read_items():
    """Récupère tous les items."""
    try:
        with get_db_cursor() as cur:
            cur.execute(
                "SELECT id, name, description, created_at FROM items ORDER BY id DESC;"
            )
            items = cur.fetchall()
            return items
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.post("/items", response_model=Item, status_code=status.HTTP_201_CREATED)
def create_item(item: ItemCreate):
    """Crée un nouvel item."""
    try:
        with get_db_cursor() as cur:
            cur.execute(
                """
                INSERT INTO items (name, description)
                VALUES (%s, %s)
                RETURNING id, name, description, created_at;
                """,
                (item.name, item.description),
            )
            new_item = cur.fetchone()
            return new_item
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int):
    """Supprime un item."""
    try:
        with get_db_cursor() as cur:
            cur.execute("DELETE FROM items WHERE id = %s RETURNING id;", (item_id,))
            deleted = cur.fetchone()

            if not deleted:
                raise HTTPException(status_code=404, detail="Item not found")

    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
