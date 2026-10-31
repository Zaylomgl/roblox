# Pipeline de maps Roblox : construire → tester → corriger

Ce dossier contient la chaîne automatique qui **construit** les maps hors de
Roblox Studio (sous Linux), les **teste**, puis produit un **rapport** qui dit
quoi corriger. Elle tourne en local (`./pipeline/run.sh`) et sur GitHub à chaque
push (`.github/workflows/pipeline.yml`).

## Ce qui est vérifié automatiquement

| Catégorie | Vérification | Gravité |
|---|---|---|
| Scripts | Erreurs de syntaxe dans les scripts embarqués (compilation Luau) | erreur |
| Scripts | Lint selene : variables inutilisées, globales inconnues, code mort… | bloque la CI |
| Spawn | Présence d'un SpawnLocation, ancré, au-dessus de la zone mortelle | erreur |
| Accessibilité | Chaque collectible est-il atteignable depuis le spawn ? (graphe de sauts) | erreur |
| Accessibilité | Grandes surfaces jamais atteintes (zone coupée du reste ?) | info |
| Rétention | Sauvegarde de progression (DataStoreService), badges, nombre de collectibles | avertissement / info |
| Revenus | Monétisation présente (MarketplaceService) | avertissement |
| Performance | Nombre de pièces, lumières avec ombres, particules/s, pièces non ancrées | avertissement |
| Assets | Références `rbxassetid://` à vérifier à la main (impossible hors ligne) | info |
| Ambiance | Atmosphere, Sky, Bloom, ColorCorrection, SunRays | info |

Le validateur lui-même est testé (`pipeline/tests/`) sur des places artificielles
dont on connaît la réponse : saut faisable, vide trop large, marche trop haute,
rampe, pad de saut, zone mortelle, etc.

## Tests du jeu (`lune run pipeline/test`)

| Fichier | Ce qui est testé |
|---|---|
| `tests/analyse.test.luau` | Le validateur de maps, sur des places artificielles |
| `tests/noyau.test.luau` | Les modules purs du noyau (`src/ServerScriptService/Noyau`) : profil, récompense quotidienne (jours UTC, séries), achats (jamais de double crédit, jamais de perte), sauvegarde (verrou de session, pannes du DataStore) |
| `tests/integration.test.luau` | Les **vrais scripts** du jeu (serveur, interface, map) exécutés dans un **moteur Roblox simulé** (`lib/moteur.luau`) avec des joueurs simulés : arrivée, interface, récompense le lendemain, achats, pass x2, collecte de cristaux, départ/retour, panne du DataStore, fermeture du serveur |

Le moteur simulé utilise les vraies instances Roblox de Lune : un nom de
propriété mal écrit ou une valeur du mauvais type fait échouer le test, comme
dans Roblox. Il ajoute les événements, les services (DataStore, Marketplace,
Players…), un ordonnanceur de tâches et une horloge virtuelle. Il ne simule
**ni la physique, ni le rendu, ni le réseau** : les tests dans le vrai moteur
passent par l'API Open Cloud « Luau Execution » (section suivante).

Chaque série de tests a été vérifiée en sabotant volontairement le code
(double crédit, verrou non libéré, faute de frappe dans une propriété…) : les
tests échouent bien.

## Roblox Open Cloud : boutique, publication, tests dans le vrai moteur

`pipeline/opencloud.py` (Python, bibliothèque standard). La clé API est lue dans
la variable d'environnement `ROBLOX_API_KEY` et n'est jamais écrite dans le
repo ; les identifiants de l'expérience sont dans `pipeline/experience.json`.

| Commande | Effet |
|---|---|
| `python3 pipeline/opencloud.py cle` | Vérifie la clé (active, non expirée) et ses 4 droits : `game-pass`, `developer-product`, `universe-places`, `universe.place.luau-execution-session` |
| `python3 pipeline/opencloud.py boutique` | Crée sur Roblox chaque pass/produit de `Configuration.luau` dont l'`id` vaut 0 (nom, description, `prix`, mis en vente) et écrit son ID dans `Configuration.luau`. Relançable : un objet du même nom déjà sur Roblox est réutilisé, jamais dupliqué |
| `python3 pipeline/opencloud.py publier build/iles-celestes.rbxl` | Publie la place (version « Published », **visible des joueurs**) et note le numéro de version dans `build/derniere-publication.json` |
| `python3 pipeline/opencloud.py tester` | Lance `pipeline/reel/tests.luau` dans le vrai moteur sur la version publiée, affiche le journal du serveur Roblox, écrit `reports/<map>-moteur-reel.md` et `.json`. Code de sortie 1 si un test échoue |

Ordre habituel : `boutique` → `./pipeline/run.sh` → `publier` → `tester`.

**Ce qui est testé dans le vrai moteur** (dernier rapport :
[`reports/iles-celestes-moteur-reel.md`](../reports/iles-celestes-moteur-reel.md)) :

- la version chargée est bien celle qui vient d'être publiée ;
- le contenu chargé par Roblox est identique au fichier construit (mêmes
  comptages que le validateur : pièces, lumières, cristaux, spawn…) ;
- le saut et la marche réels de la place sont au moins ceux supposés par le
  test d'accessibilité, et un vrai lancer de rayon trouve le sol sous le spawn ;
- les 18 tests du noyau (`tests/noyau.test.luau`), rejoués tels quels dans le
  vrai interpréteur Luau sur les modules de la place publiée ;
