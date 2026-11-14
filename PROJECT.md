# Roblox — la Fabrique de jeux

## Quoi
Un outil, « la Fabrique », qui crée des jeux Roblox complets à partir des
tendances des classements Roblox : il choisit un format de jeu qui monte et un
thème, écrit la map et le script de jeu, puis fait construire, tester et valider
le tout par le pipeline du dépôt. Les jeux créés ne sont pas tous les mêmes :
format, thème et graine changent le tracé, les obstacles et le décor.

## Pour qui / pourquoi
Pour le propriétaire du dépôt, qui veut publier des jeux Roblox qui attirent le
plus de joueurs possible : agréables à regarder, détaillés, où tout fonctionne.
Aucun chiffre du projet ne garantit des joueurs ; les tendances servent à
choisir, pas à promettre.

## Périmètre V2 (livré)
- La Fabrique : choix d'après les tendances, 2 formats constructibles (tour à grimper, évasion), 6 thèmes, 10 obstacles, étapes sauvegardées, gemmes, victoires
- 6 jeux créés (un par thème), validés par le pipeline ; 2 testés dans le vrai moteur Roblox
- Une commande pour créer un jeu de bout en bout (`./fabrique/nouveau-jeu.sh`)
- Aperçu en images de chaque jeu (rendu approximatif, hors Roblox)
- Tests automatiques : jeux générés, parcours joueur, vrai moteur (Open Cloud)
- Workflow GitHub hebdomadaire qui crée un jeu et ouvre une pull request
- Hérité de la V1 : map « Les Îles Célestes d'Aurora », noyau commun (sauvegarde, récompense quotidienne, achats, boutique), pipeline, recherche de niche

## Hors périmètre (V3 ou plus tard)
- Formats repérés dans les tendances mais pas encore constructibles : ragdoll, vol entre bases, œufs/collection, +1/évolution, construction
- Publication automatique sur Roblox, et une expérience Roblox par jeu (aujourd'hui une seule expérience est configurée)
- Badges, produit « passer l'étape », icônes et miniatures des pages Roblox
- Interface en anglais (aujourd'hui en français ; titres et descriptions en anglais)
- « L'Île d'Auraciel » dans le pipeline (script autonome)
- RPG Givrecendre (pull request séparée, non fusionnée)

## Look & feel
Mondes flottants très lisibles, une identité forte par thème (volcan, glace,
jungle, bonbon, néon, prison) : cinq familles de couleurs au plus, matériaux
texturés de Roblox, lumières d'accent, un grand repère visible de partout
(tour couronnée de cristaux, porte de sortie monumentale).

## Stack / outils
Luau, Lune 0.11.1, selene, StyLua (avec la syntaxe Luau), Python (Open Cloud,
recherche de niche), Node.js + three.js + Playwright (aperçu), GitHub Actions.
Tous gratuits.

## Où ça vit
Racine du dépôt : `PROJECT.md`, `DECISIONS.md`, `PROGRESS.md`, `CLAUDE.md`,
et `BESOINS.md` (le seul document qui liste ce que le projet attend du propriétaire).
