# Instructions pour Claude (Desktop) + MCP Roblox Studio — Étape 1 : l'Ogre

Tu es Claude, connecté à Roblox Studio par le MCP `Roblox_Studio`. Ce fichier
te dit tout ce que tu dois faire. Suis les phases **dans l'ordre** et
**arrête-toi à chaque « ⏸ VALIDATION »** pour montrer le résultat au
propriétaire et attendre son accord.

## Règles (toujours)

- Parle **français**.
- **Dis la vérité** : ne dis jamais qu'une chose marche sans l'avoir vérifiée
  par une capture (`screen_capture`) ou un test. Si un outil échoue, dis-le
  avec le message d'erreur exact.
- Avant toute grosse modification, demande au propriétaire de **sauvegarder la
  place** (Fichier → Enregistrer).
- Ne publie rien (pas de Fichier → Publier) sans qu'il le demande.
- Range tout ce que tu crées dans `workspace.Givrecendre` (dossier), jamais en
  vrac dans `workspace`.
- Le jeu est **original** : pas de nom, lieu ou personnage d'un jeu existant.
- **Note tout le code Luau que tu exécutes** avec `execute_luau` : à la fin,
  rassemble-le dans un seul bloc pour que le propriétaire puisse le
  transmettre (il sera enregistré dans le dépôt du projet).

## Contexte du jeu

Action-RPG **sombre, brutal et réaliste**, univers nordique maudit appelé
*Givrecendre* (cendre et givre). Le joueur est un chevalier qui doit sauver
une princesse. **Boss 1 : Grimmulf, l'Ogre du Col**, un ogre nordique avec une
énorme massue hérissée de pics. Il combat dans **un fort en ruine, au fond d'un
col enneigé, entouré de palissades**.

## Phase 1 — Préparer la place

1. `list_roblox_studios` puis `get_studio_state` : vérifie qu'une place est
   ouverte en mode édition.
2. Avec `execute_luau` (datamodel `Edit`) :
   - crée le dossier `workspace.Givrecendre` ;
   - éclairage sombre et froid : `Lighting.ClockTime = 17.2`,
     `Lighting.Brightness = 2`, `EnvironmentDiffuseScale = 1`,
     `EnvironmentSpecularScale = 1`, un `Atmosphere` (Density 0.45,
     Haze 2.5, Color gris-bleu `Color3.fromRGB(150,160,175)`, Decay
     `Color3.fromRGB(70,75,90)`), un `ColorCorrectionEffect` (Saturation -0.2,
     Contrast 0.12, TintColor `Color3.fromRGB(220,228,240)`) ;
   - supprime la `Baseplate` d'origine si elle existe.
3. `screen_capture` et montre l'ambiance.

## Phase 2 — Générer l'Ogre

1. Utilise `generate_mesh` avec ce texte (en anglais, les générateurs le
   comprennent mieux) :
   > Realistic dark fantasy Nordic ogre, about 3 times the height of a human,
   > grey rough skin with scars, wearing worn fur and leather, iron ornaments
   > with Norse runes, long braided beard, holding a huge wooden club covered
   > with iron spikes, menacing pose.
2. Place l'Ogre dans `workspace.Givrecendre.Ogre`, debout sur le sol, à peu
   près 3 fois la taille d'un personnage Roblox (environ 15 studs de haut).
3. Fais **3 captures** avec `screen_capture` (caméra de face, de profil, gros
   plan sur la tête et la massue) et montre-les.
4. Dis honnêtement ce qui ne va pas (proportions, texture, massue absente ou
   ratée…).

⏸ **VALIDATION** : demande au propriétaire si l'Ogre lui convient. S'il veut
des changements, regénère avec un texte ajusté (2 à 3 essais maximum, en
montrant chaque fois les captures). Si la massue est ratée, génère-la à part
avec un second `generate_mesh` :
> Huge heavy wooden club with many sharp iron spikes and iron bands, dark
> fantasy, realistic, worn.

## Phase 3 — L'arène de l'Ogre

Construis avec `execute_luau` (dans `workspace.Givrecendre.ArenaOgre`) :

1. **Le col** : un Terrain enneigé (`Terrain:FillBlock` / `FillBall` avec
   `Enum.Material.Snow`, `Rock`, `Glacier`), deux parois rocheuses hautes de
   part et d'autre, un chemin d'accès qui monte vers l'arène.
2. **Le fort en ruine** : une cour circulaire d'environ **80 studs de
   diamètre**, sol en pierre (`Cobblestone` / `Slate`) partiellement couvert
   de neige ; murs de pierre effondrés par endroits ; une **palissade** de
   rondins taillés en pointe (`Wood`, couleur sombre) tout autour ; une
   seule entrée (portail en bois) ; 4 à 6 **piliers** de pierre (l'Ogre pourra
   en arracher en phase 2) ; quelques braseros avec du feu (`Fire` +
   `PointLight` orangé) pour éclairer.
3. Détails réalistes : os et crânes d'animaux au sol, armes rouillées
   plantées dans la neige, flocons qui tombent (`ParticleEmitter` léger),
   brume au sol.
4. Place l'Ogre au centre-fond de la cour, face à l'entrée.
5. Ajoute un `SpawnLocation` devant le portail, côté extérieur.
6. `screen_capture` : vue d'ensemble de haut, vue depuis l'entrée (ce que voit
   le joueur en arrivant), vue rapprochée de l'Ogre dans l'arène.

⏸ **VALIDATION** : montre les 3 captures et attends l'accord.

## Phase 4 — Test en jeu

1. `start_stop_play` pour lancer le jeu.
2. `character_navigation` : fais marcher le personnage du spawn jusqu'au
   centre de l'arène.
3. `screen_capture` pendant le trajet et à l'arrivée ;
   `get_console_output` pour vérifier qu'il n'y a **aucune erreur**.
4. `start_stop_play` pour arrêter.
5. Signale tout problème (on traverse un mur, on reste bloqué, chute dans le
   vide, lag…).

## Phase 5 — Compte rendu

Termine par un résumé pour le propriétaire :
- ce qui a été fait, avec les captures finales ;
- ce qui n'a pas marché ou reste à améliorer ;
- **le code Luau complet** utilisé (un seul bloc), à transmettre à Claude
  dans le cloud, qui l'enregistrera et le testera dans le dépôt ;
- rappel : sauvegarder la place (Fichier → Enregistrer) et la publier
  (Fichier → Publier) quand le propriétaire le décide.

L'IA de combat de l'Ogre (attaques, phases) n'est **pas** à faire ici : elle
sera codée et testée dans le dépôt du projet.
