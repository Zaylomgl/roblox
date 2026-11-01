--[[
	Script serveur principal : branche le noyau (modules purs testés hors
	ligne) sur les services Roblox.

	- Chargement / sauvegarde des profils (DataStore + verrou de session)
	- leaderstats (monnaie visible dans le classement)
	- Récompense quotidienne (RemoteFunctions)
	- Achats : Developer Products (ProcessReceipt) et Game Passes
	- API pour les scripts de map (Noyau.API)
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Noyau = script.Parent:WaitForChild("Noyau")
local Achats = require(Noyau.Achats)
local API = require(Noyau.API)
local Profil = require(Noyau.Profil)
local RecompenseQuotidienne = require(Noyau.RecompenseQuotidienne)
local Sauvegarde = require(Noyau.Sauvegarde)
local Configuration = require(ReplicatedStorage:WaitForChild("Partage"):WaitForChild("Configuration"))

local function journal(message: string)
	print("[Noyau] " .. message)
end

--------------------------------------------------------------------------------
-- DataStore (ou mémoire en Studio si l'accès aux API n'est pas activé)
--------------------------------------------------------------------------------

local function storeMemoire()
	local donnees = {}
	return {
		UpdateAsync = function(_, cle, transformation)
			local nouveau = transformation(donnees[cle])
			if nouveau ~= nil then
				donnees[cle] = nouveau
			end
			return nouveau
		end,
	}
end

local store
local sauvegardeReelle = true
do
	local ok, resultat = pcall(function()
		return DataStoreService:GetDataStore(Configuration.NOM_DATASTORE)
	end)
	if ok then
		store = resultat
	else
		sauvegardeReelle = false
		store = storeMemoire()
		warn("[Noyau] DataStore indisponible, progression NON sauvegardée : " .. tostring(resultat))
	end
end

local sauvegarde = Sauvegarde.nouveau(store, {
	jobId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false),
	maintenant = os.time,
	attendre = task.wait,
	-- En Studio sans accès aux API, inutile d'attendre longtemps avant le profil temporaire.
	essaisChargement = if RunService:IsStudio() then 2 else 6,
	journal = journal,
})

--------------------------------------------------------------------------------
-- Profils chargés
--------------------------------------------------------------------------------

type Session = {
	profil: any,
	passes: { [string]: boolean },
	arrivee: number,
	sauvegardable: boolean, -- false si le chargement a échoué en Studio (profil temporaire)
}

local sessions: { [Player]: Session } = {}

local function cleDe(joueur: Player): string
	return Configuration.PREFIXE_CLE .. joueur.UserId
end

local function passParCle(cle: string)
	for _, pass in Configuration.PASSES do
		if pass.cle == cle then
			return pass
		end
	end
	return nil
end

-- Remotes (créés par le serveur, utilisés par l'interface).
local dossierRemotes = Instance.new("Folder")
dossierRemotes.Name = "Remotes"
local remoteEtat = Instance.new("RemoteFunction")
remoteEtat.Name = "EtatJoueur"
remoteEtat.Parent = dossierRemotes
local remoteReclamer = Instance.new("RemoteFunction")
remoteReclamer.Name = "ReclamerRecompense"
remoteReclamer.Parent = dossierRemotes
local remoteMiseAJour = Instance.new("RemoteEvent")
remoteMiseAJour.Name = "MiseAJour"
remoteMiseAJour.Parent = dossierRemotes
dossierRemotes.Parent = ReplicatedStorage

local function etatPourClient(joueur: Player)
	local session = sessions[joueur]
	if not session then
		return nil
	end
	local p = session.profil
	return {
		monnaie = p.monnaie,
		recompense = RecompenseQuotidienne.etat(p.recompense, os.time(), Configuration.RECOMPENSES_QUOTIDIENNES),
		passes = session.passes,
		sauvegardeActive = sauvegardeReelle and session.sauvegardable,
	}
end

local function rafraichir(joueur: Player)
	local session = sessions[joueur]
	if not session then
		return
	end
	local stats = joueur:FindFirstChild("leaderstats")
	local valeur = stats and stats:FindFirstChild(Configuration.MONNAIE.nom)
	if valeur then
		valeur.Value = session.profil.monnaie
	end
	remoteMiseAJour:FireClient(joueur, etatPourClient(joueur))
end

local function sauvegarderJoueur(joueur: Player, liberer: boolean): boolean
	local session = sessions[joueur]
	if not session or not session.sauvegardable then
		return false
	end
	local p = session.profil
	p.stats.derniereVisite = os.time()
	p.stats.tempsDeJeu += os.time() - session.arrivee
	session.arrivee = os.time()
	return sauvegarde:sauvegarder(cleDe(joueur), p, liberer)
end

local function verifierPasses(joueur: Player, session: Session)
	for _, pass in Configuration.PASSES do
		if pass.id ~= 0 then
			local ok, possede = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(joueur.UserId, pass.id)
			end)
			session.passes[pass.cle] = ok and possede == true
		end
	end
end

local function joueurArrive(joueur: Player)
	local donnees, erreur = sauvegarde:charger(cleDe(joueur))
	if not joueur.Parent then
		-- Parti pendant le chargement : on rend le verrou tout de suite.
		if not erreur then
			sauvegarde:sauvegarder(cleDe(joueur), donnees, true)
		end
		return
	end

	local sauvegardable = true
	if erreur then
		if RunService:IsStudio() then
			-- En Studio sans accès aux API : on joue quand même, sans sauvegarde.
			warn("[Noyau] Chargement impossible (" .. erreur .. ") : profil temporaire en Studio.")
			sauvegardable = false
			donnees = nil
		else
			-- En ligne : mieux vaut refuser que risquer d'écraser la progression.
			joueur:Kick("Tes données n'ont pas pu être chargées. Réessaie dans une minute, ta progression est en sécurité.")
			return
		end
	end

	local profil = Profil.reconcilier(donnees, os.time())
	profil.stats.visites += 1
	local session: Session = { profil = profil, passes = {}, arrivee = os.time(), sauvegardable = sauvegardable }
	sessions[joueur] = session

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local valeur = Instance.new("IntValue")
	valeur.Name = Configuration.MONNAIE.nom
	valeur.Value = profil.monnaie
	valeur.Parent = stats
	stats.Parent = joueur

	verifierPasses(joueur, session)
	rafraichir(joueur)
end

local function joueurPart(joueur: Player)
	if sessions[joueur] then
		sauvegarderJoueur(joueur, true)
		sessions[joueur] = nil
	end
end

Players.PlayerAdded:Connect(joueurArrive)
Players.PlayerRemoving:Connect(joueurPart)
for _, joueur in Players:GetPlayers() do
	task.spawn(joueurArrive, joueur)
end

-- Sauvegarde automatique.
task.spawn(function()
	while true do
		task.wait(Configuration.SAUVEGARDE_AUTO_SECONDES)
		for joueur in sessions do
			task.spawn(sauvegarderJoueur, joueur, false)
		end
	end
end)

-- Arrêt du serveur : on sauvegarde tout le monde en parallèle avant la fermeture.
game:BindToClose(function()
	local restants = 0
	for joueur in sessions do
		restants += 1
		task.spawn(function()
			sauvegarderJoueur(joueur, true)
			restants -= 1
		end)
	end
	local debut = os.clock()
	while restants > 0 and os.clock() - debut < 25 do
		task.wait(0.1)
	end
end)

--------------------------------------------------------------------------------
-- Récompense quotidienne
--------------------------------------------------------------------------------

local derniereDemande: { [Player]: number } = {}

remoteEtat.OnServerInvoke = function(joueur: Player)
	return etatPourClient(joueur)
end

remoteReclamer.OnServerInvoke = function(joueur: Player)
	-- Anti-spam : une demande par seconde maximum.
	local maintenant = os.clock()
	if derniereDemande[joueur] and maintenant - derniereDemande[joueur] < 1 then
		return { ok = false, raison = "trop_rapide" }
	end
	derniereDemande[joueur] = maintenant

	local session = sessions[joueur]
	if not session then
		return { ok = false, raison = "pas_charge" }
	end
	local gain = RecompenseQuotidienne.reclamer(session.profil.recompense, os.time(), Configuration.RECOMPENSES_QUOTIDIENNES)
	if not gain then
		return { ok = false, raison = "deja_reclamee", etat = etatPourClient(joueur) }
	end
	Profil.ajouterMonnaie(session.profil, gain)
	task.spawn(sauvegarderJoueur, joueur, false)
	rafraichir(joueur)
	return { ok = true, gain = gain, serie = session.profil.recompense.serie, etat = etatPourClient(joueur) }
end

Players.PlayerRemoving:Connect(function(joueur)
	derniereDemande[joueur] = nil
end)

--------------------------------------------------------------------------------
-- Achats
--------------------------------------------------------------------------------

local gestionnaires = {}
for _, produit in Configuration.PRODUITS do
	if produit.id ~= 0 and produit.monnaie then
		gestionnaires[produit.id] = function(profil)
			return Profil.ajouterMonnaie(profil, produit.monnaie)
		end
	end
end

local traiterRecu = Achats.creerTraitement({
	profilDe = function(userId: number)
		local joueur = Players:GetPlayerByUserId(userId)
		local session = joueur and sessions[joueur]
		return session and session.profil
	end,
	gestionnaires = gestionnaires,
	sauvegarderMaintenant = function(userId: number)
		local joueur = Players:GetPlayerByUserId(userId)
		if not joueur then
			return false
		end
		local ok = sauvegarderJoueur(joueur, false)
		if ok then
			rafraichir(joueur)
		end
		return ok
	end,
	copieProfonde = Profil.copieProfonde,
	memoriserAchat = Profil.memoriserAchat,
	achatDejaTraite = Profil.achatDejaTraite,
	journal = journal,
})

MarketplaceService.ProcessReceipt = function(recu)
	local decision = traiterRecu(recu)
	if decision == Achats.ACCORDE then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(joueur: Player, passId: number, achete: boolean)
	if not achete then
		return
	end
	local session = sessions[joueur]
	if not session then
		return
	end
	for _, pass in Configuration.PASSES do
		if pass.id == passId then
			session.passes[pass.cle] = true
		end
	end
	rafraichir(joueur)
end)

