-- Script d'initialisation PostgreSQL
-- Exécuté automatiquement par le conteneur au premier démarrage via /docker-entrypoint-initdb.d/

-- Schéma de données
CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed data pour environnement de développement
INSERT INTO items (name, description) VALUES
    ('Item 1', 'Ceci est le premier élément de test'),
    ('Item 2', 'Deuxième élément pour tester l''affichage'),
    ('Item 3', 'Troisième élément avec une description plus longue pour vérifier le rendu'),
    ('Item 4', 'Quatrième élément'),
    ('Item 5', 'Dernier élément de test');

-- Logs de diagnostic (visibles via docker logs <container_id>)
SELECT 'Base de données initialisée avec succès!' AS message;
SELECT COUNT(*) AS nombre_items FROM items;
