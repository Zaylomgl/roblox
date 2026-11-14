# Tests dans le vrai moteur Roblox — evasion-prison

- Date : 2026-11-14T08:25:00+00:00
- Place : [116414227319701](https://www.roblox.com/games/116414227319701), version testée : 9
- Tâche Luau Execution : `universes/10774067194/places/116414227319701/versions/9/luau-execution-sessions/917c6e5d-1512-4225-943b-aec724430404/tasks/917c6e5d-1512-4225-943b-aec724430404` — état : **COMPLETE**
- **17 réussi(s), 0 échoué(s), 0 non vérifiable(s)** dans cet environnement

| | Groupe | Test | Détail |
|---|---|---|---|
| ✅ | Place | c'est la version qui vient d'être envoyée | place 116414227319701, version 9 |
| ✅ | Place | le jeu de la Fabrique est là, avec ses dossiers et son script | Escape The Prison Run — format evasion, thème prison, 10 étapes |
| ✅ | Place | contenu identique au fichier construit (comptages du validateur) | 2724 pièces, 40 gemmes, 128 lumières, 1 spawn |
| ✅ | Place | matériaux, tailles et attributs relus tels qu'ils ont été écrits | 11 matériaux différents, plus grande pièce : 946.9 studs |
| ✅ | Place | ambiance du thème en place (atmosphère, nuages, étalonnage) | heure 18.7, technologie illisible ici |
| ✅ | Place | textes des arches lisibles (numéros d'étape sur les linteaux) | arches numérotées de 1 à 9 |
| ✅ | Géométrie | point d'apparition : sol réel juste dessous, au-dessus de la zone mortelle | sol « Cour » à Y = 40, zone mortelle à Y = -20 |
| ✅ | Géométrie | chaque borne d'étape est posée sur un vrai sol | 9 bornes, chacune sur un sol solide |
| ✅ | Géométrie | la zone d'arrivée est posée sur l'estrade | sol « Socle » |
| ✅ | Géométrie | chaque gemme a un sol réel à portée en dessous | 40 gemmes, la plus haute à 5 studs du sol |
| ✅ | Géométrie | les pièges mortels ne sont pas solides, les sols le sont | 16 pièges |
| ✅ | Moteur | PivotTo déplace un personnage entier sur une borne | racine et tête déplacées ensemble |
| ✅ | Moteur | GetPartsInPart voit une pièce qui recouvre une barre ou un piège | pièce témoin détectée dans « Barre » |
| ✅ | Moteur | un tapis ancré accepte une vitesse (AssemblyLinearVelocity) | vitesse 6.2 studs/s acceptée et relue |
| ✅ | Moteur | Humanoid : mettre la vie à 0, et annonce dans un PlayerGui | ok |
| ✅ | Script de jeu | s'exécute jusqu'au bout sans erreur dans le vrai moteur | terminé en 0 s ; tapis mis en vitesse par le script |
| ✅ | Script de jeu | les animations tournent (barres, gemmes) sans erreur | 181 images en 3 s, la gemme a bougé de 0.24 studs |

## Mesures dans le vrai moteur

| Mesure | Valeur |
|---|---|
| collectibles | 40 |
| emetteursParticules | 56 |
| erreursJournal | 0 |
| imagesEn3s | 181 |
| lumieres | 128 |
| pieces | 2724 |
| piecesNonAncrees | 0 |
| placeVersion | 9 |
| plusGrandePiece | 946.9 |
| sons | 49 |
| spawns | 1 |
| technologie | illisible ici |
| versionMoteur | 0.747.0.7471481 |

---
_Généré par `python3 pipeline/opencloud.py tester` (API Open Cloud « Luau Execution »). Dans cet environnement, d'après la documentation Roblox, la physique ne tourne pas et les scripts de la place ne démarrent pas d'eux-mêmes ; il n'y a pas de vrai joueur. Le parcours joueur complet reste couvert par les tests du moteur simulé (`pipeline/tests/integration.test.luau`, `pipeline/tests/fabrique.test.luau`)._
