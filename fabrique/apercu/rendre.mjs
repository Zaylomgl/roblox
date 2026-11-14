// Aperçu en images d'un jeu de la Fabrique.
//
// Usage : node fabrique/apercu/rendre.mjs build/<nom>/scene.json jeux/apercus/<nom>.jpg
//
// Écrit UNE image : une planche de quatre vues (ensemble, départ, une étape, arrivée).
//
// RENDU APPROXIMATIF : three.js dans Chromium, pas le moteur Roblox. Formes,
// couleurs, proportions et composition sont fidèles ; les matériaux, l'éclairage
// (lumières ponctuelles, bloom, atmosphère, nuages) et les particules ne le sont pas.
import { createServer } from "node:http";
import { readFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const ici = dirname(fileURLToPath(import.meta.url));
const [cheminScene, sortie] = process.argv.slice(2);
if (!cheminScene || !sortie) {
	console.error("Usage : node fabrique/apercu/rendre.mjs <scene.json> <planche.jpg>");
	process.exit(2);
}
const scene = await readFile(cheminScene, "utf8");
const three = await readFile(join(ici, "node_modules/three/build/three.module.min.js"));

const PAGE = `<!doctype html><meta charset="utf-8"><style>html,body{margin:0;overflow:hidden;background:#000}</style>
<script type="importmap">{"imports":{"three":"/three.js"}}</script>
<script type="module">
import * as THREE from "three";
const scene = await (await fetch("/scene.json")).json();
const L = scene.lumiere;
const couleur = (c) => new THREE.Color(c[0], c[1], c[2]);

const rendu = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
rendu.setSize(innerWidth, innerHeight);
rendu.setPixelRatio(devicePixelRatio);
rendu.autoClear = false;
rendu.setScissorTest(true);
rendu.shadowMap.enabled = true;
rendu.shadowMap.type = THREE.PCFSoftShadowMap;
rendu.toneMapping = THREE.ACESFilmicToneMapping;
rendu.toneMappingExposure = 1.05;
document.body.appendChild(rendu.domElement);

const monde = new THREE.Scene();
const brume = couleur(L.brume);
const nuit = L.heure < 5.5 || L.heure > 19;
const ciel = brume.clone().lerp(couleur(L.declin), 0.35);
monde.background = ciel;
monde.fog = new THREE.FogExp2(ciel, 0.0003 + L.densite * 0.0012);

monde.add(new THREE.HemisphereLight(couleur(L.exterieur).multiplyScalar(2.2), couleur(L.ambiance).multiplyScalar(1.2), 1.4));
const angle = ((L.heure - 6) / 12) * Math.PI;
const soleil = new THREE.DirectionalLight(nuit ? 0x8899ff : 0xfff2dd, nuit ? 0.9 : Math.min(3.2, L.luminosite * 1.1));
const direction = nuit ? new THREE.Vector3(0.4, 0.8, 0.3) : new THREE.Vector3(Math.cos(angle), Math.max(0.25, Math.sin(angle)), 0.45).normalize();
soleil.castShadow = true;
soleil.shadow.mapSize.set(4096, 4096);
soleil.shadow.bias = -0.0005;
monde.add(soleil, soleil.target);

const geometries = new Map();
function geometrie(p) {
	const cle = p.f + p.s.join("x");
	if (geometries.has(cle)) return geometries.get(cle);
	let g;
	if (p.f === "Ball") g = new THREE.SphereGeometry(p.s[0] / 2, 20, 14);
	else if (p.f === "Cylinder") { g = new THREE.CylinderGeometry(p.s[1] / 2, p.s[1] / 2, p.s[0], 28); g.rotateZ(Math.PI / 2); }
	else if (p.f === "CornerWedge" || p.f === "Wedge") {
		// Orientations vérifiées dans le vrai moteur : coin → sommet en (+X, +Y, -Z) ; rampe → haute côté +Z.
		const [x, y, z] = p.s.map((v) => v / 2);
		const A = [x, -y, -z], B = [x, -y, z], C = [-x, -y, z], D = [-x, -y, -z];
		const faces = p.f === "CornerWedge"
			? ((S) => [[A, B, C], [A, C, D], [S, A, B], [S, D, A], [S, B, C], [S, C, D]])([x, y, -z])
			: ((H1, H2) => [[A, B, C], [A, C, D], [B, H1, H2], [B, H2, C], [A, H1, B], [D, C, H2], [A, D, H2], [A, H2, H1]])([x, y, z], [-x, y, z]);
		g = new THREE.BufferGeometry();
		g.setAttribute("position", new THREE.Float32BufferAttribute(faces.flat(2), 3));
		g.computeVertexNormals();
	}
	else g = new THREE.BoxGeometry(p.s[0], p.s[1], p.s[2]);
	geometries.set(cle, g);
	return g;
}
const RUGOSITE = { Metal: 0.35, DiamondPlate: 0.4, Glass: 0.1, Ice: 0.15, Glacier: 0.25, SmoothPlastic: 0.45, Plastic: 0.5, Foil: 0.2 };
const materiaux = new Map();
function materiau(p) {
	const cle = p.m + p.k.join(",") + p.t + (p.f === "CornerWedge" || p.f === "Wedge");
	if (materiaux.has(cle)) return materiaux.get(cle);
	const c = couleur(p.k);
	let m;
	if (p.m === "Neon") m = new THREE.MeshBasicMaterial({ color: c, toneMapped: false });
	else if (p.m === "ForceField") m = new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: 0.3, depthWrite: false, toneMapped: false });
	else m = new THREE.MeshStandardMaterial({ color: c, roughness: RUGOSITE[p.m] ?? 0.85, metalness: p.m === "Metal" || p.m === "DiamondPlate" ? 0.5 : 0, side: THREE.DoubleSide, flatShading: p.f === "CornerWedge" || p.f === "Wedge" });
	if (p.t > 0 && p.m !== "ForceField") { m.transparent = true; m.opacity = 1 - p.t; m.depthWrite = p.t < 0.5; }
	materiaux.set(cle, m);
	return m;
}
const boite = new THREE.Box3();
for (const p of scene.pieces) {
	const maille = new THREE.Mesh(geometrie(p), materiau(p));
	const c = p.c;
	maille.matrixAutoUpdate = false;
	maille.matrix.set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
	const grand = Math.max(...p.s) > 500;
	maille.castShadow = p.o && !grand && p.t < 0.5 && p.m !== "Neon";
	maille.receiveShadow = p.m !== "Neon";
	monde.add(maille);
	if (!grand) boite.expandByPoint(new THREE.Vector3(c[0], c[1], c[2]));
}

const camera = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 0.5, 6000);
window.photo = (position, cible, champ, case_) => {
	// Chaque vue occupe un quart de l'image (grille 2 × 2, de gauche à droite puis de haut en bas).
	const l = innerWidth / 2, h = innerHeight / 2;
	const x = (case_ % 2) * l, y = (1 - Math.floor(case_ / 2)) * h;
	rendu.setViewport(x, y, l, h);
	rendu.setScissor(x, y, l, h);
	rendu.clear();
	camera.aspect = l / h;
	camera.fov = champ || 60;
	camera.updateProjectionMatrix();
	camera.position.set(...position);
	camera.lookAt(...cible);
	const portee = Math.max(120, camera.position.distanceTo(new THREE.Vector3(...cible)) * 1.4);
	soleil.target.position.set(...cible);
	soleil.position.copy(soleil.target.position).addScaledVector(direction, portee * 2);
	Object.assign(soleil.shadow.camera, { left: -portee, right: portee, top: portee, bottom: -portee, near: 1, far: portee * 5 });
	soleil.shadow.camera.updateProjectionMatrix();
	rendu.render(monde, camera);
};
window.boite = { min: boite.min.toArray(), max: boite.max.toArray() };
window.reperes = scene.reperes;
window.format = scene.format;
window.pret = true;
</script>`;

const serveur = createServer((requete, reponse) => {
	if (requete.url === "/three.js") reponse.writeHead(200, { "content-type": "text/javascript" }).end(three);
	else if (requete.url === "/scene.json") reponse.writeHead(200, { "content-type": "application/json" }).end(scene);
	else reponse.writeHead(200, { "content-type": "text/html" }).end(PAGE);
});
await new Promise((ok) => serveur.listen(0, "127.0.0.1", ok));

const navigateur = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });
const page = await navigateur.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 2 });
page.on("pageerror", (e) => console.error("Erreur dans la page :", e.message));
await page.goto(`http://127.0.0.1:${serveur.address().port}/`);
await page.waitForFunction("window.pret === true", null, { timeout: 120000 });