- le module `Sauvegarde` sur un **vrai DataStore** (verrou de session entre deux
  « serveurs », libération, refus d'écraser). Il utilise un DataStore séparé,
  `Tests_Pipeline`, et supprime sa clé de test à la fin ;
- la boutique : chaque ID de `Configuration.luau` est un vrai objet Roblox, en
  vente, au prix prévu (`MarketplaceService:GetProductInfo`).

**Limites de cet environnement** (documentation officielle :
<https://create.roblox.com/docs/cloud/reference/features/luau-execution.md>) :
la physique ne tourne pas, les scripts de la place ne démarrent pas d'eux-mêmes
et il n'y a pas de vrai joueur. Les deux tests qui tentent de démarrer
`Principal` et le script de la map sont donc marqués « non vérifiables », pas
« réussis ». Le parcours joueur complet reste couvert par
`tests/integration.test.luau` (moteur simulé).

## Noyau commun (`src/`)

Injecté dans chaque place au moment du build (`--src src`), à la manière de Rojo :
`src/<Service>/…`, `nom.server.luau` → Script, `nom.client.luau` → LocalScript,
`nom.luau` → ModuleScript.

- `Principal.server.luau` : chargement/sauvegarde des profils, leaderstats,
  récompense quotidienne, achats (ProcessReceipt, Game Passes).
- `Noyau/API.luau` : ce qu'un script de map peut appeler (`ajouterMonnaie`,
  `depenserMonnaie`, `donneesJeu`, `possedePass`).
- `ReplicatedStorage/Partage/Configuration.luau` : monnaie, récompenses,
  passes et produits (vrais IDs Roblox, écrits par `opencloud.py boutique` ;
  un objet à 0 n'est ni affiché ni vendable).
- `StarterPlayerScripts/Interface.client.luau` : compteur, récompense du jour,
  boutique.

## Installation

Il faut [Rust/cargo](https://rustup.rs), puis :

```bash
cargo install --locked lune@0.11.1 selene@0.31.0 stylua@2.6.0
```

## Utilisation

Tout lancer (tests + lint + construction + validation de toutes les maps) :

```bash
./pipeline/run.sh
```

Une seule map :

```bash
./pipeline/run.sh maps/iles-celestes.lua
```

Étapes séparées :

```bash
lune run pipeline/build maps/iles-celestes.lua
```

```bash
lune run pipeline/validate build/iles-celestes.rbxl
```

Résultats :
- `build/<map>.rbxl` : la place, **ouvrable directement dans Roblox Studio** ;
- `reports/<map>.md` : le rapport lisible ; `reports/<map>.json` : le même pour les outils.

## Comment marche le test d'accessibilité

1. Chaque pièce solide (`CanCollide`) devient une « surface » : le rectangle de
   son dessus, vu d'en haut, à une certaine hauteur. Les coins (WedgePart) et
   pièces peu inclinées sont des rampes ; les boules et pièces très inclinées
   n'offrent qu'une petite zone au sommet.
2. On part du SpawnLocation et on explore toutes les surfaces atteignables par
   un saut, à pied ou en tombant (parcours en largeur).
3. Un saut est possible si la hauteur à monter et la distance à franchir
   tiennent dans la trajectoire balistique du personnage (vitesse initiale
   `JumpPower`, gravité, vitesse de marche), avec une marge de sécurité de 10 %.
4. Les pads de saut (attribut `Vitesse` ou `LaunchVelocity` de type Vector3)
   ajoutent des trajectoires de propulsion.
5. Un collectible est accessible s'il est à portée de main (debout ou en
   sautant) d'une surface atteinte.

**Valeurs physiques utilisées** (défauts Roblox, lus dans la base de réflexion
rbx-dom embarquée dans Lune 0.11.1, version Roblox 0.741) : `Gravity = 196.2`,
`CharacterWalkSpeed = 16`, `CharacterJumpPower = 50`,
`CharacterUseJumpPower = true`, `CharacterJumpHeight = 7.2`. D'où un saut
d'environ **6,37 studs de haut** et **8,15 studs de portée à plat**. Si la place
modifie `StarterPlayer` ou `Workspace.Gravity`, ce sont ses valeurs qui comptent.

### Limites connues (à garder en tête)

- **Approximation géométrique**, pas une simulation physique : les murs ne
  bloquent pas les trajectoires (on peut surestimer l'accès), les pièces sont
  réduites à leur boîte englobante. Un « inaccessible » doit être confirmé en jeu.
- Le **Terrain voxel** n'est pas analysé (seulement les pièces).
- `Random` est simulé par un générateur maison : les détails aléatoires
  (position exacte d'une fleur…) diffèrent de ceux de Roblox. La structure de
  la map, elle, est identique.
- Les seuils de performance sont des **choix internes prudents**, pas des
  règles Roblox : à recaler avec des mesures sur un vrai téléphone.
- **Aucun test automatique ne mesure le plaisir de jeu.** Seules les données de
  vrais joueurs (rétention J1/J7, durée de session) le font.

## Prochaines étapes prévues

1. **Recherche de niche** à partir des classements Roblox (`apis.roblox.com/explore-api`).
2. **Boucle de jeu propre à la niche choisie** (le noyau commun — sauvegarde,
   récompenses quotidiennes, boutique — est en place).
3. ~~Tests dans le vrai moteur et publication de la place~~ : fait
   (`pipeline/opencloud.py`, section « Roblox Open Cloud » ci-dessus).
4. **Boucle d'amélioration** : lire les statistiques réelles des joueurs,
   corriger, republier.
