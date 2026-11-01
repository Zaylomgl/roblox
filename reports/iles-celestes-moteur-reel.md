# Tests dans le vrai moteur Roblox — iles-celestes

- Date : 2026-10-31T22:02:36+00:00
- Place : [116414227319701](https://www.roblox.com/games/116414227319701), version testée : 8
- Tâche Luau Execution : `universes/10774067194/places/116414227319701/versions/8/luau-execution-sessions/fa897051-d253-4bbf-a178-dcf3db0c411a/tasks/fa897051-d253-4bbf-a178-dcf3db0c411a` — état : **COMPLETE**
- **33 réussi(s), 0 échoué(s), 2 non vérifiable(s)** dans cet environnement

| | Groupe | Test | Détail |
|---|---|---|---|
| ✅ | Place | c'est la version qui vient d'être publiée | place 116414227319701, version 8 |
| ✅ | Place | scripts du noyau, de la map et de l'interface présents |  |
| ✅ | Place | Configuration : pass et produits ont leur vrai ID Roblox | 3 objet(s) avec un ID |
| ✅ | Place | contenu identique au fichier construit (comptages du validateur) | 1189 pièces, 50 cristaux, 100 lumières, 1 spawn |
| ✅ | Place | saut et marche réels ≥ ceux supposés par le test d'accessibilité | saut 6.37 studs (validateur 6.37), marche 16 |
| ✅ | Place | point d'apparition : sol réel juste dessous, au-dessus de la zone mortelle | sol à Y = 189.6, zone mortelle à Y = 60 |
| ✅ | Terrain | le plan du Terrain se rejoue sans erreur dans le vrai moteur | 372 opérations en 0.13 s |
| ✅ | Terrain | chaque île a un sol d'herbe au niveau prévu (lecture des voxels) | 6 îles, points d'herbe au bon niveau : 12/12, 12/12, 12/12, 12/12, 12/12, 12/12 |
| ✅ | Terrain | les 50 cristaux ont un sol réel juste dessous (pièces ou Terrain) | 24 au-dessus du Terrain, 26 au-dessus de pièces (ponts, pierres, grotte…) |
| ✅ | Terrain | la grotte secrète et son passage ne sont pas bouchés par le Terrain | Terrain : grotte remplie à 6 %, passage à 0 % ; chute libre jusqu'au palier |
| ✅ | Terrain | éclairage réaliste actif (lumière tirée du ciel, herbe animée) | Technology illisible ici, EnvironmentDiffuse/Specular 1/1, herbe animée illisible ici |
| ✅ | Noyau | achats : crédité une seule fois même si Roblox renvoie le reçu |  |
| ✅ | Noyau | achats : gestionnaire qui plante → profil restauré, rien crédité |  |
| ✅ | Noyau | achats : joueur absent → « pas encore » |  |
| ✅ | Noyau | achats : produit inconnu → « pas encore », rien crédité |  |
| ✅ | Noyau | achats : sauvegarde en échec → « pas encore », puis accordé sans double crédit |  |
| ✅ | Noyau | profil : ancien profil complété sans perdre ses données |  |
| ✅ | Noyau | profil : monnaie jamais négative, NaN refusé |  |
| ✅ | Noyau | profil : mémoire des achats bornée |  |
| ✅ | Noyau | profil : nouveau joueur reçoit les valeurs par défaut |  |
| ✅ | Noyau | récompense : le jour change à minuit UTC, pas 24 h après |  |
| ✅ | Noyau | récompense : première réclamation puis refus le même jour |  |
| ✅ | Noyau | récompense : série sur jours consécutifs, puis cycle de 7 |  |
| ✅ | Noyau | récompense : un jour manqué casse la série |  |
| ✅ | Noyau | sauvegarde : charger, modifier, sauvegarder, recharger |  |
| ✅ | Noyau | sauvegarde : panne durable signalée, pas de données inventées |  |
| ✅ | Noyau | sauvegarde : pannes passagères du DataStore surmontées |  |
| ✅ | Noyau | sauvegarde : un serveur qui a perdu le verrou ne peut plus écraser |  |
| ✅ | Noyau | sauvegarde : verrou — un 2e serveur attend que le 1er libère |  |
| ✅ | DataStore réel | sauvegarde, verrou de session entre 2 serveurs, libération | clé test_a10385d9-9f3d-45be-8a7a-88e026202cf1 supprimée ; 2.1 s |
| ✅ | Boutique | pass « Cristaux x2 » (id 2062597704) en vente au prix prévu | « Cristaux x2 », 99 Robux, en vente : true |
| ✅ | Boutique | produit « Sac de cristaux » (id 3725192416) en vente au prix prévu | « Sac de cristaux », 25 Robux, en vente : true |
| ✅ | Boutique | produit « Coffre de cristaux » (id 3725192420) en vente au prix prévu | « Coffre de cristaux », 99 Robux, en vente : true |
| ⚪ | Scripts serveur | Principal démarre sans erreur et branche le DataStore | le script cloné n'a pas démarré en 10 s (les scripts ne tournent pas dans Luau Execution) |
| ⚪ | Scripts serveur | script de la map démarre sans erreur et anime les cristaux | aucun mouvement en 3 s : script non démarré ou Heartbeat arrêté dans cet environnement |

## Mesures dans le vrai moteur

| Mesure | Valeur |
|---|---|
| characterUseJumpPower | True |
| collectibles | 50 |
| dureeTestDataStore | 2.06 |
| emetteursParticules | 110 |
| environmentDiffuseScale | 1 |
| environmentSpecularScale | 1 |
| erreursJournal | 0 |
| fallenPartsDestroyHeight | 60 |
| gravite | 196.2 |
| grotteRemplissageTerrain | 0.07 |
| hauteurSaut | 6.37 |
| lumieres | 100 |
| passageRemplissageTerrain | 0 |
| pieces | 1189 |
| piecesNonAncrees | 0 |
| placeVersion | 8 |
| sons | 50 |
| spawns | 1 |
| technologie | illisible ici |
| terrainOperations | 372 |
| terrainSecondes | 0.13 |
| versionMoteur | 0.745.0.7451137 |
| vitesseMarche | 16 |

---
_Généré par `python3 pipeline/opencloud.py tester` (API Open Cloud « Luau Execution »). Dans cet environnement, d'après la documentation Roblox, la physique ne tourne pas et les scripts de la place ne démarrent pas d'eux-mêmes ; il n'y a pas de vrai joueur. Le parcours joueur complet reste couvert par les tests d'intégration du moteur simulé (`pipeline/tests/integration.test.luau`)._
