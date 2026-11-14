# Ce dont le projet a besoin de vous

Document unique. Tout ce qui suit est **facultatif pour utiliser le projet**
(il fonctionne tel quel), mais chaque point débloque quelque chose de précis.
Classé du plus utile au moins utile.

Rien de payant n'a été utilisé. Outils employés, tous gratuits : Lune, selene,
StyLua, three.js, Playwright/Chromium, l'API Open Cloud de Roblox, GitHub Actions.

## 1. Rejouer dix minutes aux deux jeux corrigés

Votre premier essai a tout changé : merci. Voici ce que j'en ai fait, et ce que
je ne peux toujours pas vérifier sans vous (l'environnement de test de Roblox
n'a ni physique, ni joueur, ni son, ni image).

**Comment.** Dans Studio : View → Command Bar, coller tout le contenu de
`maps/tour-volcan.lua`, Entrée, puis le bouton **Play** (pas « Play Here », qui
fait apparaître à l'endroit de la caméra). Même chose avec `maps/evasion-prison.lua`.

| Votre retour | Ce que j'ai fait | À me confirmer |
|---|---|---|
| Trop de lumière, un flou, on ne voit rien | Brume, éblouissement et halo plafonnés ; lumières deux fois moins fortes ; rayons de soleil retirés ; dessous des plateformes du volcan en lave craquelée au lieu de néon | Est-ce net maintenant ? Trop terne ? Une capture d'écran m'aiderait beaucoup |
| Gemmes et coupe : de simples cubes jaunes | Gemmes taillées à huit facettes, coupe avec pied, vasque et anses, plateformes à cadre et gradins | Est-ce au niveau ? Quel élément reste trop pauvre ? |
| Apparition dans le vide sur l'évasion | Je n'ai pas pu le reproduire : dans le vrai moteur, le point d'apparition a bien un sol dessous. Hypothèse non vérifiée : le bouton « Play Here ». Dans tous les cas, un filet de sécurité ramène au départ tout joueur apparu ou tombé hors de la map | Apparaissez-vous bien dans la cour ? |
| Après une chute, retour au début au lieu du checkpoint | Une chute ramène à la dernière arche franchie, sans mourir. Après une mort (barre, braise), le personnage est remis sur son arche | Les deux cas marchent-ils ? |
| Des cases partout, on pourrait tout faire en marchant | Vides de 4,6 à 6,9 studs (au lieu de 3,4 à 6,5), dalles plus petites, plus aucun obstacle franchissable en marchant | Trop facile, bien, ou trop dur ? À partir de quelle étape ? |
| Dalles de verre qui disparaissent trop vite | Elles rougissent au premier pas, pâlissent, et ne disparaissent qu'au bout de 3 secondes | Est-ce le bon délai ? |
| Bruit horrible (gemmes, checkpoint) | Je ne peux pas écouter : j'ai gardé le son mais beaucoup plus bas et plus aigu, donc plus bref | Supportable ? Sinon, voir le point « son » ci-dessous |
| Fini en 20 minutes, rien pour revenir | Chronomètre et record au classement ; cinq reliques secrètes par jeu, cachées sous des paliers ; traînée derrière le joueur à 1, 3, 5 et 10 victoires | Trouvez-vous une relique ? Le record s'affiche-t-il à l'arrivée ? |

**Pas encore testé par vous** (votre premier essai s'est arrêté avant) : barres
tournantes (tuent-elles même si vous ne bougez pas ?), tapis roulant (vous
pousse-t-il vers l'arrière ?), victoire en haut, fluidité sur téléphone.

**Le son.** Le plus simple : dans Studio, ouvrir la Toolbox → Audio, choisir un
son de ramassage et un son de checkpoint qui vous plaisent, et me donner leurs
deux numéros (asset ID). Je les brancherai dans tous les jeux.

**Variante qui me rend autonome.** Brancher Claude Code à Roblox Studio sur
votre ordinateur, comme décrit dans `rpg/GUIDE-CLAUDE-CODE-STUDIO.md` (pull
request « RPG Givrecendre »). Je pourrais alors voir le vrai rendu et tester en
jouant moi-même. Je n'ai pas vérifié ce guide dans cette session.

## 2. Une place Roblox réservée aux tests

**Pourquoi.** Une seule expérience est configurée (`pipeline/experience.json`) :
celle des Îles Célestes. Pour tester deux jeux dans le vrai moteur, j'ai dû les
envoyer en **brouillon** sur cette place (versions 9, 10, 12 et 13, invisibles
des joueurs), puis y remettre à chaque fois Les Îles Célestes (versions 11 et
14, re-testées). La version publiée, celle que voient les joueurs, n'a pas été touchée.

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
