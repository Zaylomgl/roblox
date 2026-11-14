# Tests dans le vrai moteur Roblox — tour-volcan

- Date : 2026-11-14T13:16:33+00:00
- Place : [116414227319701](https://www.roblox.com/games/116414227319701), version testée : 13
- Tâche Luau Execution : `universes/10774067194/places/116414227319701/versions/13/luau-execution-sessions/eb65baf3-b155-4b80-86d3-a3348d6da6f9/tasks/eb65baf3-b155-4b80-86d3-a3348d6da6f9` — état : **COMPLETE**
- **21 réussi(s), 0 échoué(s), 0 non vérifiable(s)** dans cet environnement

| | Groupe | Test | Détail |
|---|---|---|---|
| ✅ | Place | c'est la version qui vient d'être envoyée | place 116414227319701, version 13 |
| ✅ | Place | le jeu de la Fabrique est là, avec ses dossiers et son script | Tower Of Volcano — format tour, thème volcan, 10 étapes |
| ✅ | Place | contenu identique au fichier construit (comptages du validateur) | 2283 pièces, 49 gemmes, 122 lumières, 1 spawn |
| ✅ | Place | matériaux, tailles et attributs relus tels qu'ils ont été écrits | 10 matériaux différents, plus grande pièce : 1800 studs |
| ✅ | Place | ambiance du thème en place (atmosphère, nuages, étalonnage) | heure 18.4, technologie illisible ici |
| ✅ | Place | textes des arches lisibles (numéros d'étape sur les linteaux) | arches numérotées de 1 à 9 |
| ✅ | Géométrie | point d'apparition : sol réel juste dessous, au-dessus de la zone mortelle | sol « Ile » à Y = 40, zone mortelle à Y = -52 |
| ✅ | Géométrie | chaque borne d'étape est posée sur un vrai sol | 9 bornes, chacune sur un sol solide |
| ✅ | Géométrie | la zone d'arrivée est posée sur l'estrade | sol « Socle » |
| ✅ | Géométrie | chaque gemme a un sol réel à portée en dessous | 44 gemmes, la plus haute à 5.1 studs du sol |
| ✅ | Géométrie | chaque relique secrète a sa corniche juste dessous, sous le niveau du palier | 5 reliques, chacune sur sa corniche |
| ✅ | Géométrie | modèles : chaque gemme et chaque relique a ses facettes, la coupe est au sommet | 392 facettes taillées, 1 coupe |
| ✅ | Géométrie | les pièges mortels ne sont pas solides, les sols le sont | 21 pièges |
| ✅ | Moteur | PivotTo déplace un personnage entier sur une borne | racine et tête déplacées ensemble |
| ✅ | Moteur | GetPartsInPart voit une pièce qui recouvre une barre ou un piège | pièce témoin détectée dans « Barre » |
| ✅ | Moteur | un tapis ancré accepte une vitesse (AssemblyLinearVelocity) | vitesse 9 studs/s acceptée et relue |
| ✅ | Moteur | traînée des vainqueurs : Trail et ses deux attaches se créent sur un personnage | ok |
| ✅ | Moteur | Humanoid : mettre la vie à 0, et annonce dans un PlayerGui | ok |
| ✅ | Script de jeu | s'exécute jusqu'au bout sans erreur dans le vrai moteur | terminé en 0 s ; tapis mis en vitesse par le script |
| ✅ | Script de jeu | il a soudé chaque modèle à sa pièce maîtresse (facettes libérées, cœur ancré) | 418 pièces soudées |
| ✅ | Script de jeu | les animations tournent : la gemme bouge et ses facettes la suivent d'un bloc | 180 images en 3 s, la gemme a bougé de 0.2 studs, facette solidaire (dérive 0) |

## Mesures dans le vrai moteur

| Mesure | Valeur |
|---|---|
| collectibles | 49 |
| emetteursParticules | 104 |
| erreursJournal | 0 |
| imagesEn3s | 180 |
| lumieres | 122 |
| pieces | 2283 |
| piecesNonAncrees | 0 |
| placeVersion | 13 |
| plusGrandePiece | 1800 |
| sons | 58 |
| spawns | 1 |
| technologie | illisible ici |
| versionMoteur | 0.747.0.7471481 |

---
_Généré par `python3 pipeline/opencloud.py tester` (API Open Cloud « Luau Execution »). Dans cet environnement, d'après la documentation Roblox, la physique ne tourne pas et les scripts de la place ne démarrent pas d'eux-mêmes ; il n'y a pas de vrai joueur. Le parcours joueur complet reste couvert par les tests du moteur simulé (`pipeline/tests/integration.test.luau`, `pipeline/tests/fabrique.test.luau`)._
