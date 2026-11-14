# 🍭 Escape The Candy Run

Jeu créé par la Fabrique le 2026-11-14 — script de construction : [`maps/evasion-bonbon.lua`](../maps/evasion-bonbon.lua).

| | |
|---|---|
| Format | Évasion (parcours) — Un parcours d'obstacles pour s'échapper, de la cellule jusqu'à la sortie. |
| Thème | Bonbon |
| Étapes | 10 |
| Graine | 77 |
| Genre à choisir sur Roblox | Obby & Platformer |

## Pourquoi ce format

Tendances : 21 relevés des classements Roblox, du 2026-10-31 au 2026-11-13 (recherche/rapport-niche.md).

Nombre de jeux du classement « En pleine ascension » dont le nom contient chaque mot du format :

| Mot | Jeux en ascension |
|---|---|
| escape | 14 |
| prison | 9 |
| run | 9 |
| obby | 6 |

Un mot à 0 n'est pas dans les 25 mots les plus fréquents du rapport ; cela ne veut pas dire qu'aucun jeu ne le porte.

Genre « Obby & Platformer » sur la période : 80 jeux classés, 4 % des joueurs connectés relevés, 34 jeux en ascension, 8 parmi les plus revisités, 80 % de votes positifs (médiane).

## Ce que ces chiffres ne disent pas

Ils montrent ce qui monte dans les classements, pas ce qui marchera pour ce jeu : aucun de ces chiffres ne garantit des joueurs. Le rendu réel (lumières, matériaux) et le plaisir de jeu ne se vérifient que dans Roblox Studio, en jouant.

## Page Roblox (proposition)

- **Nom** : 🍭 Escape The Candy Run
- **Description** : Climb, jump and dodge your way through 10 stages of the Candy world. Your stage is saved: come back and finish later. Collect gems, reach the top and count your wins!

L'interface du jeu (boutique, récompense du jour) est en français ; le titre et la description sont en anglais, comme les noms relevés dans les classements.

## Construire, valider, tester

```bash
./pipeline/run.sh maps/evasion-bonbon.lua
```

Le rapport de validation est écrit dans `reports/evasion-bonbon.md`, la place dans `build/evasion-bonbon.rbxl` (ouvrable dans Roblox Studio).
