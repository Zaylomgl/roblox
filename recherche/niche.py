#!/usr/bin/env python3
"""
Recherche de niche Roblox à partir des classements officiels de la page Découvrir.

Source : https://apis.roblox.com/explore-api/v1/get-sorts (l'API qu'utilise la
page « Découvrir » de Roblox). Chaque classement liste ~80-100 jeux avec leur
genre (genreL1), le nombre de joueurs connectés et les votes.

Usage :
    python3 recherche/niche.py              # nouvelle photo + rapport
    python3 recherche/niche.py --sans-reseau  # rapport à partir des photos déjà enregistrées

Chaque lancement enregistre une photo horodatée dans recherche/donnees/ :
plusieurs photos sur plusieurs jours/heures donnent une vision plus fiable
qu'un instantané (les classements bougent selon l'heure et le jour).

Bibliothèque standard uniquement.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import pathlib
import re
import statistics
import sys
import urllib.request
import uuid

RACINE = pathlib.Path(__file__).resolve().parent
DONNEES = RACINE / "donnees"
URL = "https://apis.roblox.com/explore-api/v1/get-sorts?sessionId={session}&device={appareil}&country={pays}"

# Appareils proposés par le filtre de la page Découvrir (valeurs lues dans la réponse de l'API).
APPAREILS = ["computer", "high_end_phone", "low_end_phone", "high_end_tablet", "console"]

CLASSEMENTS = {
    "top-trending": "Tendances",
    "up-and-coming": "En pleine ascension",
    "top-playing-now": "Les plus joués maintenant",
    "fun-with-friends": "Entre amis",
    "top-revisited": "Les plus revisités",
}

# Mots trop courants pour signaler un « format » de jeu.
MOTS_VIDES = {
    "a", "an", "the", "of", "to", "and", "or", "in", "on", "for", "with", "my", "your", "is", "be",
    "x", "vs", "new", "update", "upd", "beta", "alpha", "release", "event", "free", "de", "la", "le",
}


def telecharger(appareil: str, pays: str = "all") -> dict:
    url = URL.format(session=uuid.uuid4(), appareil=appareil, pays=pays)
    with urllib.request.urlopen(url, timeout=30) as reponse:
        return json.loads(reponse.read())


def prendre_photo() -> pathlib.Path:
    """Télécharge tous les classements pour chaque appareil et enregistre une photo datée."""
    maintenant = dt.datetime.now(dt.timezone.utc)
    photo = {"date_utc": maintenant.isoformat(timespec="seconds"), "source": URL.split("?")[0], "appareils": {}}
    for appareil in APPAREILS:
        try:
            brut = telecharger(appareil)
        except Exception as erreur:  # noqa: BLE001 - on garde les autres appareils
            print(f"  ! {appareil} : échec ({erreur})", file=sys.stderr)
            continue
        classements = {}
        for tri in brut.get("sorts", []):
            if tri.get("sortId") in CLASSEMENTS and tri.get("games"):
                classements[tri["sortId"]] = [
                    {
                        "universeId": j["universeId"],
                        "nom": j["name"],
                        "genre": j.get("genreL1") or "(inconnu)",
                        "joueurs": j.get("playerCount", 0),
                        "pour": j.get("totalUpVotes", 0),
                        "contre": j.get("totalDownVotes", 0),
                        "sponsorise": j.get("isSponsored", False),
                        "maturite": j.get("contentMaturity"),
                    }
                    for j in tri["games"]
                ]
        photo["appareils"][appareil] = classements
        print(f"  ✔ {appareil} : " + ", ".join(f"{k}={len(v)}" for k, v in classements.items()))
    DONNEES.mkdir(parents=True, exist_ok=True)
    chemin = DONNEES / f"{maintenant.strftime('%Y-%m-%dT%H%MZ')}.json"
    chemin.write_text(json.dumps(photo, ensure_ascii=False, separators=(",", ":")))
    return chemin


def charger_photos() -> list[dict]:
    return [json.loads(p.read_text()) for p in sorted(DONNEES.glob("*.json"))]


def ratio(j: dict) -> float | None:
    total = j["pour"] + j["contre"]
    return j["pour"] / total if total >= 50 else None


def analyser(photos: list[dict]) -> dict:
    """Agrège toutes les photos : un jeu compte une fois par classement où il apparaît."""
    jeux: dict[int, dict] = {}
    presence = collections.defaultdict(lambda: collections.defaultdict(int))  # univers -> classement -> nb d'apparitions
    joueurs_max = collections.defaultdict(int)
    nb_observations = 0
    for photo in photos:
        for appareil, classements in photo["appareils"].items():
            nb_observations += 1
            for tri, liste in classements.items():
                for j in liste:
                    if j.get("sponsorise"):
                        continue  # une place achetée ne dit rien de la demande
                    u = j["universeId"]
                    jeux[u] = j
                    presence[u][tri] += 1
                    joueurs_max[u] = max(joueurs_max[u], j["joueurs"])

    genres = collections.defaultdict(lambda: {"jeux": set(), "joueurs": 0, "ratios": [], "par_classement": collections.Counter()})
    for u, j in jeux.items():
        g = genres[j["genre"]]
        g["jeux"].add(u)
        g["joueurs"] += joueurs_max[u]
        r = ratio(j)
        if r is not None:
            g["ratios"].append(r)
        for tri in presence[u]:
            g["par_classement"][tri] += 1

    total_joueurs = sum(joueurs_max.values()) or 1
    lignes = []
    for nom, g in genres.items():
        joueurs_par_jeu = sorted((joueurs_max[u] for u in g["jeux"]), reverse=True)
        top1 = joueurs_par_jeu[0] if joueurs_par_jeu else 0
        lignes.append(
            {
                "genre": nom,
                "jeux": len(g["jeux"]),
                "joueurs": g["joueurs"],
                "part_joueurs": g["joueurs"] / total_joueurs,
                # Part du n°1 dans les joueurs du genre : proche de 1 = genre dominé par un seul jeu.
                "concentration_top1": top1 / g["joueurs"] if g["joueurs"] else 0,
                "mediane_joueurs_par_jeu": statistics.median(joueurs_par_jeu) if joueurs_par_jeu else 0,
                "ratio_votes_median": statistics.median(g["ratios"]) if g["ratios"] else None,
                "ascension": g["par_classement"]["up-and-coming"],
                "revisites": g["par_classement"]["top-revisited"],
                "tendances": g["par_classement"]["top-trending"],
            }
        )
    lignes.sort(key=lambda l: l["joueurs"], reverse=True)

    # Formats émergents : mots fréquents dans les noms des jeux « en pleine ascension ».
    mots = collections.Counter()
    exemples = collections.defaultdict(list)
    for u, j in jeux.items():
        if presence[u].get("up-and-coming"):
            nom_propre = re.sub(r"\[[^\]]*\]|\([^)]*\)|[^\w\s']", " ", j["nom"].lower())
            vus = set()
            for mot in nom_propre.split():
                if len(mot) >= 3 and mot not in MOTS_VIDES and not mot.isdigit() and mot not in vus:
                    vus.add(mot)
                    mots[mot] += 1
                    if len(exemples[mot]) < 4:
                        exemples[mot].append(j["nom"])

    ascension = sorted(
        (jeux[u] | {"joueurs_max": joueurs_max[u]} for u in jeux if presence[u].get("up-and-coming")),
        key=lambda j: j["joueurs_max"],
        reverse=True,
    )
    revisites = sorted(
        (jeux[u] | {"joueurs_max": joueurs_max[u]} for u in jeux if presence[u].get("top-revisited")),
        key=lambda j: j["joueurs_max"],
        reverse=True,
    )
    return {
        "photos": len(photos),
        "observations": nb_observations,
        "periode": (photos[0]["date_utc"], photos[-1]["date_utc"]) if photos else None,
        "jeux_uniques": len(jeux),
        "genres": lignes,
        "mots_ascension": [(m, n, exemples[m]) for m, n in mots.most_common(25) if n >= 2],
        "ascension": ascension[:30],
        "revisites": revisites[:30],
    }


def pct(x: float | None) -> str:
    return "—" if x is None else f"{x * 100:.0f} %"


def ecrire_rapport(a: dict) -> pathlib.Path:
    L = []
    L.append("# Recherche de niche Roblox — classements de la page Découvrir")
    L.append("")
    L.append(f"- Source : `apis.roblox.com/explore-api/v1/get-sorts` (données officielles Roblox, tous pays).")
    L.append(f"- Photos analysées : **{a['photos']}** ({a['observations']} relevés appareil × photo), période {a['periode'][0]} → {a['periode'][1]}.")
    L.append(f"- Jeux uniques (hors sponsorisés) : **{a['jeux_uniques']}**.")
    L.append("- ⚠️ Une seule photo = un instantané. Relancer le script plusieurs jours à des heures différentes pour fiabiliser.")
    L.append("")
    L.append("## Genres")
    L.append("")
    L.append("| Genre | Jeux classés | Joueurs connectés (somme des pics) | Part | Joueurs du n°1 / genre | Médiane joueurs/jeu | Votes positifs (médiane) | En ascension | Revisités | Tendances |")
    L.append("|---|---|---|---|---|---|---|---|---|---|")
    for g in a["genres"]:
        L.append(
            f"| {g['genre']} | {g['jeux']} | {g['joueurs']:,} | {pct(g['part_joueurs'])} | {pct(g['concentration_top1'])} | "
            f"{int(g['mediane_joueurs_par_jeu']):,} | {pct(g['ratio_votes_median'])} | {g['ascension']} | {g['revisites']} | {g['tendances']} |".replace(",", " ")
        )
    L.append("")
    L.append("Lecture :")
    L.append("- **Joueurs du n°1 / genre** proche de 100 % : genre dominé par un seul jeu, difficile d'y percer.")
    L.append("- **En ascension** élevé : des jeux récents y percent en ce moment, le marché est ouvert.")
    L.append("- **Revisités** élevé : les joueurs y reviennent, signe de bonne rétention.")
    L.append("")
    L.append("## Formats qui montent (mots fréquents dans les noms des jeux « En pleine ascension »)")
    L.append("")
    L.append("| Mot | Nb de jeux | Exemples |")
    L.append("|---|---|---|")
    for mot, n, ex in a["mots_ascension"]:
        L.append(f"| {mot} | {n} | {' · '.join(e.replace('|', '/') for e in ex)} |")
    L.append("")
    for titre, cle in (("Jeux « En pleine ascension »", "ascension"), ("Jeux « Les plus revisités »", "revisites")):
        L.append(f"## {titre} (30 plus gros)")
        L.append("")
        L.append("| Jeu | Genre | Joueurs (pic) | Votes positifs | Universe ID |")
        L.append("|---|---|---|---|---|")
        for j in a[cle]:
            L.append(f"| {j['nom'].replace('|', '/')} | {j['genre']} | {j['joueurs_max']:,} | {pct(ratio(j))} | {j['universeId']} |".replace(",", " "))
        L.append("")
    chemin = RACINE / "rapport-niche.md"
    chemin.write_text("\n".join(L) + "\n")
    (RACINE / "rapport-niche.json").write_text(json.dumps(a, ensure_ascii=False, indent=1, default=list))
    return chemin


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sans-reseau", action="store_true", help="ne pas télécharger de nouvelle photo")
    args = parser.parse_args()
    if not args.sans_reseau:
        print("▶ Photo des classements Roblox")
        print(f"  → {prendre_photo().relative_to(RACINE.parent)}")
    photos = charger_photos()
    if not photos:
        sys.exit("✖ Aucune photo dans recherche/donnees/ (lancer sans --sans-reseau).")
    rapport = ecrire_rapport(analyser(photos))
    print(f"✔ Rapport : {rapport.relative_to(RACINE.parent)}")


if __name__ == "__main__":
    main()
