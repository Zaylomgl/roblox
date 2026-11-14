--[[
	Tests de la Fabrique (fabrique/) : choix d'après les tendances, assemblage,
	et surtout les jeux générés eux-mêmes.

	Chaque combinaison format × thème est générée en mémoire, construite dans
	l'environnement Roblox simulé, puis passée au validateur : tous les
	collectibles (dont le trophée d'arrivée) doivent être atteignables depuis
	l'unique point d'apparition. Le parcours joueur complet (étapes, mort,
	réapparition, victoire, sauvegarde) est rejoué dans le moteur simulé.

	Ces tests ne dépendent pas de l'apparence (couleurs, nombre exact de pièces).
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Moteur = require("../lib/moteur")
local analyse = require("../lib/analyse")
local assemblage = require("../../fabrique/lib/assemblage")
local config = require("../config")
local formats = require("../../fabrique/formats")
local injection = require("../lib/injection")
local rbxenv = require("../lib/rbxenv")
local tendancesLib = require("../../fabrique/lib/tendances")
local themes = require("../../fabrique/themes")

local M = {}

local JOUR = 86400

local function parCle(liste, cle: string)
	for _, element in liste do
		if element.cle == cle then
			return element
		end
	end
	error(`inconnu : {cle}`)
end

-- Script de construction d'un jeu, généré en mémoire (rien n'est écrit sur le disque).
local function scriptDuJeu(formatCle: string, themeCle: string, graine: number, etapes: number): string
	local format = parCle(formats, formatCle)
	return assemblage.assembler({
		nom = `test-{formatCle}-{themeCle}`,
		titre = "Jeu de test",
		format = format.cle,
		gabarit = format.gabarit,
		graine = graine,
		etapes = etapes,
		theme = parCle(themes, themeCle),
		source = "test",
	}, "fabrique/gabarits")
end

-- Place construite comme par le pipeline : script de construction, puis noyau commun (src/).
local function construirePlace(source: string)
	local env, game = rbxenv.creer({ silencieux = true })
	luau.load(source, { debugName = "jeu-de-test", environment = env })()
	injection.injecter(game, "src")
	return game
end

local function constructibles()
	local liste = {}
	for _, format in formats do
		if format.gabarit then
			table.insert(liste, format)
		end
	end
	return liste
end

local function parcours(game)
	return game:GetService("Workspace").Parcours
end

local function positionsGemmes(game): string
	local textes = {}
	for _, gemme in parcours(game).Collectibles:GetChildren() do
		local p = gemme.CFrame.Position
		table.insert(textes, string.format("%.2f/%.2f/%.2f", p.X, p.Y, p.Z))
	end
	table.sort(textes)
	return table.concat(textes, " ")
end

--------------------------------------------------------------------------------
-- Tendances
--------------------------------------------------------------------------------

local TENDANCES = { mots = { tower = 15, obby = 6, escape = 14, prison = 9, run = 9, steal = 25 } }

M["tendances : le score d'un format est la somme des occurrences de ses mots (mot absent = 0)"] = function(t)
	local score, detail = tendancesLib.score(TENDANCES, { "tower", "climb", "obby" })
	t.egal(score, 21)
	t.egal(detail[2].mot, "climb")
	t.egal(detail[2].jeux, 0)
end

M["tendances : formats classés par score décroissant"] = function(t)
	local classement = tendancesLib.classerFormats(TENDANCES, formats)
	for i = 2, #classement do
		t.vrai(classement[i - 1].score >= classement[i].score)
	end
	t.egal(classement[1].format.cle, "evasion")
end

M["tendances : jamais de format que la Fabrique ne sait pas construire"] = function(t)
	-- « steal » domine largement, mais le format « vol » n'a pas de gabarit.
	local dominees = { mots = { steal = 500, tower = 1 } }
	for graine = 1, 20 do
		local format = tendancesLib.choisir(dominees, formats, themes, {}, graine)
		t.vrai(format.gabarit ~= nil)
	end
end

M["tendances : les formats alternent et les thèmes ne se répètent pas avant d'avoir tous servi"] = function(t)
	local catalogue = {}
	local parFormat, parTheme, combinaisons = {}, {}, {}
	for i = 1, #themes do
		local format, theme = tendancesLib.choisir(TENDANCES, formats, themes, catalogue, 100 + i)
		table.insert(catalogue, { format = format.cle, theme = theme.cle })
		parFormat[format.cle] = (parFormat[format.cle] or 0) + 1
		parTheme[theme.cle] = (parTheme[theme.cle] or 0) + 1
		t.faux(combinaisons[format.cle .. "/" .. theme.cle])
		combinaisons[format.cle .. "/" .. theme.cle] = true
	end
	t.egal(catalogue[1].format, "evasion") -- la tendance la plus forte d'abord
	t.egal(catalogue[1].theme, "prison") -- « prison » est le seul thème présent dans ces tendances
	t.egal(catalogue[2].format, "tour") -- 21 > 38 / 2
	t.vrai((parFormat.tour or 0) >= 2)
	for _, theme in themes do
		t.egal(parTheme[theme.cle], 1)
	end
end

M["tendances : même graine, même choix"] = function(t)
	local f1, t1 = tendancesLib.choisir(TENDANCES, formats, themes, { { format = "evasion", theme = "prison" } }, 4242)
	local f2, t2 = tendancesLib.choisir(TENDANCES, formats, themes, { { format = "evasion", theme = "prison" } }, 4242)
	t.egal(f1.cle, f2.cle)
	t.egal(t1.cle, t2.cle)
end

--------------------------------------------------------------------------------
-- Assemblage
--------------------------------------------------------------------------------

M["assemblage : un littéral se recharge à l'identique"] = function(t)
	local valeur = {
		nombre = 12.5,
		negatif = -3,
		vrai = true,
		texte = 'guillemets " et \\ et\nretour à la ligne',
		liste = { 1, 2, 3 },
		imbrique = { couleurs = { sol = { 1, 2, 3 } }, mots = { "a", "b" }, objets = { { cle = "x" }, { cle = "y" } } },
	}
	local relu = luau.load("return " .. assemblage.litteral(valeur, ""), { debugName = "litteral" })()
	t.egal(relu.nombre, 12.5)
	t.egal(relu.negatif, -3)
	t.egal(relu.vrai, true)
	t.egal(relu.texte, valeur.texte)
	t.egal(#relu.liste, 3)
	t.egal(relu.imbrique.couleurs.sol[3], 3)
	t.egal(relu.imbrique.mots[2], "b")
	t.egal(relu.imbrique.objets[2].cle, "y")
end

--------------------------------------------------------------------------------
-- Jeux générés : toutes les combinaisons format × thème
--------------------------------------------------------------------------------

for _, format in constructibles() do
	for rang, theme in themes do
		M[`jeu généré {format.cle} × {theme.cle} : construit, sans erreur, tout est atteignable`] = function(t)
			local etapes = 4
			local game = construirePlace(scriptDuJeu(format.cle, theme.cle, 1000 + rang * 17, etapes))
			local rapport = analyse.analyser(game, "test")

			for _, probleme in rapport.problemes do
				if probleme.gravite ~= "info" then
					error(`{probleme.gravite} {probleme.code} : {probleme.message}`)
				end
			end
			t.vrai(rapport.accessibilite.collectiblesTotal >= 3 * etapes)
			t.egal(rapport.accessibilite.collectiblesAccessibles, rapport.accessibilite.collectiblesTotal)
			t.egal(rapport.statistiques.spawns, 1)
			t.egal(rapport.statistiques.piecesNonAncrees, 0)
			t.vrai(rapport.statistiques.pieces < config.SEUILS.PIECES_AVERTISSEMENT)

			local map = parcours(game)
			-- Bornes 1 à N-1, sans trou ; une zone d'arrivée ; un trophée à 25.
			local vues = {}
			for _, zone in map.Etapes:GetChildren() do
				vues[zone:GetAttribute("Numero")] = true
				t.faux(zone.CanCollide)
			end
			for n = 1, etapes - 1 do
				t.vrai(vues[n])
			end
			t.egal(#map.Etapes:GetChildren(), etapes - 1)
			t.vrai(map:FindFirstChild("Arrivee") ~= nil)
			t.egal(map:GetAttribute("NombreEtapes"), etapes)
			local trophees = 0
			for _, gemme in map.Collectibles:GetChildren() do
				if gemme:GetAttribute("Valeur") == 25 then
					trophees += 1
				end
			end
			t.egal(trophees, 1)
			-- Un danger solide serait pris pour un sol par le validateur (et bloquerait le joueur).
			for _, danger in map.Dangers:GetChildren() do
				t.faux(danger.CanCollide)
			end
			-- Roblox limite une pièce à 2048 studs de côté.
			for _, objet in map:GetDescendants() do
				if objet:IsA("BasePart") then
					t.vrai(math.max(objet.Size.X, objet.Size.Y, objet.Size.Z) <= 2048)
				end
			end
		end
	end
end

M["jeu généré : 14 étapes (le maximum accepté par fabrique/creer) reste valide et sous le seuil de pièces"] = function(
	t
)
	for _, format in constructibles() do
		local game = construirePlace(scriptDuJeu(format.cle, "glace", 5, 14))
		local rapport = analyse.analyser(game, "test")
		t.egal(rapport.resume.erreur, 0)
		t.egal(rapport.resume.avertissement, 0)
		t.egal(rapport.accessibilite.collectiblesAccessibles, rapport.accessibilite.collectiblesTotal)
	end
end

M["jeu généré : même graine → même parcours ; autre graine → autre parcours"] = function(t)
	for _, format in constructibles() do
		local a = positionsGemmes(construirePlace(scriptDuJeu(format.cle, "jungle", 31, 4)))
		local b = positionsGemmes(construirePlace(scriptDuJeu(format.cle, "jungle", 31, 4)))
		local c = positionsGemmes(construirePlace(scriptDuJeu(format.cle, "jungle", 32, 4)))
		t.egal(a, b)
		t.vrai(a ~= c)
	end
end

M["jeu généré : relancer le script remplace l'ancienne map au lieu de l'empiler"] = function(t)
	local source = scriptDuJeu("tour", "volcan", 9, 3)
	local env, game = rbxenv.creer({ silencieux = true })
	luau.load(source, { debugName = "jeu-de-test", environment = env })()
	luau.load(source, { debugName = "jeu-de-test", environment = env })()
	local nb = 0
	for _, enfant in game:GetService("Workspace"):GetChildren() do
		if enfant.Name == "Parcours" then
			nb += 1
		end
	end
	t.egal(nb, 1)
	local scripts = 0
	for _, enfant in game:GetService("ServerScriptService"):GetChildren() do
		if enfant.Name == "Parcours_Jeu" then
			scripts += 1
		end
	end
	t.egal(scripts, 1)
end

M["jeux du catalogue : chaque jeu a son script, sa fiche, et se régénère à l'identique"] = function(t)
	local serde = require("@lune/serde")
	local catalogue = serde.decode("json", fs.readFile("jeux/catalogue.json"))
	t.vrai(#catalogue >= 1)
	for _, jeu in catalogue do
		t.vrai(fs.isFile(`maps/{jeu.nom}.lua`))
		t.vrai(fs.isFile(`jeux/{jeu.nom}.md`))
		-- Le fichier versionné doit être exactement ce que produisent les gabarits actuels
		-- (sinon quelqu'un a modifié un gabarit sans régénérer, ou le fichier à la main).
		local format = parCle(formats, jeu.format)
		local attendu = assemblage.assembler({
			nom = jeu.nom,
			titre = jeu.titre,
			format = format.cle,
			gabarit = format.gabarit,
			graine = jeu.graine,
			etapes = jeu.etapes,
			theme = parCle(themes, jeu.theme),
			source = "",
		}, "fabrique/gabarits")
		local function sansSource(texte: string): string
			-- La ligne « Tendances : … » de l'en-tête dépend de la date de création.
			local lignes = string.split(texte, "\n")
			table.remove(lignes, 6)
			return table.concat(lignes, "\n")
		end
		if sansSource(fs.readFile(`maps/{jeu.nom}.lua`)) ~= sansSource(attendu) then
			error(
				`maps/{jeu.nom}.lua n'est plus à jour : lune run fabrique/creer -- --format {jeu.format} --theme {jeu.theme} --graine {jeu.graine} --etapes {jeu.etapes} --remplacer`
			)
		end
	end
end

--------------------------------------------------------------------------------
-- Parcours joueur dans le moteur simulé
--------------------------------------------------------------------------------

local ETAPES = 4

local function lancer(options: { noyau: boolean?, format: string?, saboter: ((string) -> string)? }?)
	local opts = options or {}
	local source = scriptDuJeu(opts.format or "tour", "volcan", 77, ETAPES)
	local env, game = rbxenv.creer({ silencieux = true })
	luau.load(source, { debugName = "jeu-de-test", environment = env })()
	if opts.saboter then
		local script = game:GetService("ServerScriptService").Parcours_Jeu
		local modifie = opts.saboter(script.Source)
		assert(modifie ~= script.Source, "le sabotage n'a rien changé")
		script.Source = modifie
	end
	if opts.noyau ~= false then
		injection.injecter(game, "src")
	end
	local moteur = Moteur.nouveau(game, { studio = false, debut = 20_000 * JOUR + 10 * 3600 })
	moteur:demarrerServeur()
	return moteur, game
end

local function sansErreur(moteur)
	if #moteur.erreurs > 0 then
		error("Erreurs d'exécution des scripts :\n" .. table.concat(moteur.erreurs, "\n---\n"), 2)
	end
end

local function stat(joueur, nom: string): number?
	local stats = joueur:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(nom)
	return v and v.Value
end

local function borne(game, numero: number)
	return parcours(game).Etapes:FindFirstChild("Etape" .. numero)
end

local function gemmeDe(game, valeur: number)
	for _, gemme in parcours(game).Collectibles:GetChildren() do
		if gemme:GetAttribute("Valeur") == valeur then
			return gemme
		end
	end
	error("pas de gemme de valeur " .. valeur)
end

local function racine(joueur)
	return joueur.Character:FindFirstChild("HumanoidRootPart")
end

M["parcours : arrivée du joueur, étape 0 et aucune victoire"] = function(t)
	local moteur = lancer()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	sansErreur(moteur)
	t.egal(stat(alice, "Étape"), 0)
	t.egal(stat(alice, "Victoires"), 0)
	t.egal(stat(alice, "Cristaux"), 0)
end

M["parcours : une gemme est créditée une seule fois, puis revient"] = function(t)
	local moteur, game = lancer()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	local gemme = gemmeDe(game, 5)
	moteur:toucher(gemme, alice)
	t.egal(stat(alice, "Cristaux"), 5)
	moteur:toucher(gemme, alice)
	t.egal(stat(alice, "Cristaux"), 5)
	moteur:avancer(30, 1)
	moteur:toucher(gemme, alice)
	t.egal(stat(alice, "Cristaux"), 10)
	sansErreur(moteur)
end

M["parcours : les bornes font monter l'étape et rapportent une seule fois"] = function(t)
	local moteur, game = lancer()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	moteur:toucher(borne(game, 1), alice)
	t.egal(stat(alice, "Étape"), 1)
	t.egal(stat(alice, "Cristaux"), 3)
	moteur:toucher(borne(game, 1), alice) -- déjà validée
	t.egal(stat(alice, "Cristaux"), 3)
	moteur:toucher(borne(game, 2), alice)
	t.egal(stat(alice, "Étape"), 2)
	t.egal(stat(alice, "Cristaux"), 6)
	moteur:toucher(borne(game, 1), alice) -- revenir en arrière ne fait pas reculer
	t.egal(stat(alice, "Étape"), 2)
	sansErreur(moteur)
end

M["parcours : un danger tue, et on réapparaît sur la dernière borne atteinte"] = function(t)
	local moteur, game = lancer()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	moteur:toucher(borne(game, 2), alice)
	local danger = parcours(game).Dangers:FindFirstChild("Vide")
	t.vrai(danger ~= nil)
	moteur:toucher(danger, alice)
	t.egal(alice.Character:FindFirstChildOfClass("Humanoid").Health, 0)

	moteur:reapparaitre(alice)
	moteur:avancer(1)
	local ecart = (racine(alice).CFrame.Position - borne(game, 2).CFrame.Position).Magnitude
	t.vrai(ecart < 6)
	t.egal(stat(alice, "Étape"), 2)
	sansErreur(moteur)
end

M["parcours : un mort ne valide ni borne ni gemme"] = function(t)
	local moteur, game = lancer()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	alice.Character:FindFirstChildOfClass("Humanoid").Health = 0
	moteur:toucher(borne(game, 1), alice)
	moteur:toucher(gemmeDe(game, 1), alice)
	t.egal(stat(alice, "Étape"), 0)
	t.egal(stat(alice, "Cristaux"), 0)
	sansErreur(moteur)
end

M["parcours : pas de victoire sans être passé par la dernière borne"] = function(t)
	local moteur, game = lancer()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	moteur:toucher(borne(game, 1), alice)
	moteur:toucher(parcours(game).Arrivee, alice)
	moteur:avancer(6)
	t.egal(stat(alice, "Victoires"), 0)
	t.egal(stat(alice, "Étape"), 1)
	sansErreur(moteur)
end

M["parcours : victoire comptée une fois, récompense, retour au départ, puis on peut regagner"] = function(t)
	local moteur, game = lancer()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	local map = parcours(game)
	for n = 1, ETAPES - 1 do
		moteur:toucher(borne(game, n), alice)
	end
	local avant = stat(alice, "Cristaux")
	moteur:toucher(map.Arrivee, alice)
	moteur:toucher(map.Arrivee, alice) -- on reste sur l'estrade : pas de deuxième victoire
	moteur:toucher(map.Arrivee, alice)
	t.egal(stat(alice, "Victoires"), 1)
	t.egal(stat(alice, "Étape"), 0)
	t.egal(stat(alice, "Cristaux"), avant + 50)
	moteur:toucher(borne(game, 1), alice) -- pendant la célébration, rien n'est validé
	t.egal(stat(alice, "Étape"), 0)

	moteur:avancer(6)
	local ecart = (racine(alice).CFrame.Position - map.Depart.CFrame.Position).Magnitude
	t.vrai(ecart < 8)

	for n = 1, ETAPES - 1 do
		moteur:toucher(borne(game, n), alice)
	end
	moteur:toucher(map.Arrivee, alice)
	t.egal(stat(alice, "Victoires"), 2)
	sansErreur(moteur)
end

M["parcours : étape et victoires sauvegardées, retrouvées au retour"] = function(t)
	local moteur, game = lancer()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	moteur:toucher(borne(game, 1), alice)
	moteur:toucher(borne(game, 2), alice)
	moteur:retirerJoueur(alice)
	moteur:avancer(2)
	local enregistrement = moteur.datastores.Joueurs_v1.donnees["joueur_1"]
	t.egal(enregistrement.donnees.jeu.parcours.etape, 2)

	local retour = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(3)
	t.egal(stat(retour, "Étape"), 2)
	-- Replacée sur sa borne dès que la sauvegarde est chargée, sans attendre de mourir.
	local ecart = (racine(retour).CFrame.Position - borne(game, 2).CFrame.Position).Magnitude
	t.vrai(ecart < 6)
	sansErreur(moteur)
end

M["parcours : deux joueurs ont chacun leur progression"] = function(t)
	local moteur, game = lancer()
	local alice = moteur:ajouterJoueur("Alice", 1)
	local bob = moteur:ajouterJoueur("Bob", 2)
	moteur:avancer(2)
	moteur:toucher(borne(game, 1), alice)
	moteur:toucher(borne(game, 2), alice)
	moteur:toucher(borne(game, 1), bob)
	t.egal(stat(alice, "Étape"), 2)
	t.egal(stat(bob, "Étape"), 1)
	sansErreur(moteur)
end

M["parcours : sans le noyau (script collé seul dans Studio), tout marche sans sauvegarde"] = function(t)
	local moteur, game = lancer({ noyau = false })
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	t.egal(stat(alice, "Étape"), 0)
	moteur:toucher(gemmeDe(game, 1), alice)
	t.egal(stat(alice, "Gemmes"), 1)
	for n = 1, ETAPES - 1 do
		moteur:toucher(borne(game, n), alice)
	end
	moteur:toucher(parcours(game).Arrivee, alice)
	t.egal(stat(alice, "Victoires"), 1)
	t.egal(stat(alice, "Gemmes"), 1 + 3 * (ETAPES - 1) + 50)
	sansErreur(moteur)
end

M["parcours : le format évasion suit les mêmes règles"] = function(t)
	local moteur, game = lancer({ format = "evasion" })
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	for n = 1, ETAPES - 1 do
		moteur:toucher(borne(game, n), alice)
	end
	moteur:toucher(parcours(game).Arrivee, alice)
	t.egal(stat(alice, "Victoires"), 1)
	moteur:avancer(10, 0.1) -- animations (barres, gemmes) sur une centaine d'images
	sansErreur(moteur)
end

M["pièges : une dalle fragile s'efface après le passage, puis revient"] = function(t)
	-- On cherche une graine dont le parcours contient des dalles fragiles.
	local moteur, game
	for graine = 1, 30 do
		local source = scriptDuJeu("evasion", "neon", graine, 5)
		local env, place = rbxenv.creer({ silencieux = true })
		luau.load(source, { debugName = "jeu-de-test", environment = env })()
		if #place:GetService("Workspace").Parcours.Fragiles:GetChildren() > 0 then
			moteur = Moteur.nouveau(place, { studio = false, debut = 20_000 * JOUR })
			moteur:demarrerServeur()
			game = place
			break
		end
	end
	t.vrai(game ~= nil)
	local alice = moteur:ajouterJoueur("Alice", 1)
	local dalle = parcours(game).Fragiles:GetChildren()[1]
	t.vrai(dalle.CanCollide)
	moteur:toucher(dalle, alice)
	moteur:avancer(1)
	t.faux(dalle.CanCollide)
	moteur:avancer(4)
	t.vrai(dalle.CanCollide)
	sansErreur(moteur)
end

M["pièges : les barres tournent et les tapis reçoivent leur vitesse"] = function(t)
	local moteur, game
	for graine = 1, 30 do
		local source = scriptDuJeu("evasion", "prison", graine, 5)
		local env, place = rbxenv.creer({ silencieux = true })
		luau.load(source, { debugName = "jeu-de-test", environment = env })()
		local map = place:GetService("Workspace").Parcours
		if map.Dangers:FindFirstChild("Barre") and #map.Tapis:GetChildren() > 0 then
			moteur = Moteur.nouveau(place, { studio = false, debut = 20_000 * JOUR })
			moteur:demarrerServeur()
			game = place
			break
		end
	end
	t.vrai(game ~= nil)
	local barre = parcours(game).Dangers:FindFirstChild("Barre")
	local avant = barre.CFrame
	moteur:avancer(1, 0.1)
	t.vrai(barre.CFrame ~= avant)
	t.vrai((barre.CFrame.Position - avant.Position).Magnitude < 0.01) -- tourne sur place
	local tapis = parcours(game).Tapis:GetChildren()[1]
	t.vrai(typeof(tapis:GetAttribute("VitesseTapis")) == "Vector3")
	sansErreur(moteur)
end

-- Les tests ci-dessus détectent-ils vraiment une régression ? On sabote le script
-- de jeu de trois façons et on vérifie que le comportement attendu disparaît.
M["sabotages : les règles testées dépendent bien du code du jeu"] = function(t)
	-- 1. Victoire sans la dernière borne
	local moteur, game = lancer({
		saboter = function(source)
			return (string.gsub(source, "if p%.etape < NB_ETAPES %- 1 then", "if false then"))
		end,
	})
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	moteur:toucher(parcours(game).Arrivee, alice)
	t.egal(stat(alice, "Victoires"), 1)

	-- 2. Gemme créditée deux fois
	moteur, game = lancer({
		saboter = function(source)
			return (string.gsub(source, 'gemme:SetAttribute%("Pris", true%)', ""))
		end,
	})
	alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	local gemme = gemmeDe(game, 5)
	gemme.CanTouch = true
	moteur:toucher(gemme, alice)
	moteur:toucher(gemme, alice)
	t.egal(stat(alice, "Cristaux"), 10)

	-- 3. Étape non enregistrée dans le profil
	moteur, game = lancer({
		saboter = function(source)
			return (string.gsub(source, "donnees%.parcours = garde", ""))
		end,
	})
	alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(2)
	moteur:toucher(borne(game, 1), alice)
	moteur:retirerJoueur(alice)
	moteur:avancer(2)
	local enregistrement = moteur.datastores.Joueurs_v1.donnees["joueur_1"]
	t.egal(enregistrement.donnees.jeu.parcours, nil)
end

return M
