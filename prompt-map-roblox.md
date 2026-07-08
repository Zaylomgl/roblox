# Prompt pour Fable 5 — Créer une map Roblox magnifique et rejouable

> **✦ Le résultat est déjà dans ce repo !** Le thème choisi est **« Les Îles Célestes
> d'Aurora »** : un archipel d'îles flottantes au lever de soleil doré, avec un Grand
> Cristal central, une forêt luminescente, des cascades qui tombent dans le vide, des
> ruines antiques et 2 zones secrètes. Le script complet prêt à coller dans Roblox
> Studio est dans [`map-iles-celestes.lua`](map-iles-celestes.lua) — le mode d'emploi
> est en tête du fichier.

## Comment l'utiliser

1. Copie le prompt ci-dessous et colle-le dans une conversation avec Fable 5 (Claude).
2. Remplace `[TON THÈME]` par le thème de ton choix (ex : île flottante fantasy, ville cyberpunk sous la pluie, village médiéval en automne, station spatiale abandonnée…).
3. Fable 5 te rendra un script Luau complet : ouvre Roblox Studio, affiche la barre de commande (View → Command Bar), colle le script et appuie sur Entrée. La map se construit toute seule.

## Le prompt

```text
Tu es un level designer senior et un développeur Roblox expert en Luau, spécialisé
dans les maps qui font dire "waouh" dès le spawn et qui donnent envie de revenir jouer.

MISSION
Crée-moi une map Roblox complète et magnifique sur le thème : [TON THÈME].
Livre-la sous la forme d'UN SEUL script Luau que je collerai dans la barre de
commande de Roblox Studio et qui construira toute la map automatiquement.

DIRECTION ARTISTIQUE (priorité n°1 : la beauté)
- Lighting travaillé : Atmosphere (brume légère), Bloom, ColorCorrection,
  SunRays, ambiance "golden hour" ou nuit lumineuse selon le thème.
- Palette cohérente : 3 à 4 couleurs dominantes maximum, pas d'arc-en-ciel.
- Un landmark central spectaculaire, visible depuis presque partout sur la map
  (tour, arbre géant, cristal, statue… adapté au thème).
- Terrain sculpté avec du relief : collines, falaises, eau, éventuellement grottes.
- Détails vivants : végétation, rochers, lanternes/lampadaires, particules
  (lucioles, brume au sol, étincelles), sons d'ambiance.

LEVEL DESIGN & REJOUABILITÉ (priorité n°2 : donner envie de revenir)
- Le spawn doit offrir la plus belle vue de la map : première impression décisive.
- 4 à 5 zones distinctes, chacune avec une identité visuelle et une ambiance propre.
- Chemins multiples entre les zones, raccourcis, et au moins 2 zones secrètes
  cachées à découvrir.
- De la verticalité : plateformes, points de vue en hauteur, sauts intéressants.
- Des collectibles (pièces ou objets liés au thème) qui tournent sur eux-mêmes,
  avec son + effet de particules à la collecte, et qui réapparaissent après un délai.
- Un leaderboard (leaderstats) qui compte les collectibles : la boucle de jeu
  de base qui donne envie de tout explorer.

CONTRAINTES TECHNIQUES
- Un seul script Luau, exécutable tel quel dans la barre de commande de Studio.
- Une table CONFIG en haut du script pour régler facilement : taille de la map,
  nombre de collectibles, couleurs de la palette, heure du jour, densité de décor.
- Toutes les instances rangées proprement dans des dossiers
  (workspace.Map > Zones, Decor, Collectibles, Lighting…).
- Toutes les parts en Anchored = true, pas de physique inutile.
- Performance : reste raisonnable sur le nombre de parts (map fluide sur mobile),
  pas de boucles qui tournent en permanence pour rien.
- N'utilise AUCUN asset payant ni ID d'asset externe douteux : uniquement des
  parts, du terrain, des lumières, des particules et des sons du catalogue Roblox
  officiel (ou pas de son si tu n'es pas sûr de l'ID).

LIVRABLE
1. Le script Luau complet, commenté par sections.
2. Un mode d'emploi en 5 lignes maximum.
3. 3 suggestions concrètes pour améliorer la map ensuite (gameplay, événements,
   récompenses quotidiennes…).

Avant d'écrire le code, décris-moi en quelques lignes ta vision de la map
(les zones, le landmark, l'ambiance) pour que je valide la direction.
```

## Conseils pour un meilleur résultat

- **Sois précis sur le thème** : « île flottante fantasy au coucher du soleil avec des cascades qui tombent dans le vide » donnera un bien meilleur résultat que « une belle map ».
- **Itère** : une fois la map générée, redemande des ajustements ciblés (« ajoute plus de brume », « rends la zone nord plus sombre et inquiétante », « double les collectibles »).
- **Demande des variantes** : « propose-moi 3 ambiances de lighting différentes pour cette map » et choisis ta préférée.
- **Pour aller plus loin** : demande ensuite un système de quêtes, un cycle jour/nuit, ou des événements aléatoires (pluie de météores, coffre rare qui apparaît…) — ce sont ces mécaniques qui font vraiment revenir les joueurs.
