# Roblox : maps générées, testées et améliorées automatiquement

| Dossier / fichier | Contenu |
|---|---|
| [`src/`](src/) | Noyau commun à tous les jeux : sauvegarde (avec verrou de session), récompense quotidienne, achats, boutique, interface |
| [`maps/`](maps/) | Scripts de construction des maps (à coller dans la barre de commande de Roblox Studio, ou à construire avec le pipeline) |
| [`pipeline/`](pipeline/) | Chaîne automatique : construction hors Studio, tests, rapport de validation ([mode d'emploi](pipeline/README.md)) |
| [`reports/`](reports/) | Derniers rapports de validation de chaque map, et des tests dans le vrai moteur Roblox |
| [`recherche/`](recherche/) | Recherche de niche à partir des classements officiels Roblox ([dernier rapport](recherche/rapport-niche.md)) |
| [`prompt-map-roblox.md`](prompt-map-roblox.md) | Prompt d'origine pour générer une map |

Lancer tous les tests :

```bash
./pipeline/run.sh
```

Créer la boutique, publier la place et la tester dans le vrai moteur Roblox
(clé dans `ROBLOX_API_KEY`, détails dans [`pipeline/README.md`](pipeline/README.md)) :

```bash
python3 pipeline/opencloud.py boutique
```

```bash
python3 pipeline/opencloud.py publier build/iles-celestes.rbxl
```

```bash
python3 pipeline/opencloud.py tester
```

Nouvelle photo des classements Roblox + rapport de niche :

```bash
python3 recherche/niche.py
```
