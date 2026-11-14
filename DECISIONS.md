# Journal des décisions

## 2026-11-14 — Rejouabilité : record, reliques secrètes, traînée des vainqueurs
Retour du propriétaire : « en 20 minutes c'est fait, il faudrait que les gens reviennent, des easter eggs ». Chaque jeu reçoit un chronomètre avec record sauvegardé, cinq reliques cachées sous des paliers (comptées une fois par joueur, pour toujours) et une traînée derrière le joueur selon ses victoires. Idée écartée pour l'instant : une boutique de cosmétiques payés en gemmes (demande une interface côté client).

## 2026-11-14 — Une chute ramène à la dernière borne, sans mourir
Retour du propriétaire : après une chute il se retrouvait au début, pas au checkpoint. Quatre fois par seconde, tout joueur tombé sous sa dernière borne y est ramené ; cela couvre aussi une apparition hors de la map. Après une mort, le personnage est remis sur sa borne pendant trois secondes, car Roblox le repose au point de départ un peu après sa création (comportement non vérifié dans le vrai moteur : il faut un joueur).

## 2026-11-14 — De vrais sauts, moins de dalles
Retour du propriétaire : « des cases de partout, on pourrait presque tout faire en marchant ». Les vides passent de 3,4–6,5 à 4,6–6,9 studs, les dalles rétrécissent, et les deux modules qui se traversaient en marchant (poutre avec paliers, zigzag jointif) demandent maintenant de sauter.

## 2026-11-14 — La netteté passe avant l'effet lumineux
Retour du propriétaire : « trop de lumière, ça fait un flou, on ne voit rien ». Brume, éblouissement et halo sont plafonnés pour tous les thèmes, les lumières ponctuelles sont deux fois moins fortes, les rayons de soleil sont retirés, et le dessous néon des plateformes du volcan devient de la lave craquelée. Rendu non vérifié par moi : à confirmer en jeu.

## 2026-11-14 — Modèles à facettes, soudés à une pièce invisible
Retour du propriétaire : gemmes et coupe n'étaient « que des cubes jaunes ». Les gemmes sont maintenant taillées (huit pièces en coin), la coupe a un pied, une vasque et des anses. Chaque modèle est soudé par le script de jeu à une pièce invisible, seule à être animée : vérifié dans le vrai moteur (les facettes suivent, dérive nulle).

## 2026-11-14 — Sons : discrets en attendant mieux
Retour du propriétaire : « le bruit est horrible ». Faute de pouvoir écouter, le son d'origine est gardé mais beaucoup plus bas et plus aigu (donc plus bref). Un vrai choix de son reste à faire par le propriétaire (voir BESOINS.md).

## 2026-11-14 — Le hasard du jeu ne dépend plus du Random de Roblox
**Ce qu'on pensait** : hors de Roblox, seuls des détails de décor différaient (position d'une fleur).
**Pourquoi on a tourné** : mesuré dans le vrai moteur, le même script donnait 133 plateformes et 2668 pièces dans Roblox contre 141 et 2724 dans le pipeline. Le propriétaire jouait donc un parcours qui n'était pas celui validé.
**Ce qui a changé** : le script embarque son propre générateur. Vérifié dans le vrai moteur : 2997 pièces des deux côtés pour l'évasion, 2283 pour la tour.

## 2026-11-14 — 12 étapes au maximum (au lieu de 14)
Les modèles plus détaillés coûtent des pièces. Mesuré : le format « evasion » atteint 3582 pièces à 12 étapes et 4171 à 14, au-dessus du seuil de 4000 du validateur.

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
