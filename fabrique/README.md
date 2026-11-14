# La Fabrique : des jeux Roblox créés à partir des tendances

La Fabrique lit les classements Roblox, choisit un **format de jeu** qui monte et
un **thème visuel**, puis écrit un jeu complet : map détaillée, obstacles,
étapes sauvegardées, gemmes, victoire. Chaque jeu est ensuite construit, testé
et validé par le pipeline du dépôt.

Deux jeux créés avec des réglages différents ne se ressemblent pas : le format,
le thème et la **graine** (un nombre) changent le tracé, l'ordre des obstacles
et le décor. La même graine redonne exactement le même jeu.

## Créer un jeu

Tout d'un coup (choix d'après les tendances, tests, validation, aperçu) :

```bash
./fabrique/nouveau-jeu.sh
```

Avec une nouvelle photo des classements Roblox juste avant :

```bash
./fabrique/nouveau-jeu.sh --photo
```

En imposant le format, le thème, la graine ou le nombre d'étapes (3 à 14) :

```bash
./fabrique/nouveau-jeu.sh --format tour --theme glace --graine 52 --etapes 12
```

Voir seulement ce qui monte, sans rien créer :

```bash
lune run fabrique/creer -- --tendances
```

Résultat, pour un jeu nommé `<nom>` :

| Fichier | Contenu |
|---|---|
| `maps/<nom>.lua` | Le jeu : script à coller dans la barre de commande de Roblox Studio, ou construit par le pipeline |
| `jeux/<nom>.md` | Fiche : pourquoi ce format (chiffres et source), titre et description proposés pour la page Roblox |
| `jeux/apercus/<nom>.jpg` | Planche de quatre vues (rendu approximatif, voir plus bas) |
| `reports/<nom>.md` | Rapport de validation |
| `build/<nom>.rbxl` | La place, ouvrable dans Roblox Studio (non versionnée) |
| `jeux/catalogue.json` | Liste des jeux déjà créés (sert à ne pas refaire les mêmes) |

Sur GitHub, le workflow **« Fabrique — nouveau jeu »** fait la même chose chaque
lundi et à la demande (onglet Actions → Run workflow), puis ouvre une pull
request à relire. Il ne publie rien sur Roblox.

## Comment le jeu est choisi

Source : `recherche/rapport-niche.json`, produit par `python3 recherche/niche.py`
à partir des classements officiels de la page Découvrir de Roblox.

1. **Format.** Chaque format du catalogue ([`formats.luau`](formats.luau)) a une
   liste de mots. Son score est le nombre de jeux du classement « En pleine
   ascension » dont le nom contient ces mots. Parmi les formats que la Fabrique
   sait construire, elle prend celui qui maximise `score / (1 + jeux déjà créés
   dans ce format)` : la tendance la plus forte d'abord, sans refaire dix fois
   le même format.
2. **Thème.** Un thème ne revient que lorsque tous ont servi. À choix égal,
   celui dont les mots sont présents dans les tendances passe devant, puis un
   tirage au sort reproductible (la graine).

Ce que ces chiffres ne disent pas : ils montrent ce qui monte dans les noms des
jeux classés, pas ce qui marchera pour un nouveau jeu. Le rapport ne garde que
les 25 mots les plus fréquents : un mot à 0 veut dire « pas dans les 25
premiers ». Aucun de ces chiffres ne garantit des joueurs.

Les formats repérés mais **pas encore constructibles** (ragdoll, vol entre
bases, œufs, +1/évolution, construction) restent affichés par `--tendances`,
pour montrer ce que la Fabrique ne sait pas encore faire.

## Ce qu'il y a dans un jeu

