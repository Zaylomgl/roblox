#!/usr/bin/env python3
"""
Roblox Open Cloud : boutique, publication de la place, tests dans le vrai moteur.

La clé API est lue dans la variable d'environnement ROBLOX_API_KEY : elle ne
doit jamais être écrite dans le repo. Les identifiants (publics) de
l'expérience sont dans pipeline/experience.json.

Usage :
    python3 pipeline/opencloud.py cle
        Vérifie la clé (active, non expirée) et ses droits.
    python3 pipeline/opencloud.py boutique
        Crée sur Roblox les passes et produits de Configuration.luau dont l'id
        vaut 0 (nom, description, prix, mis en vente), puis écrit leur id dans
        Configuration.luau. Ne crée jamais de doublon : un objet du même nom
        déjà présent sur Roblox est réutilisé.
    python3 pipeline/opencloud.py publier build/iles-celestes.rbxl
        Publie la place (version « Published », visible des joueurs).
    python3 pipeline/opencloud.py tester [--version N] [--map iles-celestes]
        Lance pipeline/reel/tests.luau dans le vrai moteur Roblox (API « Luau
        Execution ») sur la version publiée, affiche les journaux et écrit
        reports/<map>-moteur-reel.md et .json.

Documentation officielle utilisée (lue le 31/10/2026) :
    https://create.roblox.com/docs/cloud/reference/features/game-passes.md
    https://create.roblox.com/docs/cloud/reference/features/developer-products.md
    https://create.roblox.com/docs/cloud/reference/features/places.md
    https://create.roblox.com/docs/cloud/guides/usage-place-publishing
    https://create.roblox.com/docs/cloud/reference/features/luau-execution.md

Bibliothèque standard uniquement (+ lune pour lire Configuration.luau).
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

RACINE = pathlib.Path(__file__).resolve().parent.parent
EXPERIENCE = RACINE / "pipeline" / "experience.json"
CONFIGURATION = RACINE / "src" / "ReplicatedStorage" / "Partage" / "Configuration.luau"
TESTS_REELS = RACINE / "pipeline" / "reel" / "tests.luau"
TESTS_NOYAU = RACINE / "pipeline" / "tests" / "noyau.test.luau"
DERNIERE_PUBLICATION = RACINE / "build" / "derniere-publication.json"
RAPPORTS = RACINE / "reports"

API = "https://apis.roblox.com"

# Droits nécessaires (noms exacts renvoyés par api-keys/v1/introspect).
DROITS = {
    "game-pass": {"read", "write"},
    "developer-product": {"read", "write"},
    "universe-places": {"write"},
    "universe.place.luau-execution-session": {"read", "write"},
}


class ErreurApi(Exception):
    def __init__(self, code: int, texte: str):
        super().__init__(f"HTTP {code} : {texte[:800]}")
        self.code = code


def cle_api() -> str:
    cle = os.environ.get("ROBLOX_API_KEY", "").strip()
    if not cle:
        sys.exit("✖ Variable d'environnement ROBLOX_API_KEY absente.")
    return cle


def experience() -> dict:
    return json.loads(EXPERIENCE.read_text())


def requete(
    methode: str,
    url: str,
    *,
    corps: bytes | None = None,
    type_contenu: str | None = None,
    json_corps: dict | None = None,
    rejouable: bool | None = None,
    avec_cle: bool = True,
):
    """Requête HTTP vers Open Cloud. Réessaie sur 429 (toujours) et sur 5xx (GET seulement,
    pour ne jamais créer deux fois le même objet)."""
    entetes = {"x-api-key": cle_api()} if avec_cle else {}
    if json_corps is not None:
        corps = json.dumps(json_corps).encode()
        type_contenu = "application/json"
    if type_contenu:
        entetes["Content-Type"] = type_contenu
    if rejouable is None:
        rejouable = methode == "GET"
    for essai in range(6):
        req = urllib.request.Request(url, data=corps, headers=entetes, method=methode)
        try:
            with urllib.request.urlopen(req, timeout=180) as reponse:
                donnees = reponse.read()
                return json.loads(donnees) if donnees.strip() else None
        except urllib.error.HTTPError as e:
            texte = e.read().decode(errors="replace")
            if essai < 5 and (e.code == 429 or (rejouable and e.code >= 500)):
                attente = 2 ** (essai + 1)
                print(f"  … HTTP {e.code}, nouvel essai dans {attente} s")
                time.sleep(attente)
                continue
            raise ErreurApi(e.code, texte) from None
    raise AssertionError("inatteignable")


def multipart(champs: dict[str, str]) -> tuple[bytes, str]:
    frontiere = uuid.uuid4().hex
    morceaux = []
    for nom, valeur in champs.items():
        morceaux.append(
            f'--{frontiere}\r\nContent-Disposition: form-data; name="{nom}"\r\n\r\n{valeur}\r\n'.encode()
        )
    morceaux.append(f"--{frontiere}--\r\n".encode())
    return b"".join(morceaux), f"multipart/form-data; boundary={frontiere}"


def lister(url: str, champ: str) -> list[dict]:
    elements, jeton = [], ""
    while True:
        separateur = "&" if "?" in url else "?"
        page = requete("GET", f"{url}{separateur}pageSize=50" + (f"&pageToken={jeton}" if jeton else ""))
        elements += page.get(champ) or []
        jeton = page.get("nextPageToken")
        if not jeton:
            return elements


def lire_configuration() -> dict:
    sortie = subprocess.run(
        ["lune", "run", "pipeline/configuration"], cwd=RACINE, capture_output=True, text=True, check=True
    )
    return json.loads(sortie.stdout)


def ecrire_id(cle: str, nouvel_id: int) -> None:
    """Remplace `id = …` de l'objet `cle = "<cle>"` dans Configuration.luau."""
    texte = CONFIGURATION.read_text()
    motif = re.compile(r'(cle = "' + re.escape(cle) + r'",\s*id = )\d+')
    nouveau, n = motif.subn(lambda m: m.group(1) + str(nouvel_id), texte)
    if n != 1:
        sys.exit(f"✖ Impossible de trouver l'id de « {cle} » dans {CONFIGURATION} ({n} occurrence(s)).")
    CONFIGURATION.write_text(nouveau)


