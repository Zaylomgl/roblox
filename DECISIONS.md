# Journal des décisions

## 2026-11-14 — Tests dans le vrai moteur sur le brouillon de la place existante
Une seule expérience Roblox est configurée. Pour tester deux jeux générés dans le vrai moteur, ils ont été envoyés en version « Saved » (brouillon, invisible des joueurs) sur la place des Îles Célestes (versions 9 et 10), puis Les Îles Célestes ont été remises en brouillon (version 11, re-testée : 33 réussis, 2 non vérifiables, comme avant). Une place de test dédiée éviterait ce va-et-vient (voir BESOINS.md).

## 2026-11-14 — 14 étapes au maximum par jeu
Mesuré : le format « evasion » atteint 3598 pièces à 14 étapes et 4070 à 16, au-dessus du seuil d'avertissement du validateur (4000). `fabrique/creer` borne donc le nombre d'étapes à 14.

## 2026-11-14 — StyLua compilé avec la syntaxe Luau, en CI comme en local
**Ce qu'on pensait** : la CI vérifiait le formatage de tout `pipeline/` et `src/`.
**Pourquoi on a tourné** : StyLua installé sans `--features luau` plante sur les chaînes entre accents graves et ignore le fichier en silence ; huit fichiers n'étaient jamais vérifiés.
**Ce qui a changé** : installation avec `--features luau`, garde-fou dans `pipeline/run.sh`, les huit fichiers reformatés.

## 2026-11-14 — Un thème ne revient que lorsque tous ont servi
Le premier réglage reprenait « prison » pour deux jeux de suite, parce que c'est le seul thème dont le nom figure dans les tendances. La variété passe avant : les six premiers jeux ont six thèmes différents.

## 2026-11-14 — Les barres tournantes détectent elles-mêmes les joueurs
Par précaution, les barres mortelles interrogent `GetPartsInPart` dix fois par seconde au lieu de compter seulement sur `Touched`, car une pièce ancrée déplacée par script peut ne pas déclencher `Touched` sur un personnage immobile (non vérifié en jeu : la physique ne tourne pas dans l'environnement de test).

## 2026-11-13 — Le chemin obligatoire n'utilise que des plateformes fixes
Les pièges (barres, braises, tapis, dalles fragiles) ne font qu'ajouter du danger. Le validateur, qui ne voit que la géométrie fixe, prouve ainsi que chaque étape est franchissable. Idée écartée pour cette raison : les pads de saut obligatoires, dont le comportement réel n'a jamais été vérifié en jeu.

## 2026-11-13 — Deux formats d'abord : tour à grimper et évasion
Ce sont les deux formats présents dans les tendances (« escape » 14, « prison » 9, « run » 9, « tower » 15, « obby » 6 jeux en ascension, 21 relevés du 31/10 au 13/11) que le pipeline sait prouver jouables. Limite connue, d'après les mêmes relevés : le genre « Obby & Platformer » a la plus faible médiane de votes positifs (80 %) et peu de jeux parmi les plus revisités (8), loin derrière « Simulation » (41 % des joueurs relevés). Les autres formats restent listés comme non constructibles.

## 2026-11-13 — Jeux construits en pièces, sans Terrain voxel
Le Terrain ne peut pas être rempli hors de Roblox et complique la validation. Les jeux de la Fabrique n'utilisent que des pièces et des matériaux intégrés ; le Terrain reste propre aux Îles Célestes.

## 2026-11-13 — Titres en anglais, interface en français
Les mots qui montent dans les classements sont anglais : les titres et descriptions proposés le sont aussi. L'interface du noyau commun reste en français pour l'instant (traduction hors périmètre V2).

## 2026-11-13 — Les photos de classements de la PR 5 sont fusionnées dans cette branche
Les tendances reposent ainsi sur 21 relevés (du 31/10 au 13/11) au lieu de 3.

## 2026-11-13 — Le projet devient une fabrique de jeux
**Ce qu'on pensait** : améliorer les maps existantes (badges, Île d'Auraciel dans le pipeline, quêtes).
**Pourquoi on a tourné** : le propriétaire veut un outil qui crée des jeux variés à partir des tendances, pour viser le plus de joueurs possible, et confie la direction du projet à Claude.
**Ce qui a changé** : nouveau dossier `fabrique/`, nouveau périmètre dans PROJECT.md ; les pistes précédentes passent hors périmètre.

## 2026-11-13 — Projet démarré
Périmètre et direction initiaux enregistrés dans PROJECT.md.
