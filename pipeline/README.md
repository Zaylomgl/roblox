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
2. **Boucle de jeu complète** sur la map : sauvegarde, progression, récompenses
   quotidiennes, monétisation non agressive.
3. **Tests dans le vrai moteur** via l'API Open Cloud « Luau Execution », et
   **publication automatique** de la place (nécessite `ROBLOX_API_KEY`, voir
   `pipeline/experience.json` pour les identifiants de l'expérience).
4. **Boucle d'amélioration** : lire les statistiques réelles des joueurs,
   corriger, republier.
