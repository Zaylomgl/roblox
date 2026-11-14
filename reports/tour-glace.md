# Rapport de validation — tour-glace

**Statut : ✅ OK** — 0 erreur(s), 0 avertissement(s), 3 info(s).

## Chiffres clés

| Mesure | Valeur |
|---|---|
| Pièces | 2358 (dont 0 non ancrées) |
| Lumières (dont avec ombres) | 119 (0) |
| Particules / s | 6 |
| Scripts | 9 |
| Spawns | 1 |
| Pads de saut | 0 |
| Collectibles accessibles | 49 / 49 |
| Surfaces atteintes depuis le spawn | 188 / 192 |
| Déplacements pour atteindre un collectible (médiane / max) | 65 / 118 |
| Saut théorique (hauteur / portée à plat) | 6.37 / 8.15 studs |
| Sauvegarde (DataStore) / Monétisation (Marketplace) / Badges | oui / oui / non |

## Problèmes

- ℹ️ **[Ambiance] EFFET_ABSENT** — Pas de SunRaysEffect dans Lighting.
- ℹ️ **[Accessibilité] GRANDES_SURFACES_NON_ATTEINTES** — 2 grande(s) surface(s) (≥100 studs²) jamais atteintes depuis le spawn. Décor normal, ou zone coupée du reste : à vérifier. Les 10 plus grandes :
  - `Workspace.Parcours.Decor.Tour (≈1600 studs², Y=218)`
  - `Workspace.Parcours.Decor.Linteau (≈314 studs², Y=214.7)`
- ℹ️ **[Rétention] PAS_DE_BADGES** — Aucun badge : les badges donnent des objectifs à long terme aux joueurs.

---
_Rapport généré automatiquement par `pipeline/validate.luau`. L'accessibilité est une estimation géométrique (voir pipeline/README.md) : un « inaccessible » doit être confirmé en jeu._
