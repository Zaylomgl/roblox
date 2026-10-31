--[[
	Interface du noyau (client) : compteur de monnaie, récompense quotidienne,
	boutique (passes et produits). Pensée d'abord pour le mobile : gros
	boutons, tailles relatives à l'écran.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local joueur = Players.LocalPlayer
local Configuration = require(ReplicatedStorage:WaitForChild("Partage"):WaitForChild("Configuration"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local remoteEtat = Remotes:WaitForChild("EtatJoueur")
local remoteReclamer = Remotes:WaitForChild("ReclamerRecompense")
local remoteMiseAJour = Remotes:WaitForChild("MiseAJour")

local COULEURS = {
	fond = Color3.fromRGB(28, 24, 44),
	fondClair = Color3.fromRGB(46, 40, 70),
	contour = Color3.fromRGB(120, 104, 190),
	texte = Color3.fromRGB(245, 240, 255),
	texteDoux = Color3.fromRGB(190, 180, 220),
	or_ = Color3.fromRGB(255, 199, 92),
	vert = Color3.fromRGB(96, 214, 140),
	rouge = Color3.fromRGB(240, 90, 110),
}
local POLICE = Enum.Font.FredokaOne
local MONNAIE = Configuration.MONNAIE.icone .. " "

local etat = nil -- dernier état reçu du serveur

--------------------------------------------------------------------------------
-- Petits outils de construction d'interface
--------------------------------------------------------------------------------

local function creer(classe: string, proprietes: { [string]: any }, enfants: { Instance }?)
	local objet = Instance.new(classe)
	for cle, valeur in proprietes do
		if cle ~= "Parent" then
			objet[cle] = valeur
		end
	end
	for _, enfant in enfants or {} do
		enfant.Parent = objet
	end
	objet.Parent = proprietes.Parent
	return objet
end

local function arrondi(rayon: number)
	return creer("UICorner", { CornerRadius = UDim.new(0, rayon) })
end

local function contour(couleur: Color3, epaisseur: number)
	return creer("UIStroke", { Color = couleur, Thickness = epaisseur, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- `_max` (option de ce helper, pas une propriété Roblox) : taille de texte maximale.
local function texte(proprietes: { [string]: any })
	local tailleMax = proprietes._max or 28
	proprietes._max = nil
	proprietes.BackgroundTransparency = proprietes.BackgroundTransparency or 1
	proprietes.Font = proprietes.Font or POLICE
	proprietes.TextColor3 = proprietes.TextColor3 or COULEURS.texte
	proprietes.TextScaled = if proprietes.TextScaled == nil then true else proprietes.TextScaled
	return creer("TextLabel", proprietes, { creer("UITextSizeConstraint", { MaxTextSize = tailleMax }) })
end

local function bouton(proprietes: { [string]: any })
	proprietes.Font = proprietes.Font or POLICE
	proprietes.TextColor3 = proprietes.TextColor3 or COULEURS.fond
	proprietes.BackgroundColor3 = proprietes.BackgroundColor3 or COULEURS.or_
	proprietes.TextScaled = true
	proprietes.AutoButtonColor = true
	return creer("TextButton", proprietes, {
		arrondi(12),
		creer("UITextSizeConstraint", { MaxTextSize = 24 }),
		creer("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
end

local function formaterDuree(secondes: number): string
	secondes = math.max(0, math.floor(secondes))
	return string.format("%02d:%02d:%02d", secondes // 3600, (secondes % 3600) // 60, secondes % 60)
end

--------------------------------------------------------------------------------
-- Écran principal
--------------------------------------------------------------------------------

local ecran = creer("ScreenGui", {
	Name = "InterfaceNoyau",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = joueur:WaitForChild("PlayerGui"),
})

-- Compteur de monnaie (en haut, visible aussi sur mobile où le classement est masqué).
local compteur = creer("Frame", {
	Name = "Compteur",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0, 180, 0, 44),
	BackgroundColor3 = COULEURS.fond,
	BackgroundTransparency = 0.15,
	Parent = ecran,
}, { arrondi(22), contour(COULEURS.contour, 2) })
local texteCompteur = texte({ Size = UDim2.fromScale(1, 1), Text = MONNAIE .. "…", Parent = compteur })

-- Barre de boutons à gauche.
local barre = creer("Frame", {
	Name = "Barre",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.new(0, 64, 0, 140),
	BackgroundTransparency = 1,
	Parent = ecran,
}, { creer("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function boutonBarre(icone: string, ordre: number)
	local b = bouton({
		Size = UDim2.new(0, 64, 0, 64),
		Text = icone,
		BackgroundColor3 = COULEURS.fond,
		TextColor3 = COULEURS.texte,
		LayoutOrder = ordre,
		Parent = barre,
	})
	contour(COULEURS.contour, 2).Parent = b
	return b
end

local boutonCadeau = boutonBarre("🎁", 1)
local pastille = creer("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 4, 0, -4),
	Size = UDim2.new(0, 18, 0, 18),
	BackgroundColor3 = COULEURS.rouge,
	Visible = false,
	Parent = boutonCadeau,
}, { arrondi(9) })
local boutonBoutique = boutonBarre("🛒", 2)

-- Panneau générique (centré, fermable).
local function panneau(titre: string)
	local cadre = creer("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.72),
		BackgroundColor3 = COULEURS.fond,
		Visible = false,
		Parent = ecran,
	}, {
		arrondi(18),
		contour(COULEURS.contour, 3),
		creer("UISizeConstraint", { MaxSize = Vector2.new(560, 440) }),
	})
	texte({
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.new(1, -80, 0, 40),
		Text = titre,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COULEURS.or_,
		_max = 32,
		Parent = cadre,
	})
	local fermer = bouton({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.new(0, 44, 0, 44),
		Text = "✕",
		BackgroundColor3 = COULEURS.fondClair,
		TextColor3 = COULEURS.texte,
		Parent = cadre,
	})
	fermer.Activated:Connect(function()
		cadre.Visible = false
	end)
	local contenu = creer("Frame", {
		Position = UDim2.new(0, 16, 0, 62),
		Size = UDim2.new(1, -32, 1, -78),
		BackgroundTransparency = 1,
		Parent = cadre,
	})
	return cadre, contenu
end

-- Notification éphémère en bas de l'écran.
local function notifier(message: string, couleur: Color3?)
	local toast = texte({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0, 360, 0, 48),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = COULEURS.fond,
		TextColor3 = couleur or COULEURS.texte,
		Text = message,
		Parent = ecran,
	})
	arrondi(14).Parent = toast
	contour(couleur or COULEURS.contour, 2).Parent = toast
	task.delay(2.5, function()
		local fondu = TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		fondu:Play()
		fondu.Completed:Wait()
		toast:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Récompense quotidienne
--------------------------------------------------------------------------------

local cadreCadeau, contenuCadeau = panneau("🎁 Récompense du jour")
local texteSerie = texte({
	Size = UDim2.new(1, 0, 0, 30),
	TextColor3 = COULEURS.texteDoux,
	Text = "",
	_max = 22,
	Parent = contenuCadeau,
})
local grille = creer("Frame", {
	Position = UDim2.new(0, 0, 0, 40),
	Size = UDim2.new(1, 0, 0.5, -20),
	BackgroundTransparency = 1,
	Parent = contenuCadeau,
}, {
	creer("UIGridLayout", {
		CellSize = UDim2.new(1 / 7, -6, 1, 0),
		CellPadding = UDim2.new(0, 6, 0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local cases = {}
for i, gain in Configuration.RECOMPENSES_QUOTIDIENNES do
	local case = creer("Frame", { BackgroundColor3 = COULEURS.fondClair, LayoutOrder = i, Parent = grille }, { arrondi(10) })
	local trait = contour(COULEURS.fondClair, 2)
	trait.Parent = case
	texte({ Size = UDim2.fromScale(1, 0.35), Text = "J" .. i, TextColor3 = COULEURS.texteDoux, _max = 18, Parent = case })
	texte({
		Position = UDim2.fromScale(0, 0.4),
		Size = UDim2.fromScale(1, 0.5),
		Text = tostring(gain),
		TextColor3 = COULEURS.or_,
		_max = 22,
		Parent = case,
	})
	cases[i] = { cadre = case, trait = trait }
end
local boutonReclamer = bouton({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.new(0.7, 0, 0, 56),
	Text = "Réclamer",
	Parent = contenuCadeau,
})

local function afficherRecompense()
	if not etat then
		return
	end
	local r = etat.recompense
	local nb = #Configuration.RECOMPENSES_QUOTIDIENNES
	local indice = ((r.serieSiReclamee - 1) % nb) + 1
	for i, c in cases do
		local actuelle = i == indice
		c.trait.Color = if actuelle then COULEURS.or_ else COULEURS.fondClair
		c.cadre.BackgroundColor3 = if i < indice then COULEURS.fond else COULEURS.fondClair
	end
	if r.disponible then
		texteSerie.Text = `Série : jour {r.serieSiReclamee} — reviens chaque jour pour gagner plus !`
		boutonReclamer.Text = `Réclamer {MONNAIE}{r.gainSiReclamee}`
		boutonReclamer.BackgroundColor3 = COULEURS.or_
		boutonReclamer.Active = true
	else
		texteSerie.Text = `Série : {r.serieSiReclamee} jour(s) d'affilée 🔥`
		boutonReclamer.Text = "Prochaine dans " .. formaterDuree(r.secondesAvantProchaine)
		boutonReclamer.BackgroundColor3 = COULEURS.fondClair
		boutonReclamer.Active = false
	end
	pastille.Visible = r.disponible
end

boutonReclamer.Activated:Connect(function()
	if not etat or not etat.recompense.disponible then
		return
	end
	local ok, reponse = pcall(function()
		return remoteReclamer:InvokeServer()
	end)
	if ok and reponse and reponse.ok then
		notifier(`+{reponse.gain} {Configuration.MONNAIE.nom} ! Série : {reponse.serie} 🔥`, COULEURS.or_)
		etat = reponse.etat or etat
		afficherRecompense()
	elseif ok and reponse and reponse.etat then
		etat = reponse.etat
		afficherRecompense()
	end
end)

--------------------------------------------------------------------------------
-- Boutique
--------------------------------------------------------------------------------

local cadreBoutique, contenuBoutique = panneau("🛒 Boutique")
local liste = creer("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = contenuBoutique,
}, { creer("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

local boutonsPasses = {}

local function ligneBoutique(ordre: number, nom: string, description: string, action: () -> ())
	local ligne = creer("Frame", {
		Size = UDim2.new(1, -8, 0, 76),
		BackgroundColor3 = COULEURS.fondClair,
		LayoutOrder = ordre,
		Parent = liste,
	}, { arrondi(12) })
	texte({
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.new(0.62, -12, 0, 30),
		Text = nom,
		TextXAlignment = Enum.TextXAlignment.Left,
		_max = 24,
		Parent = ligne,
	})
	texte({
		Position = UDim2.new(0, 12, 0, 40),
		Size = UDim2.new(0.62, -12, 0, 26),
		Text = description,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COULEURS.texteDoux,
		_max = 18,
		Parent = ligne,
	})
	local b = bouton({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.34, 0, 0, 52),
		Text = "Voir",
		Parent = ligne,
	})
	b.Activated:Connect(action)
	return b
end

local nbArticles = 0
for i, pass in Configuration.PASSES do
	if pass.id ~= 0 then
		nbArticles += 1
		boutonsPasses[pass.cle] = ligneBoutique(i, "⭐ " .. pass.nom, pass.description, function()
			if etat and etat.passes[pass.cle] then
				return
			end
			MarketplaceService:PromptGamePassPurchase(joueur, pass.id)
		end)
	end
end
for i, produit in Configuration.PRODUITS do
	if produit.id ~= 0 then
		nbArticles += 1
		ligneBoutique(100 + i, produit.nom, produit.description, function()
			MarketplaceService:PromptProductPurchase(joueur, produit.id)
		end)
	end
end
if nbArticles == 0 then
	texte({
		Size = UDim2.new(1, 0, 0, 40),
		Text = "La boutique ouvre bientôt !",
		TextColor3 = COULEURS.texteDoux,
		Parent = liste,
	})
end

-- Prix réels lus sur Roblox (affichés sur les boutons).
task.spawn(function()
	for _, pass in Configuration.PASSES do
		local b = boutonsPasses[pass.cle]
		if b then
			local ok, infos = pcall(function()
				return MarketplaceService:GetProductInfo(pass.id, Enum.InfoType.GamePass)
			end)
			if ok and infos and infos.PriceInRobux then
				b:SetAttribute("Prix", infos.PriceInRobux)
				b.Text = `R$ {infos.PriceInRobux}`
			end
		end
	end
end)

local function afficherBoutique()
	if not etat then
		return
	end
	for cle, b in boutonsPasses do
		if etat.passes[cle] then
			b.Text = "Possédé ✓"
			b.BackgroundColor3 = COULEURS.vert
			b.Active = false
		end
	end
end

--------------------------------------------------------------------------------
-- Synchronisation avec le serveur
--------------------------------------------------------------------------------

local function appliquer(nouvelEtat)
	if not nouvelEtat then
		return
	end
	etat = nouvelEtat
	texteCompteur.Text = MONNAIE .. tostring(etat.monnaie)
	afficherRecompense()
	afficherBoutique()
	if etat.sauvegardeActive == false then
		texteCompteur.TextColor3 = COULEURS.rouge -- signale en Studio que rien n'est sauvegardé
	end
end

remoteMiseAJour.OnClientEvent:Connect(appliquer)

boutonCadeau.Activated:Connect(function()
	cadreBoutique.Visible = false
	cadreCadeau.Visible = not cadreCadeau.Visible
	afficherRecompense()
end)
boutonBoutique.Activated:Connect(function()
	cadreCadeau.Visible = false
	cadreBoutique.Visible = not cadreBoutique.Visible
end)

-- État initial (le profil peut mettre quelques secondes à charger).
task.spawn(function()
	for _ = 1, 30 do
		local ok, e = pcall(function()
			return remoteEtat:InvokeServer()
		end)
		if ok and e then
			appliquer(e)
			if e.recompense.disponible then
				cadreCadeau.Visible = true -- on montre le cadeau dès l'arrivée s'il est disponible
			end
			return
		end
		task.wait(1)
	end
end)

-- Compte à rebours de la prochaine récompense.
task.spawn(function()
	while true do
		task.wait(1)
		if etat and not etat.recompense.disponible then
			etat.recompense.secondesAvantProchaine -= 1
			if etat.recompense.secondesAvantProchaine <= 0 then
				local ok, e = pcall(function()
					return remoteEtat:InvokeServer()
				end)
				if ok and e then
					appliquer(e)
				end
			elseif cadreCadeau.Visible then
				afficherRecompense()
			end
		end
	end
end)
