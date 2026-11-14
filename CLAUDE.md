# Projet Roblox — la Fabrique de jeux

Lire d'abord `PROJECT.md` (ce qu'on construit), puis `DECISIONS.md` et `PROGRESS.md`.
Tout le projet est en français : code, commentaires, messages, documentation.

## Fichiers de suivi du projet (convention project-kickoff)

Trois fichiers de suivi vivent à la racine : `PROJECT.md`, `DECISIONS.md`, `PROGRESS.md`.
Les tenir à jour automatiquement à chaque conversation :

- `DECISIONS.md` — à chaque décision explicite, ajouter une entrée EN HAUT
  (date + titre court + 1 à 3 phrases de raison). Une décision = changement de
  périmètre, de direction, d'esthétique, idée écartée. Pas de détails techniques mineurs.
  Si une décision renverse une direction ou une hypothèse déjà notée, utiliser
  le format narratif (Ce qu'on pensait / Pourquoi on a tourné / Ce qui a changé).
- `PROGRESS.md` — quand une unité substantielle (composant, fonctionnalité, jeu)
  est terminée, ajouter une entrée EN HAUT. Pas de petits ajustements ni de corrections de bugs.
- `PROJECT.md` — le mettre à jour quand le périmètre ou la direction change
  nettement (et noter ce changement dans DECISIONS.md aussi).

Après avoir noté, le dire en une phrase (« Noté dans DECISIONS.md : … »).
Ne demander qu'en cas de doute (réfléchir à voix haute ≠ décider).

`BESOINS.md` est le SEUL document qui liste ce que le projet attend du
propriétaire : y ajouter tout nouveau besoin, ne pas en créer un autre.

## Commandes

- Tout vérifier : `./pipeline/run.sh` (tests, lint, formatage, construction, validation).
- Créer un jeu : `./fabrique/nouveau-jeu.sh` (options dans `fabrique/README.md`).
- Outils : `cargo install --locked lune@0.11.1 selene@0.31.0`, puis
  `cargo install --locked stylua@2.6.0 --features luau` (l'option est obligatoire).

## Règles

- Ne pas modifier `maps/<jeu>.lua` à la main pour un jeu de la Fabrique : modifier
  `fabrique/gabarits/` ou `fabrique/themes.luau`, puis régénérer chaque jeu du
  catalogue avec la commande écrite en tête de son fichier.
- Le chemin obligatoire d'un parcours n'utilise que des plateformes fixes ; un
  piège mortel n'est jamais solide (`CanCollide = false`).
- La clé `ROBLOX_API_KEY` ne s'écrit jamais dans le dépôt. Publier une version
  visible des joueurs (`opencloud.py publier` sans `--brouillon`) demande l'accord
  du propriétaire. Après un test en brouillon d'un autre jeu sur la place des
  Îles Célestes, remettre `build/iles-celestes.rbxl` en brouillon.
- Ne rien affirmer sur le comportement du vrai moteur Roblox sans l'avoir vérifié
  (test Open Cloud ou documentation officielle) ; sinon écrire « non vérifié ».
