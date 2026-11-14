--------------------------------------------------------------------------------
-- KIT DE CONSTRUCTION (commun à tous les formats de la Fabrique)
-- Outils, palette du thème, ambiance et décors. Ne dépend que de `FABRIQUE`.
--------------------------------------------------------------------------------

local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")

local THEME = FABRIQUE.theme
local rng = Random.new(FABRIQUE.graine)

local TEXTURE_ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"
local TEXTURE_FUMEE = "rbxasset://textures/particles/smoke_main.dds"
local TEXTURE_FEU = "rbxasset://textures/particles/fire_main.dds"
local SON_COLLECTE = "rbxasset://sounds/electronicpingshort.wav"

-- Couleurs et matériaux du thème, convertis une fois pour toutes.
local C = {}
for cle, rvb in pairs(THEME.couleurs) do
	C[cle] = Color3.fromRGB(rvb[1], rvb[2], rvb[3])
end
C.blanc = Color3.fromRGB(250, 250, 250)
C.noir = Color3.fromRGB(24, 24, 28)
local MAT = {}
for cle, nom in pairs(THEME.materiaux) do
	MAT[cle] = Enum.Material[nom]
end

local K = {}

function K.rvb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Mélange de deux couleurs (t = 0 → a, t = 1 → b).
function K.melange(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

-- Variation légère d'une couleur, pour éviter les aplats uniformes.
function K.nuance(c, force)
	local d = rng:NextNumber(-force, force)
	return Color3.new(math.clamp(c.R + d, 0, 1), math.clamp(c.G + d, 0, 1), math.clamp(c.B + d, 0, 1))
end

function K.hasard(a, b)
	return rng:NextNumber(a, b)
end

function K.choisir(liste)
	return liste[rng:NextInteger(1, #liste)]
end

--------------------------------------------------------------------------------
-- Nettoyage : le script est relançable (l'ancienne map est supprimée)
--------------------------------------------------------------------------------

do
	local ancienne = workspace:FindFirstChild("Parcours")
	if ancienne then
		ancienne:Destroy()
	end
	local ancienScript = ServerScriptService:FindFirstChild("Parcours_Jeu")
	if ancienScript then
		ancienScript:Destroy()
	end
	for _, enfant in ipairs(Lighting:GetChildren()) do
		if string.sub(enfant.Name, 1, 4) == "Fab_" then
			enfant:Destroy()
		end
	end
	local nuages = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if nuages then
		nuages:Destroy()
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local vieuxSpawn = workspace:FindFirstChild("SpawnLocation")
	if vieuxSpawn then
		vieuxSpawn:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Dossiers
--------------------------------------------------------------------------------

local map = Instance.new("Folder")
map.Name = "Parcours"
map:SetAttribute("Nom", FABRIQUE.nom)
map:SetAttribute("Titre", FABRIQUE.titre)
map:SetAttribute("Format", FABRIQUE.format)
map:SetAttribute("Theme", THEME.cle)
map:SetAttribute("Graine", FABRIQUE.graine)

local D = {}
for _, nom in ipairs({
	"Structure", -- tout ce sur quoi on marche
	"Decor", -- purement visuel
	"Etapes", -- bornes de sauvegarde (attribut Numero)
	"Collectibles", -- gemmes à ramasser (attribut Valeur)
	"Dangers", -- tue au contact
	"Mobiles", -- tournent sur eux-mêmes (attribut VitesseRotation)
	"Fragiles", -- s'effacent quand on marche dessus
	"Tapis", -- tapis roulants (attribut VitesseTapis)
}) do
	local dossier = Instance.new("Folder")
	dossier.Name = nom
	dossier.Parent = map
	D[nom] = dossier
end

--------------------------------------------------------------------------------
-- Pièces de base
--------------------------------------------------------------------------------

function K.piece(props)
	local p = Instance.new(props.Classe or "Part")
	p.Anchored = true
	p.CastShadow = props.CastShadow ~= false
	p.CanCollide = props.CanCollide ~= false
	if props.CanTouch ~= nil then
		p.CanTouch = props.CanTouch
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Size = props.Size or Vector3.new(1, 1, 1)
	p.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	p.Color = props.Color or C.structure
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.Reflectance = props.Reflectance or 0
	p.Name = props.Name or "Decor"
	p.Parent = props.Parent or D.Decor
	return p
end

-- Pièce purement décorative : ni collision ni contact (on ne s'y coince pas).
function K.deco(props)
	props.CanCollide = false
	props.CanTouch = false
	props.Parent = props.Parent or D.Decor
	return K.piece(props)
end

-- Cylindre d'axe vertical (les cylindres Roblox ont leur axe sur X).
function K.cylindre(position, hauteur, diametre, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(hauteur, diametre, diametre)
	props.CFrame = (props.CFrame or CFrame.new(position)) * CFrame.Angles(0, 0, math.rad(90))
	return K.piece(props)
end

function K.boule(position, diametre, props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diametre, diametre, diametre)
	props.CFrame = CFrame.new(position)
	return K.piece(props)
end

-- Repère posé en `position`, dont l'axe -Z regarde dans la direction `vers`.
function K.repere(position, vers)
	return CFrame.new(position, position + vers)
end

function K.lumiere(parent, couleur, portee, luminosite)
	local l = Instance.new("PointLight")
	l.Color = couleur
	l.Range = portee
	l.Brightness = luminosite
	l.Shadows = false
	l.Parent = parent
	return l
end

function K.emetteur(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = props.Texture or TEXTURE_ETINCELLE
	e.Color = props.Color or ColorSequence.new(Color3.new(1, 1, 1))
	e.Size = props.Size or NumberSequence.new(1)
	e.Transparency = props.Transparency or NumberSequence.new(0.2, 1)
	e.Lifetime = props.Lifetime or NumberRange.new(2, 3)
	e.Rate = props.Rate or 5
	e.Speed = props.Speed or NumberRange.new(1, 2)
	e.SpreadAngle = props.SpreadAngle or Vector2.new(15, 15)
	e.Acceleration = props.Acceleration or Vector3.zero
	e.LightEmission = props.LightEmission or 0
	e.RotSpeed = props.RotSpeed or NumberRange.new(-40, 40)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = props.EmissionDirection or Enum.NormalId.Top
	e.Enabled = props.Enabled ~= false
	e.Parent = parent
	return e
end

-- Texte affiché sur une face d'une pièce.
function K.texte(piece, face, texte, couleurTexte)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = piece
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = texte
	label.TextColor3 = couleurTexte or C.blanc
	label.TextStrokeColor3 = C.noir
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return gui
end

-- Texte flottant, toujours face à la caméra.
function K.etiquette(piece, texte, hauteur, couleurTexte)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 280, 0, 64)
	gui.StudsOffset = Vector3.new(0, hauteur, 0)
	gui.MaxDistance = 260
	gui.Parent = piece
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = texte
	label.TextColor3 = couleurTexte or C.blanc
	label.TextStrokeColor3 = C.noir
	label.TextStrokeTransparency = 0.25
	label.Parent = gui
	return gui
end

--------------------------------------------------------------------------------
-- Ambiance : éclairage, atmosphère, nuages, étalonnage (tout vient du thème)
--------------------------------------------------------------------------------

function K.ambiance()
	local L = THEME.lumiere
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = THEME.heure
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = L.luminosite
	Lighting.ExposureCompensation = 0
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.Ambient = K.rvb(L.ambiance)
	Lighting.OutdoorAmbient = K.rvb(L.exterieur)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	local ciel = Instance.new("Sky") -- ciel physique par défaut de Roblox (pas de texture externe)
	ciel.Name = "Fab_Ciel"
	ciel.StarCount = 3000
	ciel.Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "Fab_Atmosphere"
	atmosphere.Density = L.atmosphere.densite
	atmosphere.Offset = L.atmosphere.decalage
	atmosphere.Color = K.rvb(L.atmosphere.couleur)
	atmosphere.Decay = K.rvb(L.atmosphere.declin)
	atmosphere.Glare = L.atmosphere.eblouissement
	atmosphere.Haze = L.atmosphere.brume
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Fab_Bloom"
	bloom.Intensity = L.bloom.intensite
	bloom.Size = L.bloom.taille
	bloom.Threshold = L.bloom.seuil
	bloom.Parent = Lighting

	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "Fab_Couleurs"
	correction.Brightness = 0
	correction.Contrast = L.correction.contraste
	correction.Saturation = L.correction.saturation
	correction.TintColor = K.rvb(L.correction.teinte)
	correction.Parent = Lighting

	local rayons = Instance.new("SunRaysEffect")
	rayons.Name = "Fab_Rayons"
	rayons.Intensity = 0.05
	rayons.Spread = 0.6
	rayons.Parent = Lighting

	local nuages = Instance.new("Clouds")
	nuages.Cover = L.nuages.couverture
	nuages.Density = L.nuages.densite
	nuages.Color = K.rvb(L.nuages.couleur)
	nuages.Parent = workspace.Terrain
end

--------------------------------------------------------------------------------
-- Décors
--------------------------------------------------------------------------------

-- Rocher : trois blocs imbriqués, tournés au hasard.
function K.rocher(position, taille, couleurRoche)
	couleurRoche = couleurRoche or C.structure
	for i = 1, 3 do
		local t = taille * (1.1 - i * 0.2)
		K.deco({
			Size = Vector3.new(t * K.hasard(0.9, 1.3), t * K.hasard(0.6, 1), t * K.hasard(0.9, 1.3)),
			CFrame = CFrame.new(position + Vector3.new(K.hasard(-0.3, 0.3) * taille, t * 0.3, K.hasard(-0.3, 0.3) * taille))
				* CFrame.Angles(K.hasard(-0.4, 0.4), K.hasard(0, 6.28), K.hasard(-0.4, 0.4)),
			Color = K.nuance(couleurRoche, 0.04),
			Material = MAT.structure,
			Name = "Rocher",
		})
	end
end

-- Grappe de cristaux lumineux (verre éclairé de l'intérieur).
function K.cristaux(position, hauteur, couleurCristal)
	couleurCristal = couleurCristal or C.accent
	for i = 1, 4 do
		local h = hauteur * (i == 1 and 1 or K.hasard(0.35, 0.7))
		local incline = (i == 1) and 0.08 or K.hasard(0.25, 0.5)
		local cap = K.hasard(0, 6.28)
		local cristal = K.deco({
			Size = Vector3.new(h * 0.22, h, h * 0.22),
			CFrame = CFrame.new(position)
				* CFrame.Angles(0, cap, 0)
				* CFrame.Angles(incline, 0, 0)
				* CFrame.new(0, h * 0.45, 0)
				* CFrame.Angles(0, math.rad(45), 0),
			Color = K.nuance(couleurCristal, 0.05),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Reflectance = 0.1,
			CastShadow = false,
			Name = "Cristal",
		})
		if i == 1 then
			K.lumiere(cristal, couleurCristal, hauteur * 3 + 6, 1.6)
		end
	end
end

local ARBRES = {}

function ARBRES.feuillu(p, e)
	local h = 6 * e
	K.cylindre(p + Vector3.new(0, h / 2, 0), h, 1.1 * e, { Color = C.bois, Material = MAT.bois, Name = "Tronc", CanCollide = false, CanTouch = false })
	for i = 1, 4 do
		local a = i * 1.6 + K.hasard(0, 1)
		K.boule(
			p + Vector3.new(math.cos(a) * 1.6 * e, h + K.hasard(-0.6, 1.4) * e, math.sin(a) * 1.6 * e),
			K.hasard(3.6, 5) * e,
			{ Color = K.nuance(C.vegetal, 0.05), Material = Enum.Material.LeafyGrass, Name = "Feuillage", CanCollide = false, CanTouch = false }
		)
	end
end

function ARBRES.sapin(p, e)
	local h = 3 * e
	K.cylindre(p + Vector3.new(0, h / 2, 0), h, 0.9 * e, { Color = C.bois, Material = MAT.bois, Name = "Tronc", CanCollide = false, CanTouch = false })
	local y = h
	for i = 1, 4 do
		local d = (6.4 - i * 1.4) * e
		local epaisseur = 2 * e
		K.cylindre(p + Vector3.new(0, y + epaisseur / 2, 0), epaisseur, d, { Color = K.nuance(C.vegetal, 0.04), Material = Enum.Material.LeafyGrass, Name = "Etage", CanCollide = false, CanTouch = false })
		K.cylindre(p + Vector3.new(0, y + epaisseur + 0.1 * e, 0), 0.25 * e, d * 0.82, { Color = C.sol, Material = Enum.Material.Snow, Name = "Neige", CanCollide = false, CanTouch = false, CastShadow = false })
		y += epaisseur * 0.85
	end
end

function ARBRES.palmier(p, e)
	local position = CFrame.new(p) * CFrame.Angles(0, K.hasard(0, 6.28), 0)
	local segment = 2 * e
	for i = 1, 5 do
		position = position * CFrame.Angles(math.rad(5), 0, 0) * CFrame.new(0, segment, 0)
		K.deco({
			Size = Vector3.new((1.2 - i * 0.1) * e, segment * 1.1, (1.2 - i * 0.1) * e),
			CFrame = position * CFrame.new(0, -segment / 2, 0),
			Color = K.nuance(C.bois, 0.04),
			Material = MAT.bois,
			Name = "Tronc",
		})
	end
	for i = 1, 7 do
		local feuille = position * CFrame.Angles(0, i * 0.9, 0) * CFrame.Angles(math.rad(-28), 0, 0)
		K.deco({
			Size = Vector3.new(1.5 * e, 0.25 * e, 6 * e),
			CFrame = feuille * CFrame.new(0, 0, -3 * e),
			Color = K.nuance(C.vegetal, 0.05),
			Material = Enum.Material.LeafyGrass,
			Name = "Palme",
		})
	end
	K.boule(position.Position + Vector3.new(0.5 * e, -0.4 * e, 0), 0.9 * e, { Color = C.bois, Material = MAT.bois, Name = "Noix", CanCollide = false, CanTouch = false })
end

function ARBRES.mort(p, e)
	local h = 5.5 * e
	local tronc = CFrame.new(p) * CFrame.Angles(K.hasard(-0.1, 0.1), K.hasard(0, 6.28), K.hasard(-0.1, 0.1))
	K.deco({ Size = Vector3.new(0.9 * e, h, 0.9 * e), CFrame = tronc * CFrame.new(0, h / 2, 0), Color = C.bois, Material = MAT.bois, Name = "Tronc" })
	for i = 1, 3 do
		local branche = tronc * CFrame.new(0, h * (0.5 + i * 0.15), 0) * CFrame.Angles(0, i * 2.1, 0) * CFrame.Angles(math.rad(48), 0, 0)
		local longueur = (3.4 - i * 0.5) * e
		K.deco({ Size = Vector3.new(0.4 * e, longueur, 0.4 * e), CFrame = branche * CFrame.new(0, longueur / 2, 0), Color = C.bois, Material = MAT.bois, Name = "Branche" })
		K.deco({
			Size = Vector3.new(0.5 * e, 0.5 * e, 0.5 * e),
			CFrame = branche * CFrame.new(0, longueur, 0),
			Color = C.accent,
			Material = Enum.Material.Neon,
			CastShadow = false,
			Name = "Braise",
		})
	end
end

function ARBRES.sucette(p, e)
	local h = 7 * e
	K.cylindre(p + Vector3.new(0, h / 2, 0), h, 0.5 * e, { Color = C.blanc, Name = "Baton", CanCollide = false, CanTouch = false })
	local face = CFrame.new(p + Vector3.new(0, h + 1.6 * e, 0)) * CFrame.Angles(0, K.hasard(0, 6.28), 0)
	local teintes = { K.choisir({ C.accent, C.accent2, C.structureAlt }), C.blanc }
	for i = 1, 4 do
		K.deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.7 * e + i * 0.12 * e, (5 - i * 1.1) * e, (5 - i * 1.1) * e),
			CFrame = face,
			Color = teintes[(i % 2) + 1],
			Name = "Sucette",
		})
	end
end

function ARBRES.antenne(p, e)
	local h = 9 * e
	K.cylindre(p + Vector3.new(0, h / 2, 0), h, 0.5 * e, { Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Mat", CanCollide = false, CanTouch = false })
	for i = 1, 3 do
		K.cylindre(p + Vector3.new(0, h * (0.35 + i * 0.18), 0), 0.25 * e, (3.6 - i * 0.8) * e, {
			Color = (i % 2 == 0) and C.accent2 or C.accent,
			Material = Enum.Material.Neon,
			Name = "Anneau",
			CanCollide = false,
			CanTouch = false,
			CastShadow = false,
		})
	end
	local tete = K.boule(p + Vector3.new(0, h + 0.4 * e, 0), 0.9 * e, { Color = C.accent2, Material = Enum.Material.Neon, Name = "Balise", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(tete, C.accent2, 16, 1.4)
end

function K.arbre(position, echelle)
	local fabriquer = ARBRES[THEME.decor.arbre] or ARBRES.feuillu
	fabriquer(position, echelle or 1)
end

local LAMPES = {}

function LAMPES.brasero(p)
	K.cylindre(p + Vector3.new(0, 1.5, 0), 3, 1.1, { Color = C.structure, Material = MAT.structure, Name = "Pied", CanCollide = false, CanTouch = false })
	local coupe = K.cylindre(p + Vector3.new(0, 3.3, 0), 0.7, 2.6, { Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Coupe", CanCollide = false, CanTouch = false })
	K.cylindre(p + Vector3.new(0, 3.7, 0), 0.2, 2.1, { Color = C.accent, Material = Enum.Material.Neon, Name = "Braises", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(coupe, C.accent, 22, 2)
	K.emetteur(coupe, {
		Texture = TEXTURE_FEU,
		Color = ColorSequence.new(C.accent2, C.danger),
		Size = NumberSequence.new(1.6, 0.2),
		Lifetime = NumberRange.new(0.6, 1.1),
		Rate = 9,
		Speed = NumberRange.new(2, 4),
		LightEmission = 1,
	})
end

function LAMPES.cristal(p)
	K.cristaux(p, 4.2, C.accent)
end

function LAMPES.lanterne(p)
	K.deco({ Size = Vector3.new(0.5, 6, 0.5), Position = p + Vector3.new(0, 3, 0), Color = C.bois, Material = MAT.bois, Name = "Poteau" })
	K.deco({ Size = Vector3.new(0.35, 0.35, 2), Position = p + Vector3.new(0, 5.8, 0.8), Color = C.bois, Material = MAT.bois, Name = "Bras" })
	local verre = K.deco({ Size = Vector3.new(0.9, 1.2, 0.9), Position = p + Vector3.new(0, 4.8, 1.6), Color = C.accent, Material = Enum.Material.Neon, CastShadow = false, Name = "Lanterne" })
	K.deco({ Size = Vector3.new(1.2, 0.2, 1.2), Position = p + Vector3.new(0, 5.5, 1.6), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Chapeau" })
	K.lumiere(verre, C.accent, 20, 1.6)
end

function LAMPES.sucre(p)
	for i = 0, 5 do
		K.cylindre(p + Vector3.new(0, 0.5 + i, 0), 1, 0.7, { Color = (i % 2 == 0) and C.danger or C.blanc, Name = "Sucre", CanCollide = false, CanTouch = false })
	end
	local globe = K.boule(p + Vector3.new(0, 6.9, 0), 1.8, { Color = C.accent2, Material = Enum.Material.Neon, Name = "Globe", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(globe, C.accent2, 18, 1.2)
end

function LAMPES.tube(p)
	K.deco({ Size = Vector3.new(0.6, 7, 0.6), Position = p + Vector3.new(0, 3.5, 0), Color = C.structure, Material = Enum.Material.Metal, Name = "Poteau" })
	local teinte = K.choisir({ C.accent, C.accent2 })
	local tube = K.deco({ Size = Vector3.new(0.3, 5, 0.3), Position = p + Vector3.new(0.45, 4, 0), Color = teinte, Material = Enum.Material.Neon, CastShadow = false, Name = "Tube" })
	K.lumiere(tube, teinte, 20, 1.8)
end

function LAMPES.projecteur(p)
	K.deco({ Size = Vector3.new(0.5, 8, 0.5), Position = p + Vector3.new(0, 4, 0), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Mat" })
	local tete = K.deco({
		Size = Vector3.new(1.4, 1, 1.8),
		CFrame = CFrame.new(p + Vector3.new(0, 8.2, 0.5)) * CFrame.Angles(math.rad(-40), 0, 0),
		Color = C.structureAlt,
		Material = Enum.Material.Metal,
		Name = "Projecteur",
	})
	K.deco({
		Size = Vector3.new(1.1, 0.7, 0.2),
		CFrame = tete.CFrame * CFrame.new(0, 0, -0.95),
		Color = C.accent2,
		Material = Enum.Material.Neon,
		CastShadow = false,
		Name = "Lentille",
	})
	local faisceau = Instance.new("SpotLight")
	faisceau.Color = C.accent2
	faisceau.Range = 34
	faisceau.Angle = 70
	faisceau.Brightness = 2.4
	faisceau.Face = Enum.NormalId.Front
	faisceau.Shadows = false
	faisceau.Parent = tete
end

function K.lampe(position)
	local fabriquer = LAMPES[THEME.decor.lampe] or LAMPES.lanterne
	fabriquer(position)
end

local SPECIAUX = {}

function SPECIAUX.geyser(p)
	for i = 1, 6 do
		local a = i * 1.05
		K.rocher(p + Vector3.new(math.cos(a) * 2.6, -0.4, math.sin(a) * 2.6), 1.8, C.structure)
	end
	local bassin = K.cylindre(p + Vector3.new(0, 0.25, 0), 0.5, 4, { Color = C.danger, Material = Enum.Material.Neon, Name = "Magma", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(bassin, C.accent, 26, 2.2)
	K.emetteur(bassin, {
		Texture = TEXTURE_FEU,
		Color = ColorSequence.new(C.accent2, C.danger),
		Size = NumberSequence.new(1.4, 0.1),
		Lifetime = NumberRange.new(0.8, 1.6),
		Rate = 12,
		Speed = NumberRange.new(10, 18),
		Acceleration = Vector3.new(0, -24, 0),
		SpreadAngle = Vector2.new(12, 12),
		LightEmission = 1,
	})
end

function SPECIAUX.stalagmite(p)
	K.cristaux(p, 7, C.solAlt)
	K.cristaux(p + Vector3.new(2.4, 0, 1.2), 4, C.accent)
end

function SPECIAUX.idole(p)
	K.deco({ Size = Vector3.new(4.4, 1, 4.4), Position = p + Vector3.new(0, 0.5, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Socle" })
	K.deco({ Size = Vector3.new(3.2, 4.4, 3), Position = p + Vector3.new(0, 3.2, 0), Color = C.structure, Material = MAT.structure, Name = "Tete" })
	K.deco({ Size = Vector3.new(3.8, 0.8, 3.4), Position = p + Vector3.new(0, 5.6, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Coiffe" })
	for _, cote in ipairs({ -0.8, 0.8 }) do
		local oeil = K.deco({ Size = Vector3.new(0.7, 0.5, 0.3), Position = p + Vector3.new(cote, 3.9, -1.5), Color = C.accent, Material = Enum.Material.Neon, CastShadow = false, Name = "Oeil" })
		K.lumiere(oeil, C.accent, 8, 1)
	end
	K.deco({ Size = Vector3.new(1.8, 0.4, 0.3), Position = p + Vector3.new(0, 2.2, -1.5), Color = C.noir, Name = "Bouche" })
	K.deco({ Size = Vector3.new(0.7, 1.4, 0.6), Position = p + Vector3.new(0, 3.1, -1.6), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Nez" })
end

function SPECIAUX.gateau(p)
	local teintes = { C.structure, C.accent, C.structure }
	for i = 1, 3 do
		local d = 6.4 - i * 1.5
		K.cylindre(p + Vector3.new(0, (i - 1) * 1.7 + 0.75, 0), 1.5, d, { Color = teintes[i], Name = "Etage", CanCollide = false, CanTouch = false })
		K.cylindre(p + Vector3.new(0, (i - 1) * 1.7 + 1.6, 0), 0.3, d + 0.3, { Color = C.blanc, Name = "Glacage", CanCollide = false, CanTouch = false, CastShadow = false })
	end
	local cerise = K.boule(p + Vector3.new(0, 5.9, 0), 1.2, { Color = C.danger, Reflectance = 0.2, Name = "Cerise", CanCollide = false, CanTouch = false })
	K.lumiere(cerise, C.accent, 10, 0.6)
end

function SPECIAUX.hologramme(p)
	K.cylindre(p + Vector3.new(0, 0.3, 0), 0.6, 3.4, { Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Socle", CanCollide = false, CanTouch = false })
	K.cylindre(p + Vector3.new(0, 0.65, 0), 0.12, 2.8, { Color = C.accent, Material = Enum.Material.Neon, Name = "Anneau", CanCollide = false, CanTouch = false, CastShadow = false })
	local cube = K.deco({
		Size = Vector3.new(2.2, 2.2, 2.2),
		CFrame = CFrame.new(p + Vector3.new(0, 3.6, 0)) * CFrame.Angles(math.rad(35), 0, math.rad(35)),
		Color = C.accent2,
		Material = Enum.Material.ForceField,
		CastShadow = false,
		Parent = D.Mobiles,
		Name = "Hologramme",
	})
	cube:SetAttribute("VitesseRotation", 0.9)
	K.lumiere(cube, C.accent2, 16, 1.4)
end

function SPECIAUX.mirador(p)
	for _, coin in ipairs({ { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } }) do
		K.deco({ Size = Vector3.new(0.5, 9, 0.5), Position = p + Vector3.new(coin[1], 4.5, coin[2]), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Pied" })
	end
	K.deco({ Size = Vector3.new(4.6, 0.5, 4.6), Position = p + Vector3.new(0, 9.2, 0), Color = C.bois, Material = MAT.bois, Name = "Plancher" })
	for _, cote in ipairs({ { 0, -2.2, 4.6, 0.3 }, { 0, 2.2, 4.6, 0.3 }, { -2.2, 0, 0.3, 4.6 }, { 2.2, 0, 0.3, 4.6 } }) do
		K.deco({ Size = Vector3.new(cote[3], 1.6, cote[4]), Position = p + Vector3.new(cote[1], 10.2, cote[2]), Color = C.structure, Material = MAT.structure, Name = "Garde" })
	end
	K.deco({ Size = Vector3.new(5.6, 0.5, 5.6), Position = p + Vector3.new(0, 13.2, 0), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Toit" })
	for _, coin in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }) do
		K.deco({ Size = Vector3.new(0.3, 2.6, 0.3), Position = p + Vector3.new(coin[1], 11.8, coin[2]), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Montant" })
	end
	local phare = K.boule(p + Vector3.new(0, 13.9, 0), 1.1, { Color = C.danger, Material = Enum.Material.Neon, Name = "Gyrophare", CanCollide = false, CanTouch = false, CastShadow = false })
	K.lumiere(phare, C.danger, 24, 1.8)
end

function K.special(position)
	local fabriquer = SPECIAUX[THEME.decor.special]
	if fabriquer then
		fabriquer(position)
	else
		K.cristaux(position, 5, C.accent)
	end
end

-- Un décor tiré au hasard parmi ceux du thème, posé sur `position` (au sol).
function K.decorHasard(position)
	local tirage = rng:NextNumber()
	if tirage < 0.34 then
		K.arbre(position, K.hasard(0.8, 1.3))
	elseif tirage < 0.58 then
		K.rocher(position, K.hasard(1.6, 3.2))
	elseif tirage < 0.78 then
		K.lampe(position)
	elseif tirage < 0.9 then
		K.cristaux(position, K.hasard(2.4, 4.2), K.choisir({ C.accent, C.accent2 }))
	else
		K.special(position)
	end
end

--------------------------------------------------------------------------------
-- Gemmes à ramasser (1, 5 ou 25 points)
--------------------------------------------------------------------------------

function K.gemme(position, valeur)
	local infos = {
		[1] = { couleur = C.piece, taille = 1.5, pitch = 1.2 },
		[5] = { couleur = C.accent2, taille = 2.1, pitch = 0.95 },
		[25] = { couleur = C.accent, taille = 3, pitch = 0.7 },
	}
	local info = infos[valeur] or infos[1]
	local gemme = K.piece({
		Size = Vector3.new(info.taille * 0.7, info.taille, info.taille * 0.7),
		CFrame = CFrame.new(position) * CFrame.Angles(math.rad(10), math.rad(45), 0),
		Color = info.couleur,
		Material = Enum.Material.Glass,
		Transparency = 0.1,
		Reflectance = 0.2,
		CanCollide = false,
		CastShadow = false,
		Parent = D.Collectibles,
		Name = "Gemme",
	})
	gemme:SetAttribute("Valeur", valeur)
	if valeur > 1 then -- les petites gemmes n'éclairent pas : moins de lumières à calculer
		K.lumiere(gemme, info.couleur, 9, 1.6)
	end
	local son = Instance.new("Sound")
	son.SoundId = SON_COLLECTE
	son.Volume = 0.6
	son.PlaybackSpeed = info.pitch
	son.Parent = gemme
	K.emetteur(gemme, {
		Color = ColorSequence.new(info.couleur, Color3.new(1, 1, 1)),
		Size = NumberSequence.new(0.9, 0.2),
		Lifetime = NumberRange.new(0.5, 1),
		Rate = 0,
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Enabled = false,
	})
	return gemme
end