| Élément | Détail |
|---|---|
| Formats | `tour` : spirale autour d'une tour, île de départ, couronne lumineuse au sommet. `evasion` : chemin sinueux au-dessus du vide, cour fortifiée au départ, enceinte et massifs, porte de sortie |
| Thèmes | volcan, glace, jungle, bonbon, néon, prison ([`themes.luau`](themes.luau)) : palette, matériaux Roblox, ambiance, arbres, lampes et décor propres à chacun. Aucun asset externe |
| Obstacles | 10 modules : dalles, poutre, piliers, bosse, zigzag, barres tournantes, braises, dalles fragiles, tapis roulant, murets. La difficulté monte d'étape en étape |
| Progression | Bornes d'étape sauvegardées (on réapparaît à la dernière borne, même le lendemain), compteur de victoires, retour au départ après la victoire |
| Récompenses | Gemmes (1, 5, 25) créditées dans la monnaie du noyau commun ; +3 par borne, +50 par victoire |
| Sans le noyau | Le script collé seul dans Studio fonctionne aussi, sans sauvegarde |

**Règle de conception.** Le chemin obligatoire n'utilise que des plateformes
fixes ; les pièges ne font qu'ajouter du danger. Le validateur, qui ne voit que
la géométrie fixe, prouve donc que chaque étape est franchissable : le trophée
d'arrivée fait partie des objets à atteindre depuis l'unique point d'apparition.
Le plus grand vide à sauter fait 6,5 studs (le validateur en accepte ≈ 8,3).

## Ce qui est testé

| Où | Quoi |
|---|---|
| `pipeline/tests/fabrique.test.luau` (36 tests) | Choix d'après les tendances ; les 12 combinaisons format × thème construites et validées ; reproductibilité ; parcours joueur complet dans le moteur simulé (gemmes, bornes, mort, réapparition, victoire, sauvegarde, deux joueurs, sans noyau) ; pièges ; trois sabotages volontaires qui vérifient que les tests détectent bien une régression |
| `./pipeline/run.sh` | Lint, formatage, construction et validation de chaque jeu du dépôt |
| `pipeline/reel/tests-parcours.luau` (17 tests) | Dans le **vrai moteur Roblox** (Open Cloud) : fichier relu à l'identique, vrai sol sous chaque borne, fonctions du moteur utilisées par le jeu, script de jeu exécuté sans erreur, animations |

Derniers résultats dans le vrai moteur : [`reports/evasion-prison-moteur-reel.md`](../reports/evasion-prison-moteur-reel.md)
et [`reports/tour-volcan-moteur-reel.md`](../reports/tour-volcan-moteur-reel.md).

**Ce qui n'est PAS vérifié.** Dans l'environnement de test de Roblox, la
physique ne tourne pas et il n'y a pas de joueur : les sauts, les contacts
réels, le tapis roulant qui entraîne le personnage, la fluidité sur téléphone
et le plaisir de jeu ne peuvent être vérifiés qu'en jouant dans Roblox Studio.

## L'aperçu en images

`fabrique/apercu/` exporte la géométrie de la place et la dessine avec three.js
dans Chromium. C'est un **rendu approximatif** : formes, couleurs, proportions
et composition sont fidèles ; les matériaux, l'éclairage (lumières, bloom,
atmosphère, nuages, nuit) et les particules de Roblox ne le sont pas. Il sert à
repérer un décor vide ou raté, pas à juger le rendu final.

```bash
./fabrique/apercu/apercu.sh <nom>
```

Il demande Node.js et Playwright (`npm install --no-save playwright` puis
`npx playwright install chromium` dans `fabrique/apercu/`).

## Modifier la Fabrique

| Pour… | Modifier |
|---|---|
| Ajouter ou retoucher un thème | [`themes.luau`](themes.luau) (et, pour un nouvel arbre ou une nouvelle lampe, `gabarits/kit.lua`) |
| Ajouter un obstacle | `MODULES` dans `gabarits/parcours.lua`, puis l'ajouter à `MODULES_CALMES` ou `MODULES_PIEGES` |
| Changer le décor d'un format | `gabarits/scenes.lua` |
| Changer les règles du jeu | `gabarits/jeu.server.lua` |
| Ajouter un format | [`formats.luau`](formats.luau) + ses gabarits + `lib/assemblage.luau` |

Les fichiers `maps/<nom>.lua` des jeux créés ne se modifient pas à la main :
après un changement de gabarit, régénérer chaque jeu avec la commande écrite en
tête de son fichier (un test échoue tant que ce n'est pas fait).
