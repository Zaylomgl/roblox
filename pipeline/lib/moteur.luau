--[[
	Moteur Roblox simulé (pour les tests d'intégration, hors de Roblox).

	Exécute les vrais scripts du jeu (serveur, client, map) sur de VRAIES
	instances Roblox fournies par Lune : chaque nom de propriété et chaque type
	sont vérifiés contre la base de réflexion officielle de Roblox. Ce module
	ajoute ce que Lune ne fournit pas : événements, callbacks, services
	(DataStore, Marketplace, Players…), ordonnanceur de tâches et horloge
	virtuelle (on peut « sauter au lendemain »).

	Ce n'est PAS le vrai moteur : pas de physique, pas de rendu, pas de réseau.
	Il sert à exécuter la logique de bout en bout et à attraper les erreurs
	d'exécution (champ nil, mauvais nom de propriété, mauvais enchaînement).
	Les tests dans le vrai moteur passeront par l'API Open Cloud Luau Execution.
]]

local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local rbxenv = require("./rbxenv")

local Moteur = {}
Moteur.__index = Moteur

local courant = nil -- moteur actif (les implémentations Lune sont globales au processus)

--------------------------------------------------------------------------------
-- Signaux
--------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.nouveau(moteur)
	return setmetatable({ _moteur = moteur, _connexions = {}, _attentes = {} }, Signal)
end

function Signal:Connect(fonction)
	local connexion = { Connected = true }
	function connexion.Disconnect()
		connexion.Connected = false
	end
	connexion._f = fonction
	table.insert(self._connexions, connexion)
	return connexion
end

function Signal:Once(fonction)
	local connexion
	connexion = self:Connect(function(...)
		connexion.Disconnect()
		fonction(...)
	end)
	return connexion
end

function Signal:Wait()
	table.insert(self._attentes, coroutine.running())
	return coroutine.yield()
end

function Signal:Fire(...)
	for _, c in table.clone(self._connexions) do
		if c.Connected then
			self._moteur:spawn(c._f, ...)
		end
	end
	local attentes = self._attentes
	self._attentes = {}
	for _, co in attentes do
		self._moteur:_reprendre(co, ...)
	end
end

Moteur.Signal = Signal

--------------------------------------------------------------------------------
-- Création
--------------------------------------------------------------------------------

export type Options = {
	studio: boolean?, -- RunService:IsStudio()
	debut: number?, -- os.time() au démarrage
}

function Moteur.nouveau(game, options: Options?)
	local opts = options or {}
	local self = setmetatable({
		game = game,
		studio = opts.studio or false,
		horloge = 0, -- os.clock() virtuel
		debut = opts.debut or 1_760_000_000,
		_attente = {}, -- { reveil, co | f, args }
		_signaux = {},
		_callbacks = {},
		_modules = {},
		_guid = 0,
		erreurs = {}, -- erreurs d'exécution des scripts
		journal = {}, -- print/warn des scripts
		datastores = {},
		datastoreEnPanne = false,
		passesPossedes = {}, -- [userId] = { [passId] = true }
		invitesAchat = {}, -- appels PromptGamePassPurchase / PromptProductPurchase
		expulses = {}, -- [userId] = message
		fermeture = nil, -- fonction BindToClose
		evenementsClient = {}, -- FireClient : { joueur, args }
	}, Moteur)
	courant = self
	game.JobId = "serveur-de-test"
	return self
end

function Moteur:maintenant(): number
	return math.floor(self.debut + self.horloge)
end

--------------------------------------------------------------------------------
-- Ordonnanceur
--------------------------------------------------------------------------------

function Moteur:_erreur(contexte: string, message: any, co: thread?)
	local trace = if co then debug.traceback(co, tostring(message)) else tostring(message)
	table.insert(self.erreurs, `{contexte} : {trace}`)
end

function Moteur:_reprendre(co: thread, ...)
	if coroutine.status(co) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		self:_erreur("script", err, co)
	end
end

function Moteur:spawn(f, ...)
	local co = if type(f) == "thread" then f else coroutine.create(f)
	self:_reprendre(co, ...)
	return co
end

function Moteur:_planifier(delai: number, co: thread?, f: any?, args: { any }?)
	table.insert(self._attente, { reveil = self.horloge + delai, co = co, f = f, args = args or {} })
end

function Moteur:wait(secondes: number?)
	local debut = self.horloge
	local co = coroutine.running()
	self:_planifier(math.max(secondes or 0, 1 / 60), co)
	coroutine.yield()
	return self.horloge - debut
end

-- Exécute tout ce qui est dû à l'instant courant (y compris ce qui se replanifie à 0).
function Moteur:_executerDus()
	for _ = 1, 100000 do
		local indice, meilleur = nil, math.huge
		for i, t in self._attente do
			if t.reveil <= self.horloge + 1e-9 and t.reveil < meilleur then
				indice, meilleur = i, t.reveil
			end
		end
		if not indice then
			return
		end
		local tache = table.remove(self._attente, indice)
		if tache.co then
			self:_reprendre(tache.co, self.horloge)
		else
			self:spawn(tache.f, table.unpack(tache.args))
		end
	end
	error("Boucle infinie dans l'ordonnanceur (une tâche se replanifie sans fin)")
end

-- Avance le temps virtuel de `secondes`, par pas de `pas` (Heartbeat déclenché à chaque pas).
function Moteur:avancer(secondes: number, pas: number?)
	local p = pas or 0.1
	local cible = self.horloge + secondes
	self:_executerDus()
	while self.horloge < cible - 1e-9 do
		local dt = math.min(p, cible - self.horloge)
		self.horloge += dt
		self:_executerDus()
		local rs = self.game:GetService("RunService")
		self:signal(rs, "Heartbeat"):Fire(dt)
	end
end

-- Saute un long moment (ex. 1 jour) sans Heartbeat, en exécutant les tâches dans l'ordre.
function Moteur:sauter(secondes: number)
	local cible = self.horloge + secondes
	while true do
		local prochaine = math.huge
		for _, t in self._attente do
			prochaine = math.min(prochaine, t.reveil)
		end
		if prochaine > cible then
			break
		end
		self.horloge = math.max(self.horloge, prochaine)
		self:_executerDus()
	end
	self.horloge = cible
	self:_executerDus()
end

--------------------------------------------------------------------------------
-- Signaux et callbacks par instance
--------------------------------------------------------------------------------

function Moteur:signal(instance, nom: string)
	local parInstance = self._signaux[instance]
	if not parInstance then
		parInstance = {}
		self._signaux[instance] = parInstance
	end
	local s = parInstance[nom]
	if not s then
		s = Signal.nouveau(self)
		parInstance[nom] = s
	end
	return s
end

function Moteur:callback(instance, nom: string)
	local t = self._callbacks[instance]
	return t and t[nom]
end

function Moteur:_definirCallback(instance, nom: string, f)
	self._callbacks[instance] = self._callbacks[instance] or {}
	self._callbacks[instance][nom] = f
end

--------------------------------------------------------------------------------
-- DataStore simulé (copie les valeurs et refuse ce qui n'est pas sérialisable)
--------------------------------------------------------------------------------

local function copieSerialisable(valeur, chemin: string)
	local t = type(valeur)
	if t == "table" then
		local copie = {}
		for k, v in valeur do
			if type(k) ~= "string" and type(k) ~= "number" then
				error(`DataStore : clé non sérialisable ({type(k)}) dans {chemin}`)
			end
			copie[k] = copieSerialisable(v, `{chemin}.{tostring(k)}`)
		end
		return copie
	elseif t == "string" or t == "number" or t == "boolean" or t == "nil" then
		return valeur
	end
	error(`DataStore : valeur non sérialisable ({typeof(valeur)}) dans {chemin}`)
end

function Moteur:_datastore(nom: string)
	local store = self.datastores[nom]
	if store then
		return store
	end
	local moteur = self
	store = { donnees = {}, ecritures = 0 }
	function store.UpdateAsync(magasin, cle, transformation)
		if moteur.datastoreEnPanne then
			error("DataStore indisponible (panne simulée)")
		end
		local nouveau = transformation(copieSerialisable(magasin.donnees[cle], cle), nil)
		if nouveau ~= nil then
			magasin.donnees[cle] = copieSerialisable(nouveau, cle)
			magasin.ecritures += 1
		end
		return nouveau
	end
	function store.GetAsync(magasin, cle)
		if moteur.datastoreEnPanne then
			error("DataStore indisponible (panne simulée)")
		end
		return copieSerialisable(magasin.donnees[cle], cle)
	end
	function store.SetAsync(magasin, cle, valeur)
		if moteur.datastoreEnPanne then
			error("DataStore indisponible (panne simulée)")
		end
		magasin.donnees[cle] = copieSerialisable(valeur, cle)
		magasin.ecritures += 1
	end
	self.datastores[nom] = store
	return store
end

--------------------------------------------------------------------------------
-- Implémentations Lune (événements, callbacks, méthodes de services)
--------------------------------------------------------------------------------

local EVENEMENTS = {
	Players = { "PlayerAdded", "PlayerRemoving" },
	MarketplaceService = { "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished" },
	GuiButton = { "Activated", "MouseButton1Click" },
	BasePart = { "Touched", "TouchEnded" },
	RunService = { "Heartbeat", "RenderStepped", "Stepped" },
	RemoteEvent = { "OnClientEvent", "OnServerEvent" },
	BindableEvent = { "Event" },
	Instance = { "Destroying", "ChildAdded", "ChildRemoved", "AncestryChanged" },
}

local CALLBACKS = {
	RemoteFunction = { "OnServerInvoke", "OnClientInvoke" },
	BindableFunction = { "OnInvoke" },
	MarketplaceService = { "ProcessReceipt" },
}

local implemente = false
local function implementer()
	if implemente then
		return
	end
	implemente = true

	for classe, noms in EVENEMENTS do
		for _, nom in noms do
			roblox.implementProperty(classe, nom, function(instance)
				return courant:signal(instance, nom)
			end)
		end
	end
	for classe, noms in CALLBACKS do
		for _, nom in noms do
			roblox.implementProperty(classe, nom, function(instance)
				return courant:callback(instance, nom)
			end, function(instance, f)
				courant:_definirCallback(instance, nom, f)
			end)
		end
	end

	local M = roblox.implementMethod
	M("Instance", "WaitForChild", function(instance, nom, delaiMax)
		local limite = delaiMax or 30
		local debut = courant.horloge
		while true do
			local enfant = instance:FindFirstChild(nom)
			if enfant then
				return enfant
			end
			if courant.horloge - debut >= limite then
				if delaiMax then
					return nil
				end
				error(`WaitForChild("{nom}") sur {instance:GetFullName()} : jamais trouvé après {limite} s`)
			end
			courant:wait(0.05)
		end
	end)
	M("DataModel", "BindToClose", function(_, f)
		courant.fermeture = f
	end)
	M("DataStoreService", "GetDataStore", function(_, nom)
		return courant:_datastore(nom)
	end)
	M("RunService", "IsStudio", function()
		return courant.studio
	end)
	M("RunService", "IsServer", function()
		return true
	end)
	M("RunService", "IsClient", function()
		return true
	end)
	M("HttpService", "GenerateGUID", function()
		courant._guid += 1
		return `guid-{courant._guid}`
	end)
	M("Players", "GetPlayers", function(players)
		local liste = {}
		for _, enfant in players:GetChildren() do
			if enfant:IsA("Player") then
				table.insert(liste, enfant)
			end
		end
		return liste
	end)
	M("Players", "GetPlayerByUserId", function(players, userId)
		for _, enfant in players:GetChildren() do
			if enfant:IsA("Player") and enfant.UserId == userId then
				return enfant
			end
		end
		return nil
	end)
	M("Players", "GetPlayerFromCharacter", function(players, modele)
		for _, enfant in players:GetChildren() do
			if enfant:IsA("Player") and modele ~= nil and enfant.Character == modele then
				return enfant
			end
		end
		return nil
	end)
	M("Player", "Kick", function(joueur, message)
		courant.expulses[joueur.UserId] = message or ""
		courant:retirerJoueur(joueur)
	end)
	M("MarketplaceService", "UserOwnsGamePassAsync", function(_, userId, passId)
		local possedes = courant.passesPossedes[userId]
		return possedes ~= nil and possedes[passId] == true
	end)
	M("MarketplaceService", "PromptGamePassPurchase", function(_, joueur, passId)
		table.insert(courant.invitesAchat, { type = "pass", joueur = joueur, id = passId })
	end)
	M("MarketplaceService", "PromptProductPurchase", function(_, joueur, produitId)
		table.insert(courant.invitesAchat, { type = "produit", joueur = joueur, id = produitId })
	end)
	M("MarketplaceService", "GetProductInfo", function(_, id)
		return { PriceInRobux = 99, Name = `Article {id}` }
	end)
	M("RemoteEvent", "FireClient", function(remote, joueur, ...)
		table.insert(courant.evenementsClient, { joueur = joueur, args = table.pack(...) })
		courant:signal(remote, "OnClientEvent"):Fire(...)
	end)
	M("RemoteEvent", "FireAllClients", function(remote, ...)
		courant:signal(remote, "OnClientEvent"):Fire(...)
	end)
	M("RemoteEvent", "FireServer", function(remote, ...)
		local joueur = courant.game:GetService("Players").LocalPlayer
		courant:signal(remote, "OnServerEvent"):Fire(joueur, ...)
	end)
	M("RemoteFunction", "InvokeServer", function(remote, ...)
		local f = courant:callback(remote, "OnServerInvoke")
		if not f then
			error("InvokeServer : OnServerInvoke non défini côté serveur")
		end
		local joueur = courant.game:GetService("Players").LocalPlayer
		return f(joueur, ...)
	end)
	M("BindableEvent", "Fire", function(b, ...)
		courant:signal(b, "Event"):Fire(...)
	end)
	M("ParticleEmitter", "Emit", function() end)
	M("Sound", "Play", function() end)
	M("Sound", "Stop", function() end)
	M("TweenService", "Create", function(_, instance, infos, objectifs)
		local tween = { Completed = Signal.nouveau(courant), PlaybackState = "Begin" }
		function tween.Play()
			for propriete, valeur in objectifs do
				instance[propriete] = valeur
			end
			courant:_planifier(infos.Time or 0, nil, function()
				tween.Completed:Fire("Completed")
			end)
		end
		function tween.Cancel() end
		function tween.Pause() end
		return tween
	end)
end

--------------------------------------------------------------------------------
-- Environnement des scripts
--------------------------------------------------------------------------------

local TweenInfoShim = {
	new = function(temps, style, direction, repetitions, inverse, delai)
		return {
			Time = temps or 1,
			EasingStyle = style,
			EasingDirection = direction,
			RepeatCount = repetitions or 0,
			Reverses = inverse or false,
			DelayTime = delai or 0,
		}
	end,
}

function Moteur:_environnement(script)
	if not self._base then
		local moteur = self
		local base = rbxenv.creer({ silencieux = true })
		base.game = self.game
		base.workspace = self.game:GetService("Workspace")
		base.Workspace = base.workspace
		base.TweenInfo = TweenInfoShim
		base.task = {
			wait = function(s)
				return moteur:wait(s)
			end,
			spawn = function(f, ...)
				return moteur:spawn(f, ...)
			end,
			defer = function(f, ...)
				moteur:_planifier(0, nil, f, table.pack(...))
			end,
			delay = function(s, f, ...)
				moteur:_planifier(s or 0, nil, f, table.pack(...))
			end,
			cancel = function() end,
		}
		base.wait = base.task.wait
		base.os = setmetatable({
			time = function(t)
				if t then
					return os.time(t)
				end
				return moteur:maintenant()
			end,
			clock = function()
				return moteur.horloge
			end,
		}, { __index = os })
		base.tick = function()
			return moteur.debut + moteur.horloge
		end
		base.time = base.os.clock
		local function journaliser(prefixe, ...)
			local morceaux = table.pack(...)
			local textes = {}
			for i = 1, morceaux.n do
				textes[i] = tostring(morceaux[i])
			end
			table.insert(moteur.journal, prefixe .. table.concat(textes, " "))
		end
		base.print = function(...)
			journaliser("", ...)
		end
		base.warn = function(...)
			journaliser("[warn] ", ...)
		end
		base.require = function(module)
			return moteur:requerir(module)
		end
		self._base = base
	end
	-- luau.load de Lune ne suit pas la métatable de l'environnement : on copie les champs.
	local env = table.clone(self._base)
	env.script = script
	return env
end

function Moteur:requerir(module)
	if typeof(module) ~= "Instance" or not module:IsA("ModuleScript") then
		error(`require attend un ModuleScript, reçu {typeof(module)}`)
	end
	local cache = self._modules[module]
	if cache then
		return cache.valeur
	end
	local fonction = luau.load(module.Source, { debugName = module:GetFullName(), environment = self:_environnement(module) })
	local valeur = fonction()
	self._modules[module] = { valeur = valeur }
	return valeur
end

function Moteur:executer(script)
	local fonction = luau.load(script.Source, { debugName = script:GetFullName(), environment = self:_environnement(script) })
	local co = coroutine.create(fonction)
	local ok, err = coroutine.resume(co)
	if not ok then
		self:_erreur(script:GetFullName(), err, co)
	end
end

-- Lance les Scripts serveur (comme Roblox : ServerScriptService et Workspace).
function Moteur:demarrerServeur()
	for _, conteneur in { self.game:GetService("ServerScriptService"), self.game:GetService("Workspace") } do
		for _, s in conteneur:GetDescendants() do
			if s.ClassName == "Script" then
				self:executer(s)
			end
		end
	end
	self:avancer(0.5)
end

--------------------------------------------------------------------------------
-- Joueurs
--------------------------------------------------------------------------------

function Moteur:ajouterJoueur(nom: string, userId: number)
	local players = self.game:GetService("Players")
	local joueur = roblox.Instance.new("Player")
	joueur.Name = nom
	joueur.UserId = userId
	roblox.Instance.new("PlayerGui").Parent = joueur

	-- Personnage minimal (pour les contacts avec les collectibles).
	local perso = roblox.Instance.new("Model")
	perso.Name = nom
	local racine = roblox.Instance.new("Part")
	racine.Name = "HumanoidRootPart"
	racine.Parent = perso
	roblox.Instance.new("Humanoid").Parent = perso
	perso.Parent = self.game:GetService("Workspace")
	joueur.Character = perso

	joueur.Parent = players
	self:signal(players, "PlayerAdded"):Fire(joueur)

	-- Scripts clients (StarterPlayerScripts), avec ce joueur comme LocalPlayer.
	players.LocalPlayer = joueur
	local starter = self.game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	if starter then
		for _, s in starter:GetDescendants() do
			if s.ClassName == "LocalScript" then
				self:executer(s)
			end
		end
	end
	self:avancer(0.5)
	return joueur
end

function Moteur:retirerJoueur(joueur)
	local players = self.game:GetService("Players")
	if joueur.Parent ~= players then
		return
	end
	self:signal(players, "PlayerRemoving"):Fire(joueur)
	joueur.Parent = nil
	if joueur.Character then
		joueur.Character.Parent = nil
	end
end

-- Simule l'arrêt du serveur (appelle la fonction BindToClose).
function Moteur:fermer()
	if self.fermeture then
		self:spawn(self.fermeture)
		self:avancer(30, 0.5)
	end
end

-- Simule un achat de Developer Product : appelle ProcessReceipt comme Roblox.
function Moteur:recu(joueur, produitId: number, purchaseId: string)
	local ms = self.game:GetService("MarketplaceService")
	local f = self:callback(ms, "ProcessReceipt")
	if not f then
		error("ProcessReceipt n'est pas défini")
	end
	local resultat
	self:spawn(function()
		resultat = f({
			PlayerId = joueur.UserId,
			ProductId = produitId,
			PurchaseId = purchaseId,
			CurrencySpent = 99,
			PlaceIdWherePurchased = 1,
		})
	end)
	-- ProcessReceipt peut attendre (sauvegarde, nouvelles tentatives) : on patiente jusqu'à 60 s.
	local debut = self.horloge
	while resultat == nil and self.horloge - debut < 60 do
		self:avancer(0.5, 0.5)
	end
	return resultat
end

-- Simule l'achat d'un Game Pass (le joueur le possède désormais + événement).
function Moteur:acheterPass(joueur, passId: number)
	self.passesPossedes[joueur.UserId] = self.passesPossedes[joueur.UserId] or {}
	self.passesPossedes[joueur.UserId][passId] = true
	self:signal(self.game:GetService("MarketplaceService"), "PromptGamePassPurchaseFinished"):Fire(joueur, passId, true)
	self:avancer(0.2)
end

-- Clic sur un bouton d'interface.
function Moteur:cliquer(bouton)
	self:signal(bouton, "Activated"):Fire()
	self:avancer(0.2)
end

-- Contact d'une partie du personnage avec une pièce.
function Moteur:toucher(piece, joueur)
	self:signal(piece, "Touched"):Fire(joueur.Character:FindFirstChild("HumanoidRootPart"))
	self:avancer(0.2)
end

-- Recherche récursive d'un descendant par nom (dans l'interface, par exemple).
function Moteur.trouver(racine, predicat: (any) -> boolean)
	for _, d in racine:GetDescendants() do
		if predicat(d) then
			return d
		end
	end
	return nil
end

implementer()

return Moteur