################################################################################ Commandes


def commande_cle(_args) -> int:
    infos = requete("POST", f"{API}/api-keys/v1/introspect", json_corps={"apiKey": cle_api()}, avec_cle=False)
    print(f"Clé « {infos.get('name')} » — active : {infos.get('enabled')}, expirée : {infos.get('expired')}")
    droits = {d["name"]: set(d.get("operations") or []) for d in infos.get("scopes") or []}
    univers = str(experience()["universeId"])
    manquants = []
    for nom, operations in DROITS.items():
        portee = next((d for d in infos.get("scopes") or [] if d["name"] == nom), None)
        ok = nom in droits and operations <= droits[nom]
        ok = ok and portee is not None and ("*" in portee.get("universeIds", []) or univers in portee["universeIds"])
        print(f"  {'✔' if ok else '✖'} {nom} : {', '.join(sorted(operations))}")
        if not ok:
            manquants.append(nom)
    if not infos.get("enabled") or infos.get("expired") or manquants:
        print("✖ Clé inutilisable pour le pipeline (droits manquants ou clé inactive).")
        return 1
    print("✔ Clé utilisable pour la boutique, la publication et les tests dans le vrai moteur.")
    return 0


def commande_boutique(_args) -> int:
    univers = experience()["universeId"]
    config = lire_configuration()
    url_passes = f"{API}/game-passes/v1/universes/{univers}/game-passes"
    url_produits = f"{API}/developer-products/v2/universes/{univers}/developer-products"
    sorte = {
        "pass": ("PASSES", f"{url_passes}/creator", "gamePasses", "gamePassId", url_passes),
        "produit": ("PRODUITS", f"{url_produits}/creator", "developerProducts", "productId", url_produits),
    }
    for genre, (section, url_liste, champ_liste, champ_id, url_creation) in sorte.items():
        existants = lister(url_liste, champ_liste)
        for objet in config.get(section) or []:
            nom, ident = objet["nom"], int(objet.get("id") or 0)
            if ident != 0:
                trouve = next((e for e in existants if int(e[champ_id]) == ident), None)
                etat = "présent sur Roblox" if trouve else "INTROUVABLE sur Roblox (supprimé ? autre univers ?)"
                print(f"  {'✔' if trouve else '✖'} {genre} « {nom} » (id {ident}) : {etat}")
                continue
            meme_nom = next((e for e in existants if e.get("name") == nom), None)
            if meme_nom:
                ident = int(meme_nom[champ_id])
                print(f"  ↺ {genre} « {nom} » existe déjà sur Roblox (id {ident}) : réutilisé")
            else:
                if not objet.get("prix"):
                    sys.exit(f"✖ {genre} « {nom} » : pas de `prix` dans Configuration.luau.")
                corps, type_contenu = multipart(
                    {
                        "name": nom,
                        "description": objet.get("description", ""),
                        "price": str(int(objet["prix"])),
                        "isForSale": "true",
                    }
                )
                cree = requete("POST", url_creation, corps=corps, type_contenu=type_contenu)
                ident = int(cree[champ_id])
                print(
                    f"  + {genre} « {nom} » créé : id {ident}, en vente : {cree.get('isForSale')}, "
                    f"prix : {json.dumps(cree.get('priceInformation'), ensure_ascii=False)}"
                )
            ecrire_id(objet["cle"], ident)
    # Vérification : relire la configuration écrite.
    for section in ("PASSES", "PRODUITS"):
        for objet in lire_configuration().get(section) or []:
            if int(objet.get("id") or 0) == 0:
                print(f"✖ « {objet['nom']} » a toujours l'id 0")
                return 1
    print(f"✔ Boutique à jour, identifiants écrits dans {CONFIGURATION.relative_to(RACINE)}")
    return 0


