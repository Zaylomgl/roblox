# Rapport de validation — evasion-prison

**Statut : ✅ OK** — 0 erreur(s), 0 avertissement(s), 2 info(s).

## Chiffres clés

| Mesure | Valeur |
|---|---|
| Pièces | 1687 (dont 0 non ancrées) |
| Lumières (dont avec ombres) | 133 (0) |
| Particules / s | 9 |
| Scripts | 9 |
| Spawns | 1 |
| Pads de saut | 0 |
| Collectibles accessibles | 40 / 40 |
| Surfaces atteintes depuis le spawn | 148 / 186 |
| Déplacements pour atteindre un collectible (médiane / max) | 50 / 94 |
| Saut théorique (hauteur / portée à plat) | 6.37 / 8.15 studs |
| Sauvegarde (DataStore) / Monétisation (Marketplace) / Badges | oui / oui / non |

## Problèmes

- ℹ️ **[Accessibilité] GRANDES_SURFACES_NON_ATTEINTES** — 1 grande(s) surface(s) (≥100 studs²) jamais atteintes depuis le spawn. Décor normal, ou zone coupée du reste : à vérifier. Les 10 plus grandes :
  - `Workspace.Parcours.Decor.Linteau (≈173 studs², Y=50.1)`
- ℹ️ **[Rétention] PAS_DE_BADGES** — Aucun badge : les badges donnent des objectifs à long terme aux joueurs.

---
_Rapport généré automatiquement par `pipeline/validate.luau`. L'accessibilité est une estimation géométrique (voir pipeline/README.md) : un « inaccessible » doit être confirmé en jeu._
