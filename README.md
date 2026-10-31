# Roblox : maps générées, testées et améliorées automatiquement

| Dossier / fichier | Contenu |
|---|---|
| [`maps/`](maps/) | Scripts de construction des maps (à coller dans la barre de commande de Roblox Studio, ou à construire avec le pipeline) |
| [`pipeline/`](pipeline/) | Chaîne automatique : construction hors Studio, tests, rapport de validation ([mode d'emploi](pipeline/README.md)) |
| [`reports/`](reports/) | Derniers rapports de validation de chaque map |
| [`recherche/`](recherche/) | Recherche de niche à partir des classements officiels Roblox ([dernier rapport](recherche/rapport-niche.md)) |
| [`prompt-map-roblox.md`](prompt-map-roblox.md) | Prompt d'origine pour générer une map |

Lancer tous les tests :

```bash
./pipeline/run.sh
```

Nouvelle photo des classements Roblox + rapport de niche :

```bash
python3 recherche/niche.py
```
