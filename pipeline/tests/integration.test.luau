--[[
	Tests d'intégration : les VRAIS scripts du jeu (src/ + script de la map)
	exécutés dans le moteur simulé (pipeline/lib/moteur.luau), avec des joueurs
	simulés. Vérifie le parcours complet : arrivée, interface, récompense
	quotidienne, achats, pass, collecte sur la map, départ, fermeture.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Moteur = require("../lib/moteur")
local injection = require("../lib/injection")
local rbxenv = require("../lib/rbxenv")

local M = {}

local PASS_X2, PRODUIT_PETIT, PRODUIT_GRAND = 1001, 2001, 2002
local JOUR = 86400

-- Construit une place : (map optionnelle) + src/ injecté, avec des IDs de boutique de test.
local function construire(options: { map: string?, studio: boolean? }?)
	local opts = options or {}
	local env, game = rbxenv.creer({ silencieux = true })
	if opts.map then
		luau.load(fs.readFile(opts.map), { debugName = opts.map, environment = env })()
	end
	injection.injecter(game, "src")
	local config = game:GetService("ReplicatedStorage").Partage.Configuration
	-- Remplace les IDs (0 ou vrais IDs Roblox) par des IDs de test connus du moteur simulé.
	local source = config.Source
	for cle, id in { DoubleMonnaie = PASS_X2, PackPetit = PRODUIT_PETIT, PackGrand = PRODUIT_GRAND } do
		local n
		source, n = string.gsub(source, `(cle = "{cle}",%s*id = )%d+`, "%1" .. id)
		assert(n == 1, `Configuration.luau : id de « {cle} » introuvable`)
	end
	config.Source = source
	local moteur = Moteur.nouveau(game, { studio = opts.studio, debut = 20_000 * JOUR + 10 * 3600 })
	moteur:demarrerServeur()
	return moteur, game
end

local function sansErreur(t, moteur)
	if #moteur.erreurs > 0 then
		error("Erreurs d'exécution des scripts :\n" .. table.concat(moteur.erreurs, "\n---\n"), 2)
	end
	t.vrai(true)
end

local function monnaie(joueur): number?
	local stats = joueur:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild("Cristaux")
	return v and v.Value
end

local function sauvegarde(moteur, userId: number)
	local store = moteur.datastores.Joueurs_v1
	return store and store.donnees["joueur_" .. userId]
end

local function boutonTexte(joueur, debut: string)
	return Moteur.trouver(joueur.PlayerGui, function(d)
		return d:IsA("TextButton") and string.sub(d.Text, 1, #debut) == debut
	end)
end

---------------------------------------------------------------------------------

M["arrivée : profil, leaderstats, interface et cadeau du jour proposé"] = function(t)
	local moteur = construire()
	local alice = moteur:ajouterJoueur("Alice", 1)
	sansErreur(t, moteur)
	t.egal(monnaie(alice), 0)
	local ecran = alice.PlayerGui:FindFirstChild("InterfaceNoyau")
	t.vrai(ecran ~= nil)
	local reclamer = boutonTexte(alice, "Réclamer")
	t.vrai(reclamer ~= nil)
	t.vrai(reclamer.Parent.Parent.Visible) -- panneau du cadeau ouvert d'office
	local compteur = Moteur.trouver(ecran, function(d)
		return d:IsA("TextLabel") and string.find(d.Text, "🔮", 1, true) ~= nil and d.Parent.Name == "Compteur"
	end)
	t.egal(compteur.Text, "🔮 0")
end

M["récompense : +10, sauvegardée, refusée le même jour, +20 le lendemain, série cassée ensuite"] = function(t)
	local moteur = construire()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:cliquer(boutonTexte(alice, "Réclamer"))
	t.egal(monnaie(alice), 10)
	t.egal(sauvegarde(moteur, 1).donnees.monnaie, 10)

	moteur:cliquer(boutonTexte(alice, "Prochaine dans"))
	t.egal(monnaie(alice), 10)

	moteur:sauter(JOUR)
	moteur:cliquer(boutonTexte(alice, "Réclamer"))
	t.egal(monnaie(alice), 30)

	moteur:sauter(3 * JOUR)
	moteur:cliquer(boutonTexte(alice, "Réclamer"))
	t.egal(monnaie(alice), 40) -- série cassée : retour au gain du jour 1
	sansErreur(t, moteur)
end

M["achat de produit : crédité une fois, sauvegardé avant d'accorder, rejouable sans double crédit"] = function(t)
	local moteur = construire()
	local alice = moteur:ajouterJoueur("Alice", 1)
	local ACCORDE = roblox.Enum.ProductPurchaseDecision.PurchaseGranted
	local PAS_ENCORE = roblox.Enum.ProductPurchaseDecision.NotProcessedYet

	t.egal(moteur:recu(alice, PRODUIT_PETIT, "achat-1"), ACCORDE)
	t.egal(monnaie(alice), 100)
	t.egal(sauvegarde(moteur, 1).donnees.monnaie, 100)
	t.egal(moteur:recu(alice, PRODUIT_PETIT, "achat-1"), ACCORDE)
	t.egal(monnaie(alice), 100)

	moteur.datastoreEnPanne = true
	t.egal(moteur:recu(alice, PRODUIT_GRAND, "achat-2"), PAS_ENCORE)
	moteur.datastoreEnPanne = false
	t.egal(moteur:recu(alice, PRODUIT_GRAND, "achat-2"), ACCORDE)
	t.egal(monnaie(alice), 700)
	t.egal(sauvegarde(moteur, 1).donnees.monnaie, 700)
	sansErreur(t, moteur)
end

M["map Îles Célestes : cristal crédité dans le profil, doublé avec le pass x2"] = function(t)
	local moteur, game = construire({ map = "maps/iles-celestes.lua" })
	local alice = moteur:ajouterJoueur("Alice", 1)
	local cristaux = {}
	for _, c in game:GetService("Workspace").MapIlesCelestes.Collectibles:GetChildren() do
		if c:IsA("BasePart") and c:GetAttribute("Valeur") == 1 then
			table.insert(cristaux, c)
		end
	end
	t.vrai(#cristaux >= 2)

	moteur:toucher(cristaux[1], alice)
	t.egal(monnaie(alice), 1)
	moteur:toucher(cristaux[1], alice) -- déjà pris : rien
	t.egal(monnaie(alice), 1)

	moteur:acheterPass(alice, PASS_X2)
	moteur:toucher(cristaux[2], alice)
	t.egal(monnaie(alice), 3)

	moteur:avancer(30, 1) -- réapparition des cristaux (25 s par défaut)
	moteur:toucher(cristaux[1], alice)
	t.egal(monnaie(alice), 5)
	moteur:avancer(2, 0.1) -- quelques images d'animation (Heartbeat)
	sansErreur(t, moteur)
end

M["départ et retour : progression conservée, verrou libéré"] = function(t)
	local moteur = construire()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:recu(alice, PRODUIT_PETIT, "achat-1")
	moteur:retirerJoueur(alice)
	moteur:avancer(1)
	local enregistrement = sauvegarde(moteur, 1)
	t.egal(enregistrement.donnees.monnaie, 100)
	t.egal(enregistrement.verrou, nil)
	t.egal(enregistrement.donnees.stats.visites, 1)

	local retour = moteur:ajouterJoueur("Alice", 1)
	t.egal(monnaie(retour), 100)
	sansErreur(t, moteur)
end

M["DataStore en panne en ligne : le joueur est expulsé plutôt que de risquer sa sauvegarde"] = function(t)
	local moteur = construire({ studio = false })
	moteur.datastoreEnPanne = true
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(40, 0.5)
	t.vrai(moteur.expulses[1] ~= nil)
	t.egal(alice.Parent, nil)
	sansErreur(t, moteur)
end

M["Studio sans DataStore : on peut jouer, avec un profil temporaire"] = function(t)
	local moteur = construire({ studio = true })
	moteur.datastoreEnPanne = true
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:avancer(10, 0.5)
	t.egal(moteur.expulses[1], nil)
	t.egal(monnaie(alice), 0)
	sansErreur(t, moteur)
end

M["fermeture du serveur : sauvegarde de tous les joueurs"] = function(t)
	local moteur = construire()
	local alice = moteur:ajouterJoueur("Alice", 1)
	local bob = moteur:ajouterJoueur("Bob", 2)
	moteur:recu(alice, PRODUIT_PETIT, "a")
	moteur:recu(bob, PRODUIT_GRAND, "b")
	moteur:fermer()
	t.egal(sauvegarde(moteur, 1).donnees.monnaie, 100)
	t.egal(sauvegarde(moteur, 2).donnees.monnaie, 600)
	t.egal(sauvegarde(moteur, 2).verrou, nil)
	sansErreur(t, moteur)
end

M["boutique : le pass ouvre la fenêtre d'achat Roblox, puis s'affiche « Possédé »"] = function(t)
	local moteur = construire()
	local alice = moteur:ajouterJoueur("Alice", 1)
	moteur:cliquer(Moteur.trouver(alice.PlayerGui, function(d)
		return d:IsA("TextButton") and d.Text == "🛒"
	end))
	local boutonPass = boutonTexte(alice, "R$ ")
	t.vrai(boutonPass ~= nil)
	moteur:cliquer(boutonPass)
	t.egal(#moteur.invitesAchat, 1)
	t.egal(moteur.invitesAchat[1].id, PASS_X2)
	moteur:acheterPass(alice, PASS_X2)
	t.egal(boutonPass.Text, "Possédé ✓")
	sansErreur(t, moteur)
end

M["sauvegarde automatique toutes les 2 minutes"] = function(t)
	local moteur = construire()
	local alice = moteur:ajouterJoueur("Alice", 1)
	local ecrituresAvant = moteur.datastores.Joueurs_v1.ecritures
	moteur:sauter(125)
	t.vrai(moteur.datastores.Joueurs_v1.ecritures > ecrituresAvant)
	t.egal(monnaie(alice), 0)
	sansErreur(t, moteur)
end

return M
