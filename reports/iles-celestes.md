# Rapport de validation — iles-celestes

**Statut : ✅ OK** — 0 erreur(s), 2 avertissement(s), 1 info(s).

## Chiffres clés

| Mesure | Valeur |
|---|---|
| Pièces | 1047 (dont 0 non ancrées) |
| Lumières (dont avec ombres) | 100 (0) |
| Particules / s | 224 |
| Scripts | 1 |
| Spawns | 1 |
| Pads de saut | 5 |
| Collectibles accessibles | 50 / 50 |
| Surfaces atteintes depuis le spawn | 434 / 460 |
| Déplacements pour atteindre un collectible (médiane / max) | 17 / 24 |
| Saut théorique (hauteur / portée à plat) | 6.37 / 8.15 studs |
| Sauvegarde (DataStore) / Monétisation (Marketplace) / Badges | non / non / non |

## Problèmes

- ⚠️ **[Revenus] PAS_DE_MONETISATION** — Aucun script n'utilise MarketplaceService : aucun pass ni produit n'est vendu, le jeu ne peut pas rapporter de Robux par achats.
- ⚠️ **[Rétention] PAS_DE_SAUVEGARDE** — Aucun script n'utilise DataStoreService : la progression des joueurs est perdue à chaque départ, ce qui retire une grosse raison de revenir.
- ℹ️ **[Rétention] PAS_DE_BADGES** — Aucun badge : les badges donnent des objectifs à long terme aux joueurs.

---
_Rapport généré automatiquement par `pipeline/validate.luau`. L'accessibilité est une estimation géométrique (voir pipeline/README.md) : un « inaccessible » doit être confirmé en jeu._
