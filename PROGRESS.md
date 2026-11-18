# Travail accompli

## 2026-11-14 — Version 3 : reprise après le premier essai en jeu
- Parcours : vides de 4,6 à 6,9 studs, modules sans marche, deux modules de sauts purs par étape, 12 étapes au maximum.
- Script de jeu : retour à la borne après une chute (sans mourir) ou une mort, dalles de verre qui préviennent 3 secondes, chronomètre et record, cinq reliques secrètes, traînée des vainqueurs, modèles soudés.
- Modèles : `K.pyramide`, `K.joyau`, `K.coupe`, `K.relique` dans `gabarits/kit.lua` ; plateformes à cadre et gradins.
- Lumière plafonnée ; générateur de hasard maison (même jeu dans Studio et dans le pipeline).
- Tests : 90 au total (45 pour la Fabrique) ; 21 tests dans le vrai moteur, réussis sur `evasion-prison` et `tour-volcan`.
- Aperçu : formes en coin dessinées, mode `details` (gros plans).
- Non vérifié : tout ce qui demande un joueur (sauts, sons, rendu des lumières, retour à la borne après une mort).

## 2026-11-14 — Tests dans le vrai moteur Roblox pour les jeux générés
- `pipeline/reel/tests-parcours.luau` : 17 tests exécutés par Open Cloud « Luau Execution » (fichier relu à l'identique, vrai sol sous chaque borne, PivotTo, GetPartsInPart, vitesse d'un tapis ancré, script de jeu exécuté sans erreur, animations).
- `python3 pipeline/opencloud.py tester --map <nom>` choisit ce script pour tout jeu présent dans `jeux/catalogue.json`.
- Résultats : `evasion-prison` 17/17 et `tour-volcan` 17/17 (rapports dans `reports/*-moteur-reel.md`).
- Non couvert : sauts, contacts réels, tapis qui entraîne le joueur (la physique ne tourne pas dans cet environnement).

## 2026-11-14 — Agent GitHub « Fabrique — nouveau jeu »
- `.github/workflows/fabrique.yml` : chaque lundi et à la demande ; photo des classements, création, validation, aperçu, pull request brouillon.
- Jamais exécuté sur GitHub à ce jour : un workflow planifié ou manuel ne démarre qu'une fois présent sur la branche par défaut. Ses étapes ont été essayées en local (`./fabrique/nouveau-jeu.sh`).

## 2026-11-14 — Tests automatiques de la Fabrique
- `pipeline/tests/fabrique.test.luau` : 36 tests (81 au total avec ceux d'avant, tous réussis).
- Les 12 combinaisons format × thème sont construites et validées ; parcours joueur complet dans le moteur simulé ; trois sabotages volontaires.
- Le moteur simulé gère désormais `CharacterAdded`, la réapparition et les points de vie.
- Un test échoue si un fichier `maps/<jeu>.lua` n'est plus ce que produisent les gabarits : régénérer après tout changement de gabarit.

## 2026-11-14 — Six jeux créés
- `evasion-prison`, `tour-volcan`, `evasion-neon`, `evasion-jungle`, `tour-glace`, `evasion-bonbon` : 10 étapes, 40 gemmes chacun, 0 erreur et 0 avertissement au validateur.
- Fiches dans `jeux/`, aperçus dans `jeux/apercus/`, rapports dans `reports/`.

## 2026-11-14 — Aperçu en images
- `fabrique/apercu/` : export de la place en JSON, rendu three.js dans Chromium, une planche de quatre vues par jeu.
- Rendu approximatif : ne remplace pas un coup d'œil dans Roblox Studio.

## 2026-11-13 — La Fabrique (générateur de jeux)
- `fabrique/creer.luau` : lit `recherche/rapport-niche.json`, classe les formats, choisit format et thème, écrit `maps/<nom>.lua`, `jeux/<nom>.md`, `jeux/catalogue.json`.
- Gabarits : `kit.lua` (outils, ambiance, décors par thème), `parcours.lua` (tracés tour/évasion, 10 obstacles, bornes, arrivée), `scenes.lua` (décor de chaque format), `jeu.server.lua` (règles du jeu).
- 6 thèmes dans `themes.luau`, 7 formats dans `formats.luau` dont 2 constructibles.
- `./fabrique/nouveau-jeu.sh` enchaîne création, pipeline et aperçu.

## Avant le 2026-11-13 — Version 1 (voir l'historique git)
- Map « Les Îles Célestes d'Aurora », script « L'Île d'Auraciel », noyau commun (`src/`), pipeline de construction et de validation, Open Cloud (boutique, publication, tests dans le vrai moteur), recherche de niche.
