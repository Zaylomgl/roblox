# Lance un script Luau dans le vrai moteur sur la place Givrecendre (lecture seule).
# Usage : python3 rpg/tests/lancer.py rpg/tests/arene-ogre.luau
import sys, json, time
import pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "pipeline"))
import opencloud as oc
script = open(sys.argv[1]).read()
base = f"{oc.API}/cloud/v2/universes/10774188905/places/85466448220573"
t = oc.requete("POST", f"{base}/luau-execution-session-tasks", json_corps={"script": script, "timeout": "300s"}, rejouable=False)
while t.get("state") not in ("COMPLETE","FAILED","CANCELLED"):
    time.sleep(3); t = oc.requete("GET", f"{oc.API}/cloud/v2/{t['path']}")
logs = oc.requete("GET", f"{oc.API}/cloud/v2/{t['path']}/logs?maxPageSize=10000")
for b in logs.get("luauExecutionSessionTaskLogs") or []:
    for m in b.get("messages") or []: print(m)
print("ETAT", t.get("state"), json.dumps(t.get("error")), json.dumps(t.get("output"), ensure_ascii=False)[:3000])