def commande_publier(args) -> int:
    exp = experience()
    fichier = pathlib.Path(args.fichier)
    if fichier.suffix not in (".rbxl", ".rbxlx"):
        sys.exit("✖ Fichier .rbxl ou .rbxlx attendu.")
    type_contenu = "application/octet-stream" if fichier.suffix == ".rbxl" else "application/xml"
    url = f"{API}/universes/v1/{exp['universeId']}/places/{exp['placeId']}/versions?versionType=Published"
    print(f"▶ Publication de {fichier} ({fichier.stat().st_size / 1024:.0f} Ko) sur la place {exp['placeId']}")
    reponse = requete("POST", url, corps=fichier.read_bytes(), type_contenu=type_contenu)
    version = reponse.get("versionNumber") if isinstance(reponse, dict) else reponse
    if version is None:
        print(f"✖ Réponse inattendue : {reponse!r}")
        return 1
    DERNIERE_PUBLICATION.parent.mkdir(parents=True, exist_ok=True)
    DERNIERE_PUBLICATION.write_text(
        json.dumps(
            {
                "versionNumber": int(version),
                "fichier": str(fichier),
                "map": fichier.stem,
                "date": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
            },
            indent=2,
        )
    )
    print(f"✔ Publiée : version {version} — https://www.roblox.com/games/{exp['placeId']}")
    return 0


