-- Script d'initialisation de la base de données
-- Ce fichier sera exécuté automatiquement au démarrage du conteneur PostgreSQL

-- Création de la table items
CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insertion de données factices pour tester l'affichage
INSERT INTO items (name, description) VALUES
    ('Item 1', 'Ceci est le premier élément de test'),
    ('Item 2', 'Deuxième élément pour tester l''affichage'),
    ('Item 3', 'Troisième élément avec une description plus longue pour vérifier le rendu'),
    ('Item 4', 'Quatrième élément'),
    ('Item 5', 'Dernier élément de test');

-- Afficher un message de confirmation (visible dans les logs du conteneur)
SELECT 'Base de données initialisée avec succès!' AS message;
SELECT COUNT(*) AS nombre_items FROM items;