const { boite, reperes, format } = await page.evaluate("({ boite: window.boite, reperes: window.reperes, format: window.format })");
const centre = boite.min.map((v, i) => (v + boite.max[i]) / 2);
const etendue = Math.max(boite.max[0] - boite.min[0], boite.max[2] - boite.min[2]);
const hauteur = boite.max[1] - boite.min[1];
const etapes = Object.keys(reperes.etapes || {}).map(Number).sort((a, b) => a - b);
const milieu = reperes.etapes[etapes[Math.floor(etapes.length / 2)]] || centre;
const d = reperes.depart || centre;
const a = reperes.arrivee || centre;
const vers = (p, q) => { const v = [q[0] - p[0], 0, q[2] - p[2]]; const n = Math.hypot(v[0], v[2]) || 1; return [v[0] / n, 0, v[2] / n]; };

// Prises de vue : ensemble, départ (ce que voit le joueur en arrivant), une étape, l'arrivée.
const vues = {};
if (format === "tour") {
	const recul = Math.max(etendue * 0.62, hauteur * 1.1);
	vues["1-ensemble"] = [[centre[0] + recul, centre[1] + hauteur * 0.25, centre[2] + recul * 0.75], [centre[0], centre[1] + hauteur * 0.05, centre[2]], 55];
	const versCentre = vers(d, [0, 0, 0]);
	vues["2-depart"] = [[d[0] - versCentre[0] * 26 + 8, d[1] + 12, d[2] - versCentre[2] * 26 + 8], [d[0] + versCentre[0] * 30, d[1] + 22, d[2] + versCentre[2] * 30], 70];
	const dehors = vers([0, 0, 0], milieu);
	vues["3-etape"] = [[milieu[0] + dehors[0] * 30 + dehors[2] * 16, milieu[1] + 12, milieu[2] + dehors[2] * 30 - dehors[0] * 16], [milieu[0] - dehors[0] * 4, milieu[1] - 2, milieu[2] - dehors[2] * 4], 65];
	const dehorsFin = vers([0, 0, 0], a);
	vues["4-arrivee"] = [[a[0] + dehorsFin[0] * 34 - dehorsFin[2] * 14, a[1] + 14, a[2] + dehorsFin[2] * 34 + dehorsFin[0] * 14], [a[0], a[1] + 2, a[2]], 65];
} else {
	vues["1-ensemble"] = [[centre[0] + etendue * 0.3 + 150, centre[1] + 170, d[2] - 120], [centre[0], centre[1] - 20, centre[2] - etendue * 0.12], 55];
	vues["2-depart"] = [[d[0] + 3, d[1] + 8, d[2] - 5], [d[0] - 1, d[1] + 3, d[2] + 60], 80];
	vues["3-etape"] = [[milieu[0] + 22, milieu[1] + 14, milieu[2] - 40], [milieu[0], milieu[1], milieu[2] + 16], 68];
	vues["4-arrivee"] = [[a[0] + 26, a[1] + 16, a[2] - 52], [a[0], a[1] + 5, a[2] + 6], 62];
}

