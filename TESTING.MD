# Pipeline de Qualité & Tests Automatisés

## Description

Ce projet intègre un pipeline de **Quality Assurance (QA)** complet et automatisé. Il assure la fiabilité, la lisibilité et la robustesse du code avant tout déploiement. L'ensemble de la suite de tests s'exécute dans un environnement conteneurisé éphémère pour garantir l'isolation et la reproductibilité des résultats.

## Fonctionnalités du Pipeline

Le script de contrôle qualité (`run_tests.sh`) orchestre une séquence de 5 étapes critiques (Quality Gate) :

1.  **Formatage** : Vérification de la conformité au style de code (PEP 8).
2.  **Linting** : Détection rapide des erreurs de syntaxe et des mauvaises pratiques.
3.  **Typage Statique** : Analyse de la cohérence des types de données.
4.  **Analyse Approfondie** : Audit de la complexité et de la qualité globale.
5.  **Tests Unitaires** : Validation de la logique métier avec rapport de couverture.

## Stack Technique

Les meilleurs outils de l'écosystème Python sont utilisés pour garantir l'excellence du code :

| Outil      | Rôle                                              | Version Cible |
| :--------- | :------------------------------------------------ | :------------ |
| **Black**  | Formateur de code sans compromis (PEP 8)          | Latest        |
| **Ruff**   | Linter extrêmement rapide (remplace Flake8/Isort) | Latest        |
| **Mypy**   | Vérificateur de typage statique                   | Latest        |
| **Pylint** | Analyseur de code statique (Score visé : >9/10)   | Latest        |
| **Pytest** | Framework de tests unitaires                      | 9.0.2         |

## Architecture des Tests

L'exécution des tests est entièrement encapsulée :

- **Image Docker** : `python:3.11-slim`
- **Volume** : Le code source local (`./api`) est monté dans le conteneur (`/app`) en lecture seule pour l'analyse.
- **Isolation** : Aucune dépendance de test n'est installée sur la machine hôte. Le conteneur est détruit après l'exécution.

## Rapport de Couverture

La suite de tests actuelle assure une couverture significative du code critique.

| Module            | Statements | Manquants | Couverture |
| :---------------- | :--------: | :-------: | :--------: |
| `src/database.py` |     28     |     0     |  **100%**  |
| `src/main.py`     |     47     |    17     |  **64%**   |
| **TOTAL**         |   **75**   |  **17**   |  **77%**   |

> **Note** : Les lignes non couvertes dans `main.py` (lignes 53-66, 72-83) correspondent principalement à des gestionnaires d'exceptions spécifiques ou des cas limites non simulés dans les tests actuels.

## Utilisation

Pour lancer la suite de tests complète (Quality Gate) :

```bash
./run_tests.sh
```

### Interprétation des Résultats

Le pipeline s'arrête immédiatement si une étape échoue. Un succès complet affiche le rapport final :

```plaintext
═══════════════════════════════════════════════════════════════════════════════════════
  [✓] CONTRÔLE QUALITÉ RÉUSSI - CODE PRÊT POUR LE DÉPLOIEMENT
═══════════════════════════════════════════════════════════════════════════════════════
```
