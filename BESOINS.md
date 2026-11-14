# Ce dont le projet a besoin de vous

Document unique. Tout ce qui suit est **facultatif pour utiliser la version 2**
(elle fonctionne telle quelle), mais chaque point débloque quelque chose de
précis. Classé du plus utile au moins utile.

Rien de payant n'a été utilisé. Outils employés, tous gratuits : Lune, selene,
StyLua, three.js, Playwright/Chromium, l'API Open Cloud de Roblox, GitHub Actions.

## 1. Jouer dix minutes à deux jeux dans Roblox Studio

**Pourquoi.** C'est la seule chose que je ne peux pas faire. L'environnement de
test de Roblox n'a ni physique ni joueur : je n'ai donc jamais vu le vrai rendu,
ni senti un saut. Les aperçus du dépôt sont dessinés hors de Roblox.

**Comment.** Dans Studio : View → Command Bar, coller tout le contenu de
`maps/evasion-prison.lua`, Entrée, puis Play. Même chose avec `maps/tour-volcan.lua`.

**Ce que j'ai besoin de savoir** (une phrase par point suffit) :

| Point | Question |
|---|---|
| Rendu | Est-ce beau ? Trop sombre, trop clair, trop chargé ? Une capture d'écran m'aiderait beaucoup |
| Sauts | Y a-t-il un saut impossible ou trop dur ? À quelle étape ? |
| Barres tournantes | Tuent-elles bien quand elles vous touchent, même si vous ne bougez pas ? |
| Tapis roulant | Vous pousse-t-il vraiment vers l'arrière ? |
| Dalles de verre | Disparaissent-elles sous vos pieds puis reviennent-elles ? |
| Réapparition | Après une chute, revenez-vous bien sur la dernière arche franchie ? |
| Victoire | En haut, le compteur de victoires monte-t-il, et revenez-vous au départ ? |
| Fluidité | Sur téléphone si possible : est-ce fluide ? |

**Variante qui me rend autonome.** Brancher Claude Code à Roblox Studio sur
votre ordinateur, comme décrit dans `rpg/GUIDE-CLAUDE-CODE-STUDIO.md` (pull
request « RPG Givrecendre »). Je pourrais alors voir le vrai rendu et tester en
jouant moi-même. Je n'ai pas vérifié ce guide dans cette session.

## 2. Une place Roblox réservée aux tests

**Pourquoi.** Une seule expérience est configurée (`pipeline/experience.json`) :
celle des Îles Célestes. Pour tester deux jeux dans le vrai moteur, j'ai dû les
envoyer en **brouillon** sur cette place (versions 9 et 10, invisibles des
joueurs), puis y remettre Les Îles Célestes (version 11, re-testée). La version
publiée, celle que voient les joueurs, n'a pas été touchée.

**Ce qu'il me faut.** Une expérience vide créée sur le Creator Hub, et ses deux
numéros : `universeId` et `placeId`. Si la clé API est limitée à une
expérience, lui ajouter celle-ci avec les mêmes quatre droits.

## 3. Une expérience Roblox par jeu à publier

**Pourquoi.** Chaque jeu publié a besoin de sa propre expérience (ses joueurs,
ses sauvegardes, sa boutique). Aujourd'hui, publier un jeu de la Fabrique
remplacerait Les Îles Célestes.

**Ce qu'il me faut.** Me dire **quel jeu publier en premier** parmi les six, et
me donner l'`universeId` et le `placeId` de l'expérience créée pour lui. Je ne
publierai jamais une version visible des joueurs sans votre accord.

## 4. Trois réglages sur GitHub

| Réglage | Où | Ce que ça débloque |
|---|---|---|
| Fusionner la pull request de la version 2 dans la branche par défaut | La pull request | L'agent hebdomadaire « Fabrique — nouveau jeu » ne démarre qu'une fois sur la branche par défaut. Il n'a donc jamais tourné sur GitHub ; ses étapes ont été essayées ici |
| Autoriser « Allow GitHub Actions to create and approve pull requests » | Settings → Actions → General | Sans lui, l'agent pousse bien sa branche, mais vous devrez ouvrir la pull request à la main |
| Fermer la pull request « Photos des classements » | La pull request | Ses relevés sont déjà inclus dans la version 2 |

## 5. Quatre décisions

| Décision | Mon avis (étiqueté comme tel) |
|---|---|
| Quel format rendre constructible ensuite ? Candidats repérés : ragdoll (score 44), œufs/collection (35), construction (26), vol entre bases (25), +1/évolution (20) | Opinion : œufs/collection ou +1/évolution. « Simulation » réunit 41 % des joueurs relevés, et ces deux formats se testent sans physique ni affrontement entre joueurs, contrairement à ragdoll et vol |
| Interface du jeu en anglais ? | Opinion : oui avant de publier. Les titres relevés dans les classements sont en anglais ; l'interface actuelle est en français |
| Que faire de la pull request « RPG Givrecendre » ? | Sans avis : elle est indépendante de la Fabrique |
| Rythme de l'agent GitHub (un jeu par semaine aujourd'hui) | Opinion : suffisant tant que personne n'a joué aux six premiers |

## 6. Ce qui se crée sur le Creator Hub, pour plus tard

| Besoin | À quoi ça sert | Remarque |
|---|---|---|
| Icône et miniatures de chaque jeu | Page Roblox du jeu | À capturer dans Studio : les aperçus du dépôt ne sont pas le vrai rendu |
| Badges | Objectifs à long terme (le validateur signale leur absence) | Je ne peux pas confirmer le coût actuel d'un badge : à vérifier sur le Creator Hub |
| Produit « passer l'étape » et passes, par expérience | Revenus | Les identifiants actuels de la boutique appartiennent à l'expérience des Îles Célestes |

## 7. Pour information : limite d'usage

Deux agents que j'avais lancés en parallèle (tests, relecture) ont été coupés
par la limite d'usage de cinq heures avant d'avoir rien produit. J'ai fait leur
travail moi-même. Rien à faire de votre côté ; cela explique seulement le délai.