--------------------------------------------------------------------------------
-- API pour les scripts de map
--------------------------------------------------------------------------------

local function multiplicateur(session: Session): number
	local m = 1
	for cle, possede in session.passes do
		local pass = possede and passParCle(cle)
		if pass and pass.multiplicateurMonnaie then
			m *= pass.multiplicateurMonnaie
		end
	end
	return m
end

API._brancher({
	ajouterMonnaie = function(joueur: Player, montant: number, _raison: string?)
		local session = sessions[joueur]
		if not session or type(montant) ~= "number" or montant <= 0 then
			return false
		end
		local gain = math.floor(montant * multiplicateur(session))
		if not Profil.ajouterMonnaie(session.profil, gain) then
			return false
		end
		rafraichir(joueur)
		return gain
	end,
	depenserMonnaie = function(joueur: Player, montant: number, _raison: string?)
		local session = sessions[joueur]
		if not session or type(montant) ~= "number" or montant <= 0 then
			return false
		end
		local ok = Profil.ajouterMonnaie(session.profil, -montant)
		if ok then
			rafraichir(joueur)
		end
		return ok
	end,
	donneesJeu = function(joueur: Player)
		local session = sessions[joueur]
		return session and session.profil.jeu
	end,
	possedePass = function(joueur: Player, cle: string)
		local session = sessions[joueur]
		return session ~= nil and session.passes[cle] == true
	end,
})

journal(`Prêt (sauvegarde {if sauvegardeReelle then "DataStore" else "en mémoire"})`)