def assembler_script(map_nom: str, version: int | None = None) -> str:
    """pipeline/reel/tests.luau + chiffres attendus (rapport du validateur, version publiée) + tests du noyau."""
    script = TESTS_REELS.read_text()
    rapport = RAPPORTS / f"{map_nom}.json"
    if rapport.exists():
        donnees = json.loads(rapport.read_text())
        stats, monde = donnees["statistiques"], donnees["monde"]
        champs = {k: stats[k] for k in ("pieces", "piecesNonAncrees", "lumieres", "emetteursParticules", "sons",
                                        "collectibles", "spawns")}
        champs["hauteurSaut"] = monde["hauteurSautTheorique"]
        champs["vitesseMarche"] = monde["vitesseMarche"]
        champs["fallenPartsDestroyHeight"] = monde["fallenPartsDestroyHeight"]
    else:
        champs = {}
    if version:
        champs["placeVersion"] = int(version)
    attendu = "{ " + ", ".join(f"{k} = {json.dumps(v)}" for k, v in champs.items()) + " }" if champs else "nil"
    noyau = re.sub(
        r'require\("\.\./\.\./src/ServerScriptService/Noyau/(\w+)"\)',
        r'require(game:GetService("ServerScriptService"):WaitForChild("Noyau"):WaitForChild("\1"))',
        TESTS_NOYAU.read_text(),
    )
    if "require(\"" in noyau:
        sys.exit("✖ noyau.test.luau contient un require non adaptable au vrai moteur.")
    lignes = []
    for ligne in script.splitlines():
        if "--@@ATTENDU@@" in ligne:
            lignes.append(f"local ATTENDU = {attendu}")
        elif "--@@TESTS_NOYAU@@" in ligne:
            lignes.append("local function testsNoyau()")
            lignes += ["\t" + l if l else l for l in noyau.splitlines()]
            lignes.append("end")
        else:
            lignes.append(ligne)
    return "\n".join(lignes) + "\n"


def commande_tester(args) -> int:
    exp = experience()
    publication = json.loads(DERNIERE_PUBLICATION.read_text()) if DERNIERE_PUBLICATION.exists() else {}
    version = args.version or publication.get("versionNumber")
    map_nom = args.map or publication.get("map") or "iles-celestes"
    script = assembler_script(map_nom, version)
    if len(script.encode()) > 4 * 1024 * 1024:
        sys.exit("✖ Script de test > 4 Mo (limite Luau Execution).")
    base = f"{API}/cloud/v2/universes/{exp['universeId']}/places/{exp['placeId']}"
    url = f"{base}/versions/{version}/luau-execution-session-tasks" if version else f"{base}/luau-execution-session-tasks"
    print(f"▶ Tests dans le vrai moteur Roblox — place {exp['placeId']}, version {version or 'la plus récente'}")
    tache = requete("POST", url, json_corps={"script": script, "timeout": "300s"}, rejouable=False)
    chemin = tache["path"]
    print(f"  tâche : {chemin}")
    debut = time.time()
    while tache.get("state") not in ("COMPLETE", "FAILED", "CANCELLED"):
        time.sleep(3)
        tache = requete("GET", f"{API}/cloud/v2/{chemin}")
        print(f"  … {tache.get('state')} ({time.time() - debut:.0f} s)")

    journaux = []
    for page in [requete("GET", f"{API}/cloud/v2/{chemin}/logs?maxPageSize=10000")]:
        for bloc in page.get("luauExecutionSessionTaskLogs") or []:
            journaux += bloc.get("messages") or []
    print("──── Journal du serveur Roblox")
    for ligne in journaux:
        print("  " + ligne)
    print("────")

    sortie = tache.get("output") or {}
    resultats = (sortie.get("results") or [None])[0] if isinstance(sortie, dict) else None
    rapport = {
        "date": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "placeId": exp["placeId"],
        "versionTestee": version,
        "map": map_nom,
        "tache": chemin,
        "etat": tache.get("state"),
        "erreur": tache.get("error"),
        "resultats": resultats,
        "journal": journaux,
    }
    RAPPORTS.mkdir(exist_ok=True)
    (RAPPORTS / f"{map_nom}-moteur-reel.json").write_text(json.dumps(rapport, indent=1, ensure_ascii=False) + "\n")
    ecrire_rapport_md(rapport, RAPPORTS / f"{map_nom}-moteur-reel.md")

    if tache.get("state") != "COMPLETE":
        print(f"✖ Tâche {tache.get('state')} : {json.dumps(tache.get('error'), ensure_ascii=False)}")
        return 1
    if not isinstance(resultats, dict):
        print(f"✖ Sortie inattendue : {json.dumps(sortie, ensure_ascii=False)[:1000]}")
        return 1
    print(
        f"{resultats.get('reussis')} réussi(s), {resultats.get('echoues')} échoué(s), "
        f"{resultats.get('ignores')} non vérifiable(s) dans cet environnement"
    )
    print(f"Rapport : reports/{map_nom}-moteur-reel.md")
    return 0 if resultats.get("echoues") == 0 else 1


