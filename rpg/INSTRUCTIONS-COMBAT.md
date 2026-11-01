# Instructions pour Claude (Desktop) + MCP Roblox Studio — Étape 2 : le combat

Tu es Claude, connecté à Roblox Studio par le MCP `Roblox_Studio`, avec la
place **Givrecendre** ouverte (place `85466448220573`). Suis les phases dans
l'ordre et **arrête-toi à chaque « ⏸ VALIDATION »**. Mêmes règles que
`INSTRUCTIONS-STUDIO.md` : français, vérité (capture ou test à l'appui), rien
publier sans accord, demander de sauvegarder avant les grosses modifications.

Le code du combat est écrit et testé dans le dépôt (`rpg/src/`, 68 tests hors
ligne). **Ne le réécris pas dans Studio** : installe-le avec l'installateur,
et signale les problèmes ; les corrections se font dans le dépôt.

## Phase 1 — Installer

1. Demande au propriétaire de **sauvegarder la place**.
2. Récupère la dernière version du dépôt (`git pull` dans le dossier du
   projet), puis lis `rpg/studio/installer-combat.lua` (fichier généré, ~68 Ko).
3. Exécute son contenu **en entier** avec `execute_luau` (mode Édition). S'il
   est trop long pour un seul appel, exécute d'abord la fonction `installer`
   (début du fichier), puis les appels `installer(...)` un par un, en recopiant
   la fonction à chaque fois.
4. Vérifie avec `execute_luau` que ces scripts existent :
   `ReplicatedStorage.Givrecendre.Regles`, `ReplicatedStorage.Givrecendre.IAOgre`,
   `ServerScriptService.Givrecendre.Combat`,
   `StarterPlayer.StarterPlayerScripts.Givrecendre.Combat`,
   `ServerScriptService.Principal`, `ServerScriptService.Noyau` (5 modules),
   `ReplicatedStorage.Partage.Configuration`.

## Phase 2 — Tester en jouant

1. `start_stop_play` pour lancer le jeu.
2. `get_console_output` : on doit voir `[Combat] Grimmulf est prêt` et
   **aucune erreur rouge**. Recopie toute erreur mot pour mot.
3. `character_navigation` : marche du spawn jusqu'au milieu de la cour
   (vers (0, 0, 0)). L'Ogre doit se tourner vers le personnage, avancer,
   puis attaquer : zone **rouge au sol** (télégraphe), puis le coup.
4. `screen_capture` : à l'entrée de la cour, pendant un télégraphe, et avec la
   barre de vie du boss visible en bas de l'écran.
5. Si tu peux envoyer des touches, essaie : clic gauche (coup), F (coup
   lourd), Q (roulade), R (fiole). Sinon, dis-le : le propriétaire testera
   lui-même.
6. `start_stop_play` pour arrêter.

⏸ **VALIDATION** : montre les captures et le journal de la console.

## Phase 3 — Compte rendu

- Ce qui marche, ce qui ne marche pas (avec les messages d'erreur exacts).
- Ressenti si le propriétaire a joué : Ogre trop fort / trop faible, attaques
  lisibles ou non, roulade utile ou non.
- Ne modifie pas les scripts installés : renvoie le compte rendu, Claude dans
  le cloud corrige le dépôt et régénère l'installateur.
