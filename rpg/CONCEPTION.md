# Conception du RPG — titre de travail : *Givrecendre*

Document de référence du jeu. Il réunit les décisions prises avec le
propriétaire du projet. Toute session (cloud ou locale) le lit avant de
travailler sur le RPG, et le met à jour quand une décision change.

Légende : ✅ décidé · 💡 proposition à valider · ❓ question ouverte

## 1. Intention

- ✅ Un **action-RPG exigeant**, sombre et brutal, dans l'esprit des
  souls-like : combats difficiles, boss, exploration, butin, points de
  repos. **Univers, noms, lieux et boss 100 % originaux** : on s'inspire du
  genre, on ne copie aucun jeu existant.
- ✅ Style visuel : **réaliste sombre**.
- ✅ Plateformes : **PC et mobile** (le plus de joueurs possible).
- ✅ Première région : **environ 1 h de jeu**.
- ✅ Objectif commercial : un jeu ambitieux qui peut percer. On mesurera
  avec les données réelles (rétention J1/J7, durée des sessions, achats).

## 2. Univers et histoire

- 💡 **Givrecendre** : un royaume nordique maudit, couvert de cendre et de
  givre. Pins morts, ruines nordiques, brume, feux de camp.
- ✅ Le joueur est un **chevalier** qui doit **sauver la princesse**,
  enlevée pendant la **cinématique d'ouverture**.
- 💡 Dans la cinématique, c'est l'**hippogriffe putréfié** (boss 2) qui
  emporte la princesse depuis le château.
- ✅ Fin de la région : la princesse est retrouvée chez le boss 3,
  **enroulée dans un cocon de toiles, seule la tête dépasse**, entourée de
  **petites araignées**.

## 3. Les boss (chacun avec son arène dédiée)

✅ Chaque boss a sa **propre arène** (grotte ou terrain de combat) conçue
pour son combat.

| | Boss | Description (✅) | Arène (💡) | Attaques (💡) |
|---|---|---|---|---|
| 1 | **Grimmulf, l'Ogre du Col** (💡 nom) | Ogre de style **nordique**, **massue hérissée de pics** | Fort en ruine dans un col enneigé, ceint de palissades | Onde de choc au sol, charge, balayage ; phase 2 enragée : arrache un pilier, lance des rochers |
| 2 | **L'Hippogriffe putréfié** | Hippogriffe **zombie**, **volant** : à la place des plumes, de la **chair qui se détache** | Nid au sommet d'une falaise, piliers pour s'abriter des piqués | Piqués, cri étourdissant, lambeaux de chair projetés ; phase 2 : ailes déchirées, combat au sol |
| 3 | **La Tisseuse** (💡 nom) | **Araignée géante velue**, détails inhabituels (yeux luminescents…) | Immense grotte tapissée de toiles, la princesse en cocon au fond | Toiles qui ralentissent, venin, invocation d'araignéons ; phase 2 : attaque depuis le plafond |

Les boss servent à **l'avancement** : chacun ouvre la zone suivante.

### Récompenses d'un boss (✅)

- de l'**XP** ;
- **+10 % de dégâts, permanent et cumulable** (+30 % après les 3 boss) ;
- **3 points de compétence** (contre 1 habituellement, qui est rare) ;
- **boost d'XP pendant 1 h** (💡 ×2) ;
- un **skin d'arme du boss** (voir ci-dessous).

### Skins de boss (✅)

- Un skin **par boss**, **en rapport avec le boss** (💡 Ogre : fer clouté,
  fourrure et runes ; Hippogriffe : chair putréfiée et mouches ; Tisseuse :
  soie, venin luisant).
- **Universel** : il s'applique à **toutes les armes** (épée, massue,
  arbalète, bâton…). Techniquement : un « habillage » (matériaux, textures,
  effets, petits ornements) posé sur n'importe quel modèle d'arme, pas un
  modèle par arme.
- **Réservé aux détenteurs du pass** et obtenu **uniquement en battant ce
  boss**.
- 💡 La victoire est enregistrée pour tous : un joueur qui achète le pass
  après coup récupère aussitôt les skins des boss déjà battus.

## 4. Armes (✅ 15 types)

| Mêlée (5) | Distance (5) | Magie (5) |
|---|---|---|
| 💡 Épée longue | 💡 Arc court | 💡 Bâton de feu |
| 💡 Espadon (deux mains) | 💡 Arc long | 💡 Sceptre de givre |
| 💡 Hache de guerre | 💡 Arbalète | 💡 Grimoire de foudre |
| 💡 Lance | 💡 Javelots | 💡 Orbe d'ombre |
| 💡 Marteau / massue | 💡 Haches de jet | 💡 Talisman sacré (soin) |

- ✅ **Raretés** : 💡 Commun, Peu commun, Rare, Épique, Légendaire. Les
  stats et le visuel montent avec la rareté. 💡 Le Légendaire est réservé
  aux boss.

## 5. Compétences (✅)

- Des compétences à monter avec des **points de compétence** : 1 point
  habituellement, **difficile à obtenir** ; **3 points par boss**.
- 💡 Quatre branches : **Guerrier** (mêlée), **Chasseur** (distance),
  **Arcaniste** (magie), **Survie** (vie, endurance, roulade).

## 6. Combat (💡)

Endurance, attaque légère et lourde, roulade avec invulnérabilité,
verrouillage de cible, fioles de soin, points de repos qui font
réapparaître les ennemis. Calculs de dégâts côté serveur (anti-triche).
Commandes tactiles pour le mobile.

## 7. Monétisation (✅ / 💡)

- ✅ Un **pass** qui donne accès aux **skins de boss**.
- 💡 Garder le pass surtout esthétique : vendre de la puissance fait
  souvent fuir les joueurs gratuits (avis, pas une règle Roblox).
- Le noyau existant (`src/`) gère déjà la sauvegarde, les achats, les
  passes et la récompense quotidienne.

## 8. Production

- **Armes, armures, décors, arènes, grottes, Terrain** : modélisés par
  script avec **Blender** (`bpy` 5.2, testé dans l'environnement cloud),
  rendus en image pour validation, puis envoyés sur Roblox avec l'API
  Open Cloud « Assets » (`.fbx` / `.glb`, 20 Mo max ; la clé a les droits
  `asset:read` et `asset:write`).
- **Créatures réalistes** (ogre, hippogriffe, araignée) : génération IA via
  le **MCP intégré à Roblox Studio** (`generate_mesh`), depuis Claude Code
  sur l'ordinateur du propriétaire. Animation : à vérifier (procédurale par
  le code pour les pattes et les ailes).
- **Vérification visuelle** : `screen_capture` du MCP de Studio, en plus
  des tests automatiques (`./pipeline/run.sh`, `pipeline/opencloud.py tester`).
- ❓ **Nouvelle expérience Roblox** : en cours de création par le
  propriétaire (les Îles Célestes restent à part).

## 9. Étapes

1. **Prototype de combat** : chevalier, 3 armes (une par catégorie),
   ennemis de base, l'Ogre dans son arène.
2. **Butin et progression** : les 15 armes et leurs raretés, inventaire,
   compétences, sauvegarde.
3. **Région complète** (~1 h) : cinématique, village avec PNJ qui parlent
   et quêtes, les 3 boss et leurs arènes, la princesse.
4. **Pass, équilibrage, tests PC et mobile, lancement.**

Chaque modèle est montré en image et validé avant d'être intégré ; chaque
version est testée (local + vrai moteur) avant d'être publiée.
