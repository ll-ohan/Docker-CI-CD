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
    ('container_securise:latest', 'L''application utilise des secrets sécurisés via Docker Secrets et des variables d''environnement protégées'),
    ('container_web:production', 'Frontend moderne avec architecture multi-conteneurs isolée pour une sécurité renforcée'),
    ('container_api:v1.2', 'API REST robuste  avec gestion des erreurs, déployée via Docker Compose'),
    ('container_database:postgres15', 'Base de données PostgreSQL avec initialisation automatique et persistance des données via volumes'),
    ('container_monitoring:stable', 'Stack complète avec CI/CD automatisé via GitHub Actions et tests de sécurité intégrés'),
    ('container_nginx:alpine', 'Serveur web Nginx optimisé en mode production avec configuration SSL/TLS et reverse proxy'),
    ('container_tests:pytest', 'Suite de tests automatisés incluant tests unitaires et de sécurité avec coverage complet'),
    ('container_healthcheck:v2', 'Monitoring de santé des conteneurs avec endpoints de diagnostic'),
    ('container_backup:cron', 'Sauvegarde automatique des données avec rotation et chiffrement des volumes persistants'),
    ('container_network:isolated', 'Architecture réseau sécurisée avec isolation des conteneurs et communication inter-services chiffrée');

-- Logs de diagnostic (visibles via docker logs <container_id>)
SELECT 'Base de données initialisée avec succès!' AS message;
SELECT COUNT(*) AS nombre_items FROM items;
