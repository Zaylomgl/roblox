# Instructions pour Claude (projet Roblox)

Ce fichier est lu automatiquement par Claude Code. Il résume le projet et ses
règles ; les détails sont dans les documents liés.

## Le projet

- Langue : **français** (code, commentaires, messages, documents).
- Jeu en cours : un **action-RPG sombre** (titre de travail *Givrecendre*).
  **Lire [`rpg/CONCEPTION.md`](rpg/CONCEPTION.md) avant toute tâche sur le
  RPG** et le mettre à jour quand une décision change. Univers et noms
  100 % originaux : on s'inspire du genre souls-like, on ne copie aucun jeu.
- Map de test précédente : `maps/iles-celestes.lua` (place 116414227319701).
- Noyau commun réutilisable (`src/`) : sauvegarde avec verrou de session,
  achats, passes, récompense quotidienne, interface.
- Pipeline (`pipeline/`, voir [`pipeline/README.md`](pipeline/README.md)) :
  construction hors Studio, validateur, tests, publication et tests dans le
  vrai moteur via Open Cloud.

## Règles de travail

- **Tester avant de livrer** : `./pipeline/run.sh` (tests, lint selene,
  formatage stylua, validation des maps). Ne jamais désactiver un test pour
  avoir du vert.
- **Vrai moteur** : `python3 pipeline/opencloud.py publier <place> --brouillon`
  puis `python3 pipeline/opencloud.py tester` ; publier pour de vrai
  (`publier` sans `--brouillon`) seulement si tout est vert **et** si le
  propriétaire l'a demandé.
- La clé API est dans la variable d'environnement `ROBLOX_API_KEY` : ne
  jamais l'écrire dans un fichier du dépôt, ni l'afficher.
- **Toujours dire la vérité** : ne rien affirmer sans l'avoir vérifié (doc
  officielle, test, mesure) ; dire « je ne peux pas confirmer » sinon ;
  citer les sources.
- Montrer chaque **modèle 3D** en image au propriétaire et attendre sa
  validation avant de l'intégrer.

## MCP de Roblox Studio (sur l'ordinateur du propriétaire)

Quand le MCP intégré à Roblox Studio est connecté :
- `screen_capture` pour **voir le vrai rendu** (montrer les captures au
  propriétaire) ;
- `start_stop_play`, `character_navigation`, `get_console_output` pour
  **tester en jouant** ;
- `generate_mesh` pour les **créatures** (ogre, hippogriffe, araignée) ;
  `insert_asset` / `search_asset` pour le Creator Store ;
- `execute_luau` pour agir dans la place ouverte. Les modifications faites
  dans Studio doivent aussi être reportées dans le dépôt (scripts dans `src/`
  ou `maps/`) pour rester reproductibles et testées.
- Prudence : ces outils modifient la place ouverte dans Studio. Sauvegarder
  la place avant les grosses opérations.