// Mode « détails » (3e argument) : gros plans sur une gemme, la coupe, une relique et une borne.
if (process.argv[4] === "details") {
	for (const cle of Object.keys(vues)) delete vues[cle];
	const g = reperes.gemme || centre, c = reperes.coupe || centre, r = reperes.relique || centre, e = reperes.etapes[etapes[0]] || centre;
	vues["1-gemme"] = [[g[0] + 7, g[1] + 3, g[2] + 9], [g[0], g[1] - 1.5, g[2]], 50];
	vues["2-coupe"] = [[c[0] + 7, c[1] + 2.5, c[2] + 8], [c[0], c[1] - 1, c[2]], 50];
	vues["3-relique"] = [[r[0] + 9, r[1] + 1, r[2] + 9], [r[0], r[1], r[2]], 55];
	vues["4-borne"] = [[e[0] + 16, e[1] + 6, e[2] + 18], [e[0], e[1] - 2, e[2]], 60];
}

await mkdir(dirname(sortie), { recursive: true });
let case_ = 0;
for (const [position, cible, champ] of Object.values(vues)) {
	await page.evaluate(([p, c, f, n]) => window.photo(p, c, f, n), [position, cible, champ, case_]);
	case_ += 1;
}
await page.screenshot({ path: sortie, type: "jpeg", quality: 82 });
console.log(`✔ ${sortie}`);
await navigateur.close();
serveur.close();