def ecrire_rapport_md(rapport: dict, chemin: pathlib.Path) -> None:
    res = rapport.get("resultats") or {}
    symboles = {"ok": "✅", "echec": "❌", "ignore": "⚪"}
    lignes = [
        f"# Tests dans le vrai moteur Roblox — {rapport['map']}",
        "",
        f"- Date : {rapport['date']}",
        f"- Place : [{rapport['placeId']}](https://www.roblox.com/games/{rapport['placeId']}), "
        f"version testée : {rapport['versionTestee'] or 'la plus récente'}",
        f"- Tâche Luau Execution : `{rapport['tache']}` — état : **{rapport['etat']}**",
    ]
    if rapport.get("erreur"):
        lignes.append(f"- Erreur : `{json.dumps(rapport['erreur'], ensure_ascii=False)}`")
    if res:
        lignes += [
            f"- **{res.get('reussis')} réussi(s), {res.get('echoues')} échoué(s), "
            f"{res.get('ignores')} non vérifiable(s)** dans cet environnement",
            "",
            "| | Groupe | Test | Détail |",
            "|---|---|---|---|",
        ]
        for t in res.get("tests") or []:
            detail = str(t.get("detail") or "").replace("|", "\\|").replace("\n", " ")
            lignes.append(f"| {symboles.get(t.get('statut'), '?')} | {t.get('groupe')} | {t.get('nom')} | {detail} |")
        if res.get("mesures"):
            lignes += ["", "## Mesures dans le vrai moteur", "", "| Mesure | Valeur |", "|---|---|"]
            for k in sorted(res["mesures"]):
                lignes.append(f"| {k} | {res['mesures'][k]} |")
    lignes += [
        "",
        "---",
        "_Généré par `python3 pipeline/opencloud.py tester` (API Open Cloud « Luau Execution »). "
        "Dans cet environnement, d'après la documentation Roblox, la physique ne tourne pas et les scripts de la "
        "place ne démarrent pas d'eux-mêmes ; il n'y a pas de vrai joueur. Le parcours joueur complet reste couvert "
        "par les tests d'intégration du moteur simulé (`pipeline/tests/integration.test.luau`)._",
    ]
    chemin.write_text("\n".join(lignes) + "\n")


def main() -> int:
    analyseur = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sous = analyseur.add_subparsers(dest="commande", required=True)
    sous.add_parser("cle").set_defaults(fonction=commande_cle)
    sous.add_parser("boutique").set_defaults(fonction=commande_boutique)
    p = sous.add_parser("publier")
    p.add_argument("fichier")
    p.set_defaults(fonction=commande_publier)
    t = sous.add_parser("tester")
    t.add_argument("--version", type=int)
    t.add_argument("--map")
    t.set_defaults(fonction=commande_tester)
    args = analyseur.parse_args()
    os.chdir(RACINE)
    try:
        return args.fonction(args)
    except ErreurApi as e:
        print(f"✖ Erreur de l'API Roblox : {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
