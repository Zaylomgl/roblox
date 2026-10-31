--------------------------------------------------------------------------------
-- ✦ LES ÎLES CÉLESTES D'AURORA ✦
--
-- Map Roblox complète : un archipel d'îles flottantes baigné dans un lever de
-- soleil doré. Un Grand Cristal trône au centre, entouré de 4 îles reliées par
-- des ponts de bois : le Belvédère (spawn), la Forêt Lumineuse, l'Île des
-- Cascades et les Ruines d'Elyndor. Deux zones secrètes : une grotte cachée
-- derrière la grande cascade, et le Sanctuaire Céleste au-dessus des nuages.
--
-- UTILISATION :
--   1. Ouvre Roblox Studio (une place vide type "Baseplate" fait l'affaire).
--   2. Affiche la barre de commande : onglet View → Command Bar.
--   3. Colle TOUT ce script dans la barre de commande, puis appuie sur Entrée.
--   4. Lance Play : tu apparais sur le Belvédère, face au Grand Cristal.
--
-- Le script installe aussi automatiquement un Script serveur qui gère :
-- le leaderboard (🔮 Cristaux), la collecte + réapparition des cristaux,
-- les pads de saut vers le Sanctuaire, et toutes les animations (cristaux
-- qui flottent, anneaux qui tournent, éclats en orbite autour du cristal).
--
-- Tout se règle dans la table CONFIG ci-dessous. Relancer le script
-- reconstruit proprement la map (l'ancienne est supprimée).
--------------------------------------------------------------------------------

local CONFIG = {
	SEED = 1207,               -- change la graine pour varier les détails aléatoires
	HEURE = 7.4,               -- heure du jour (7.4 = lever de soleil doré ; essaie 17.3 pour le soir)
	QUALITE_MOBILE = false,    -- true = moins de décor et pas de profondeur de champ (plus fluide)
	DENSITE_DECOR = 1,         -- 0.5 = moitié moins d'arbres/fleurs/rochers, 1.5 = plus dense
	TEMPS_REAPPARITION = 25,   -- secondes avant qu'un cristal collecté réapparaisse
	MULTIPLICATEUR_PADS = 1,   -- augmente si les pads de saut ne propulsent pas assez haut
	SUPPRIMER_BASEPLATE = true,-- supprime la Baseplate et le SpawnLocation d'origine
	HAUTEUR_DISPARITION = 60,  -- altitude sous laquelle on retombe au spawn (chute dans le vide)
}

-- Palette : 4 familles de couleurs maximum pour garder une identité forte
-- (verts chauds, roche brune, cristal violet/turquoise, accents or/rose).
local PALETTE = {
	Herbe          = Color3.fromRGB(101, 173, 92),
	HerbeClaire    = Color3.fromRGB(133, 196, 105),
	Feuillage      = Color3.fromRGB(88, 158, 82),
	FeuillageClair = Color3.fromRGB(121, 184, 96),
	Rose           = Color3.fromRGB(255, 156, 196),
	RoseClair      = Color3.fromRGB(255, 190, 216),
	Bois           = Color3.fromRGB(105, 76, 52),
	BoisClair      = Color3.fromRGB(151, 112, 76),
	Roche          = Color3.fromRGB(92, 86, 82),
	RochePale      = Color3.fromRGB(126, 118, 111),
	Terre          = Color3.fromRGB(112, 84, 61),
	Pierre         = Color3.fromRGB(168, 158, 143),
	PierreClaire   = Color3.fromRGB(199, 188, 168),
	Eau            = Color3.fromRGB(96, 176, 218),
	Cristal        = Color3.fromRGB(158, 128, 255),
	CristalClair   = Color3.fromRGB(198, 178, 255),
	Turquoise      = Color3.fromRGB(96, 228, 214),
	Or             = Color3.fromRGB(255, 199, 92),
	Ambre          = Color3.fromRGB(255, 178, 96),
}

local TEXTURE_ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"
local TEXTURE_FUMEE = "rbxasset://textures/particles/smoke_main.dds"
local SON_COLLECTE = "rbxasset://sounds/electronicpingshort.wav"

local Lighting = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")

local rng = Random.new(CONFIG.SEED)

--------------------------------------------------------------------------------
-- 0. NETTOYAGE (le script est relançable : on supprime l'ancienne map)
--------------------------------------------------------------------------------

local ancienneMap = workspace:FindFirstChild("MapIlesCelestes")
if ancienneMap then ancienneMap:Destroy() end

local ancienScript = ServerScriptService:FindFirstChild("IlesCelestes_Script")
if ancienScript then ancienScript:Destroy() end

for _, nom in ipairs({
	"Aurora_Ciel", "Aurora_Atmosphere", "Aurora_Bloom",
	"Aurora_Couleurs", "Aurora_Rayons", "Aurora_Profondeur",
}) do
	local inst = Lighting:FindFirstChild(nom)
	if inst then inst:Destroy() end
end

local anciensNuages = workspace.Terrain:FindFirstChildOfClass("Clouds")
if anciensNuages then anciensNuages:Destroy() end

if CONFIG.SUPPRIMER_BASEPLATE then
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then baseplate:Destroy() end
	local vieuxSpawn = workspace:FindFirstChild("SpawnLocation")
	if vieuxSpawn then vieuxSpawn:Destroy() end
end

workspace.FallenPartsDestroyHeight = CONFIG.HAUTEUR_DISPARITION

--------------------------------------------------------------------------------
-- 1. DOSSIERS (tout est rangé proprement dans workspace.MapIlesCelestes)
--------------------------------------------------------------------------------

local map = Instance.new("Folder")
map.Name = "MapIlesCelestes"
map:SetAttribute("TempsReapparition", CONFIG.TEMPS_REAPPARITION)
map:SetAttribute("MultiplicateurPads", CONFIG.MULTIPLICATEUR_PADS)

local dossierIles = Instance.new("Folder"); dossierIles.Name = "Iles"; dossierIles.Parent = map
local dossierPonts = Instance.new("Folder"); dossierPonts.Name = "Ponts"; dossierPonts.Parent = map
local dossierCollectibles = Instance.new("Folder"); dossierCollectibles.Name = "Collectibles"; dossierCollectibles.Parent = map
local dossierRotors = Instance.new("Folder"); dossierRotors.Name = "Rotors"; dossierRotors.Parent = map
local dossierOrbites = Instance.new("Folder"); dossierOrbites.Name = "Orbites"; dossierOrbites.Parent = map
local dossierPads = Instance.new("Folder"); dossierPads.Name = "JumpPads"; dossierPads.Parent = map
local dossierEffets = Instance.new("Folder"); dossierEffets.Name = "Effets"; dossierEffets.Parent = map

--------------------------------------------------------------------------------
-- 2. PETITS OUTILS DE CONSTRUCTION
--------------------------------------------------------------------------------

local function jitter(n)
	return rng:NextNumber(-n, n)
end

-- Fait tourner un vecteur horizontal autour de l'axe Y (en radians).
local function tourner(v, a)
	return Vector3.new(
		v.X * math.cos(a) - v.Z * math.sin(a),
		0,
		v.X * math.sin(a) + v.Z * math.cos(a)
	)
end

-- Ajuste les quantités de décor selon la config (densité / qualité mobile).
local function quantite(n)
	local facteur = CONFIG.DENSITE_DECOR * (CONFIG.QUALITE_MOBILE and 0.6 or 1)
	return math.max(1, math.floor(n * facteur + 0.5))
end

local function creerPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CastShadow = props.CastShadow ~= false
	p.CanCollide = props.CanCollide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then p.Shape = props.Shape end
	p.Size = props.Size or Vector3.new(1, 1, 1)
	p.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	p.Color = props.Color or Color3.fromRGB(255, 255, 255)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.Name = props.Name or "Decor"
	p.Parent = props.Parent or map
	return p
end

-- Cylindre vertical (les cylindres Roblox ont leur axe sur X, on les redresse).
local function cylindreVertical(position, hauteur, diametre, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(hauteur, diametre, diametre)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	props.Position = nil
	return creerPart(props)
end

-- Bloc invisible servant de support aux émetteurs de particules.
local function blocInvisible(cf, taille, dossier)
	if typeof(cf) == "Vector3" then cf = CFrame.new(cf) end
	return creerPart({
		CFrame = cf, Size = taille, Transparency = 1,
		CanCollide = false, CastShadow = false,
		Parent = dossier, Name = "Emetteur",
	})
end

local function creerEmetteur(parent, props)
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

local function creerLumiere(parent, couleur, portee, luminosite)
	local l = Instance.new("PointLight")
	l.Color = couleur
	l.Range = portee
	l.Brightness = luminosite
	l.Shadows = false
	l.Parent = parent
	return l
end

-- Sème n éléments dans un anneau (rayonMin → rayonMax) autour d'un centre.
local function semer(centre, rayonMin, rayonMax, n, fabriquer)
	for i = 1, n do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(rayonMin, rayonMax)
		fabriquer(centre + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist), i)
	end
end

--------------------------------------------------------------------------------
-- 3. AMBIANCE : lumière dorée, atmosphère, ciel, nuages
--------------------------------------------------------------------------------

pcall(function()
	Lighting.Technology = Enum.Technology.Future -- meilleures ombres/lumières si dispo
end)

Lighting.ClockTime = CONFIG.HEURE
Lighting.GeographicLatitude = 25
Lighting.Brightness = 2.8
Lighting.ExposureCompensation = 0.12
Lighting.Ambient = Color3.fromRGB(84, 76, 92)
Lighting.OutdoorAmbient = Color3.fromRGB(134, 118, 122)
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.15

local ciel = Instance.new("Sky")
ciel.Name = "Aurora_Ciel"
ciel.SunAngularSize = 16
ciel.MoonAngularSize = 9
ciel.StarCount = 2500
ciel.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "Aurora_Atmosphere"
atmosphere.Density = 0.32
atmosphere.Offset = 0.6
atmosphere.Color = Color3.fromRGB(213, 160, 130)
atmosphere.Decay = Color3.fromRGB(122, 92, 106)
atmosphere.Glare = 0.32
atmosphere.Haze = 1.9
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "Aurora_Bloom"
bloom.Intensity = 0.45
bloom.Size = 26
bloom.Threshold = 1.15
bloom.Parent = Lighting

local couleurs = Instance.new("ColorCorrectionEffect")
couleurs.Name = "Aurora_Couleurs"
couleurs.Brightness = 0.015
couleurs.Contrast = 0.06
couleurs.Saturation = 0.12
couleurs.TintColor = Color3.fromRGB(255, 246, 234)
couleurs.Parent = Lighting

local rayons = Instance.new("SunRaysEffect")
rayons.Name = "Aurora_Rayons"
rayons.Intensity = 0.18
rayons.Spread = 0.9
rayons.Parent = Lighting

if not CONFIG.QUALITE_MOBILE then
	local profondeur = Instance.new("DepthOfFieldEffect")
	profondeur.Name = "Aurora_Profondeur"
	profondeur.FarIntensity = 0.12
	profondeur.FocusDistance = 60
	profondeur.InFocusRadius = 120
	profondeur.NearIntensity = 0.2
	profondeur.Parent = Lighting
end

local nuages = Instance.new("Clouds")
nuages.Cover = 0.52
nuages.Density = 0.32
nuages.Color = Color3.fromRGB(255, 228, 205)
nuages.Parent = workspace.Terrain

--------------------------------------------------------------------------------
-- 4. PRÉFABS : arbres, lanternes, rochers, fleurs, champignons, colonnes...
--------------------------------------------------------------------------------

local function creerRocher(position, taille, dossier)
	creerPart({
		Size = Vector3.new(taille * rng:NextNumber(0.8, 1.2), taille * rng:NextNumber(0.6, 0.9), taille * rng:NextNumber(0.8, 1.2)),
		CFrame = CFrame.new(position + Vector3.new(0, taille * 0.25, 0))
			* CFrame.Angles(jitter(0.3), rng:NextNumber(0, math.pi * 2), jitter(0.3)),
		Material = Enum.Material.Slate,
		Color = rng:NextNumber() < 0.5 and PALETTE.Roche or PALETTE.RochePale,
		Parent = dossier, Name = "Rocher",
	})
end

local function creerFleur(position, dossier)
	local teintes = { PALETTE.RoseClair, PALETTE.Ambre, Color3.fromRGB(245, 240, 220) }
	cylindreVertical(position + Vector3.new(0, 0.45, 0), 0.9, 0.16, {
		Material = Enum.Material.Grass, Color = PALETTE.FeuillageClair,
		CanCollide = false, CastShadow = false, Parent = dossier, Name = "Fleur",
	})
	creerPart({
		Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5),
		Position = position + Vector3.new(0, 1, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = teintes[rng:NextInteger(1, #teintes)],
		CanCollide = false, CastShadow = false, Parent = dossier, Name = "Fleur",
	})
end

-- type d'arbre : "classique", "luciole" (fleurs roses + pétales) ou "or"
local function creerArbre(position, echelle, genre, dossier)
	echelle = echelle or 1
	genre = genre or "classique"
	local couleurTronc = (genre == "classique") and PALETTE.Bois or PALETTE.BoisClair
	if genre == "or" then couleurTronc = Color3.fromRGB(226, 214, 196) end

	cylindreVertical(position + Vector3.new(0, 3.2 * echelle, 0), 6.4 * echelle, 1.4 * echelle, {
		Material = Enum.Material.Wood, Color = couleurTronc,
		Parent = dossier, Name = "Tronc",
	})

	local teintes
	if genre == "classique" then
		teintes = { PALETTE.Feuillage, PALETTE.FeuillageClair }
	elseif genre == "luciole" then
		teintes = { PALETTE.Rose, PALETTE.RoseClair }
	else
		teintes = { PALETTE.Or, Color3.fromRGB(255, 220, 140) }
	end

	local feuillageHaut
	for i = 1, 3 do
		local taille = (7.6 - i * 1.5) * echelle
		feuillageHaut = creerPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(taille, taille, taille),
			Position = position + Vector3.new(jitter(1.1 * echelle), (4.6 + i * 1.8) * echelle, jitter(1.1 * echelle)),
			Material = Enum.Material.Grass,
			Color = teintes[(i % 2) + 1],
			CanCollide = false, Parent = dossier, Name = "Feuillage",
		})
	end

	if genre == "luciole" then
		creerLumiere(feuillageHaut, PALETTE.Rose, 13 * echelle, 0.7)
		creerEmetteur(feuillageHaut, { -- pétales qui tombent doucement
			Color = ColorSequence.new(PALETTE.RoseClair, PALETTE.Rose),
			Size = NumberSequence.new(0.4, 0.15),
			Transparency = NumberSequence.new(0.1, 1),
			Lifetime = NumberRange.new(4, 6),
			Rate = 2.5,
			Speed = NumberRange.new(0.5, 1.2),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0.4, -2.4, 0),
			LightEmission = 0.55,
		})
	elseif genre == "or" then
		creerLumiere(feuillageHaut, PALETTE.Or, 18 * echelle, 1)
		creerEmetteur(feuillageHaut, {
			Color = ColorSequence.new(PALETTE.Or, Color3.fromRGB(255, 235, 180)),
			Size = NumberSequence.new(0.5, 0.2),
			Lifetime = NumberRange.new(3, 5),
			Rate = 4,
			Speed = NumberRange.new(0.4, 1),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -1.2, 0),
			LightEmission = 1,
		})
	end
end

local function creerLanterne(position, dossier)
	cylindreVertical(position + Vector3.new(0, 2, 0), 4, 0.35, {
		Material = Enum.Material.Wood, Color = PALETTE.Bois,
		Parent = dossier, Name = "Lanterne",
	})
	local lampe = creerPart({
		Size = Vector3.new(1.1, 1.4, 1.1),
		Position = position + Vector3.new(0, 4.4, 0),
		Material = Enum.Material.Neon, Color = PALETTE.Ambre,
		CanCollide = false, Parent = dossier, Name = "Lanterne",
	})
	creerPart({
		Size = Vector3.new(1.4, 0.3, 1.4),
		Position = position + Vector3.new(0, 5.25, 0),
		Material = Enum.Material.Wood, Color = PALETTE.Bois,
		CanCollide = false, Parent = dossier, Name = "Lanterne",
	})
	creerLumiere(lampe, PALETTE.Ambre, 15, 1.1)
	creerEmetteur(lampe, { -- lucioles autour de la lanterne
		Color = ColorSequence.new(Color3.fromRGB(255, 236, 150)),
		Size = NumberSequence.new(0.22, 0.1),
		Transparency = NumberSequence.new(0.15, 1),
		Lifetime = NumberRange.new(3, 5),
		Rate = 1.6,
		Speed = NumberRange.new(0.3, 0.9),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
	})
end

local function creerChampignon(position, echelle, dossier)
	echelle = echelle or 1
	cylindreVertical(position + Vector3.new(0, 0.8 * echelle, 0), 1.6 * echelle, 0.7 * echelle, {
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(235, 228, 210),
		CanCollide = false, Parent = dossier, Name = "Champignon",
	})
	local chapeau = creerPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.1 * echelle, 2.1 * echelle, 2.1 * echelle),
		Position = position + Vector3.new(0, 1.7 * echelle, 0),
		Material = Enum.Material.Neon, Color = PALETTE.Turquoise,
		CanCollide = false, Parent = dossier, Name = "Champignon",
	})
	creerLumiere(chapeau, PALETTE.Turquoise, 11 * echelle, 0.9)
end

local function creerColonne(position, hauteur, cassee, dossier)
	creerPart({
		Size = Vector3.new(3.4, 1, 3.4), Position = position + Vector3.new(0, 0.5, 0),
		Material = Enum.Material.Sandstone, Color = PALETTE.PierreClaire,
		Parent = dossier, Name = "Colonne",
	})
	local h = cassee and rng:NextNumber(2.5, 4.5) or hauteur
	cylindreVertical(position + Vector3.new(0, 1 + h / 2, 0), h, 2.4, {
		Material = Enum.Material.Sandstone, Color = PALETTE.Pierre,
		Parent = dossier, Name = "Colonne",
	})
	if cassee then
		local angle = rng:NextNumber(0, math.pi * 2)
		creerPart({ -- le tronçon effondré, couché dans l'herbe
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(math.max(2, hauteur - h), 2.4, 2.4),
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 4.5, 1.2, math.sin(angle) * 4.5))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(jitter(6))),
			Material = Enum.Material.Sandstone, Color = PALETTE.PierreClaire,
			Parent = dossier, Name = "ColonneTombee",
		})
	else
		creerPart({
			Size = Vector3.new(3.2, 1, 3.2), Position = position + Vector3.new(0, 1.5 + h, 0),
			Material = Enum.Material.Sandstone, Color = PALETTE.PierreClaire,
			Parent = dossier, Name = "Chapiteau",
		})
	end
	if rng:NextNumber() < 0.7 then -- un peu de mousse au pied
		cylindreVertical(position + Vector3.new(jitter(1), 1.06, jitter(1)), 0.25, rng:NextNumber(2.4, 3.6), {
			Material = Enum.Material.Grass, Color = PALETTE.Feuillage,
			CanCollide = false, CastShadow = false, Parent = dossier, Name = "Mousse",
		})
	end
end

local function creerBanc(cf, dossier)
	creerPart({ Size = Vector3.new(5, 0.45, 1.6), CFrame = cf * CFrame.new(0, 1.15, 0),
		Material = Enum.Material.WoodPlanks, Color = PALETTE.BoisClair, Parent = dossier, Name = "Banc" })
	creerPart({ Size = Vector3.new(5, 1.5, 0.4), CFrame = cf * CFrame.new(0, 1.9, 0.75) * CFrame.Angles(math.rad(-8), 0, 0),
		Material = Enum.Material.WoodPlanks, Color = PALETTE.BoisClair, Parent = dossier, Name = "Banc" })
	for _, cote in ipairs({ -1.9, 1.9 }) do
		creerPart({ Size = Vector3.new(0.5, 1, 1.4), CFrame = cf * CFrame.new(cote, 0.5, 0),
			Material = Enum.Material.Wood, Color = PALETTE.Bois, Parent = dossier, Name = "Banc" })
	end
end

local function creerPanneau(position, texte, dossier)
	local socle = creerPart({
		Size = Vector3.new(2.6, 3.2, 0.9),
		CFrame = CFrame.new(position + Vector3.new(0, 1.6, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(jitter(4))),
		Material = Enum.Material.Slate, Color = PALETTE.RochePale,
		Parent = dossier, Name = "Panneau",
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 260, 0, 56)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 220
	gui.Parent = socle
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = texte
	label.TextColor3 = Color3.fromRGB(255, 228, 164)
	label.TextStrokeColor3 = Color3.fromRGB(46, 32, 28)
	label.TextStrokeTransparency = 0.35
	label.Parent = gui
end

-- Cascade : un voile d'eau translucide + écume qui tombe + brume au pied.
local function creerCascade(positionHaut, direction, largeur, hauteurChute, dossier)
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	local repere = CFrame.lookAt(positionHaut, positionHaut + direction)

	creerPart({
		Size = Vector3.new(largeur, hauteurChute, 0.7),
		CFrame = repere * CFrame.new(0, -hauteurChute / 2 + 0.6, -1.3),
		Material = Enum.Material.Glass, Color = PALETTE.Eau, Transparency = 0.45,
		CanCollide = false, CastShadow = false, Parent = dossier, Name = "VoileCascade",
	})

	local hautEmetteur = blocInvisible(repere * CFrame.new(0, 0.4, -1.5), Vector3.new(largeur, 0.8, 0.8), dossier)
	creerEmetteur(hautEmetteur, { -- écume qui dévale
		Texture = TEXTURE_FUMEE,
		Color = ColorSequence.new(Color3.fromRGB(235, 248, 255), PALETTE.Eau),
		Size = NumberSequence.new(largeur / 6, largeur / 3),
		Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(hauteurChute / 14, hauteurChute / 9),
		Rate = math.min(50, largeur * 3.2),
		Speed = NumberRange.new(6, 10),
		SpreadAngle = Vector2.new(6, 6),
		Acceleration = Vector3.new(0, -55, 0),
		EmissionDirection = Enum.NormalId.Bottom,
		LightEmission = 0.12,
	})

	local basEmetteur = blocInvisible(repere * CFrame.new(0, -hauteurChute - 1.5, -2.4), Vector3.new(largeur + 2, 1, 3), dossier)
	creerEmetteur(basEmetteur, { -- brume au point de chute
		Texture = TEXTURE_FUMEE,
		Color = ColorSequence.new(Color3.fromRGB(240, 250, 255)),
		Size = NumberSequence.new(largeur / 3, largeur / 1.6),
		Transparency = NumberSequence.new(0.6, 1),
		Lifetime = NumberRange.new(2.4, 3.6),
		Rate = math.min(14, largeur),
		Speed = NumberRange.new(0.8, 2),
		SpreadAngle = Vector2.new(45, 45),
	})
end

--------------------------------------------------------------------------------
-- 5. LES ÎLES : squelette générique (plateau d'herbe + cône rocheux + brume)
--------------------------------------------------------------------------------

-- def.centre = centre de la SURFACE (le dessus de l'herbe est à cette hauteur)
local ILES = {
	Cristal = { nom = "Ile du Grand Cristal", centre = Vector3.new(0, 200, 0), rayon = 55, couleurHerbe = PALETTE.Herbe },
	Spawn = { nom = "Le Belvedere", centre = Vector3.new(-170, 190, 0), rayon = 45, couleurHerbe = PALETTE.Herbe },
	Foret = { nom = "Foret Lumineuse", centre = Vector3.new(10, 206, -178), rayon = 52, couleurHerbe = PALETTE.Feuillage },
	Cascades = { nom = "Ile des Cascades", centre = Vector3.new(170, 186, 28), rayon = 48, couleurHerbe = PALETTE.Herbe },
	Ruines = { nom = "Ruines d'Elyndor", centre = Vector3.new(28, 214, 175), rayon = 42, couleurHerbe = Color3.fromRGB(148, 176, 100) },
	Sanctuaire = { nom = "Sanctuaire Celeste", centre = Vector3.new(62, 318, 208), rayon = 17, couleurHerbe = PALETTE.HerbeClaire },
}

local function creerIle(def)
	local dossier = Instance.new("Folder")
	dossier.Name = def.nom
	dossier.Parent = dossierIles
	def.dossier = dossier

	local c, r = def.centre, def.rayon

	-- le plateau d'herbe, son liseré clair et la couche de terre
	cylindreVertical(c - Vector3.new(0, 1.2, 0), 2.4, r * 2, {
		Material = Enum.Material.Grass, Color = def.couleurHerbe,
		Parent = dossier, Name = "Plateau",
	})
	cylindreVertical(c - Vector3.new(0, 2.1, 0), 1.1, r * 2 + 1.8, {
		Material = Enum.Material.Grass, Color = PALETTE.HerbeClaire,
		Parent = dossier, Name = "Lisere",
	})
	cylindreVertical(c - Vector3.new(0, 4.1, 0), 3, r * 1.94, {
		Material = Enum.Material.Ground, Color = PALETTE.Terre,
		Parent = dossier, Name = "Terre",
	})

	-- le cône rocheux renversé qui pend sous l'île
	local fractions = { 0.82, 0.64, 0.47, 0.31, 0.17 }
	local hauteurCouche = math.max(4, r * 0.36)
	local y = c.Y - 5.6
	for i, fraction in ipairs(fractions) do
		y -= hauteurCouche * 0.92
		cylindreVertical(Vector3.new(c.X + jitter(r * 0.05), y, c.Z + jitter(r * 0.05)), hauteurCouche, r * 2 * fraction, {
			Material = Enum.Material.Slate,
			Color = (i % 2 == 0) and PALETTE.Roche or PALETTE.RochePale,
			Parent = dossier, Name = "Roche",
		})
	end
	local basY = y - hauteurCouche * 0.7
	creerPart({
		Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.3, r * 0.3, r * 0.3),
		Position = Vector3.new(c.X, basY, c.Z),
		Material = Enum.Material.Slate, Color = PALETTE.Roche,
		Parent = dossier, Name = "Pointe",
	})

	-- éclats de roche en lévitation sous l'île (magie des îles volantes)
	for _ = 1, quantite(6) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(r * 0.25, r * 0.8)
		local taille = rng:NextNumber(2, 5)
		local pos = Vector3.new(c.X + math.cos(angle) * dist, basY - rng:NextNumber(3, 13), c.Z + math.sin(angle) * dist)
		local eclat = creerPart({
			Size = Vector3.new(taille, taille * 0.8, taille * 1.15),
			CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi)),
			Material = Enum.Material.Slate, Color = PALETTE.Roche,
			CanCollide = false, Parent = dossier, Name = "EclatFlottant",
		})
		if rng:NextNumber() < 0.35 then -- certains portent un petit cristal
			creerPart({
				Size = Vector3.new(0.8, 1.8, 0.8),
				CFrame = eclat.CFrame * CFrame.new(0, taille * 0.6, 0) * CFrame.Angles(0, math.rad(45), 0),
				Material = Enum.Material.Neon, Color = PALETTE.Cristal,
				CanCollide = false, CastShadow = false, Parent = dossier, Name = "EclatCristal",
			})
		end
	end

	-- quelques rochers sur le pourtour du plateau
	semer(c, r * 0.82, r * 0.94, quantite(5 + math.floor(r / 14)), function(pos)
		creerRocher(pos, rng:NextNumber(1.6, 3.4), dossier)
	end)

	-- brume chaude qui flotte sous l'île
	local brume = blocInvisible(Vector3.new(c.X, basY - 4, c.Z), Vector3.new(r * 0.8, 2, r * 0.8), dossier)
	creerEmetteur(brume, {
		Texture = TEXTURE_FUMEE,
		Color = ColorSequence.new(Color3.fromRGB(255, 232, 212)),
		Size = NumberSequence.new(10, 17),
		Transparency = NumberSequence.new(0.78, 1),
		Lifetime = NumberRange.new(4, 6),
		Rate = 2.2,
		Speed = NumberRange.new(0.4, 1.2),
		SpreadAngle = Vector2.new(60, 60),
	})

	return dossier
end

for _, cle in ipairs({ "Cristal", "Spawn", "Foret", "Cascades", "Ruines", "Sanctuaire" }) do
	creerIle(ILES[cle])
end

-- Point sur le bord d'une île, en direction d'une cible (pour ponts et chemins).
local function pointBord(def, vers)
	local dir = Vector3.new(vers.X - def.centre.X, 0, vers.Z - def.centre.Z).Unit
	return def.centre + dir * (def.rayon - 3) + Vector3.new(0, 0.4, 0)
end

--------------------------------------------------------------------------------
-- 6. COLLECTIBLES : les cristaux à ramasser (1, 5 ou 20 points)
--------------------------------------------------------------------------------

local function creerCristalCollectible(position, valeur)
	local infos = {
		[1] = { couleur = PALETTE.CristalClair, taille = Vector3.new(1.1, 2.4, 1.1), pitch = 1.15 },
		[5] = { couleur = PALETTE.Turquoise, taille = Vector3.new(1.35, 2.9, 1.35), pitch = 0.95 },
		[20] = { couleur = PALETTE.Or, taille = Vector3.new(1.7, 3.6, 1.7), pitch = 0.7 },
	}
	local info = infos[valeur] or infos[1]

	local cristal = creerPart({
		Size = info.taille,
		CFrame = CFrame.new(position) * CFrame.Angles(math.rad(8), math.rad(45), 0),
		Material = Enum.Material.Neon, Color = info.couleur,
		CanCollide = false, CastShadow = false,
		Parent = dossierCollectibles, Name = "Cristal",
	})
	cristal:SetAttribute("Valeur", valeur)
	creerLumiere(cristal, info.couleur, 9, 1.4)

	local son = Instance.new("Sound")
	son.SoundId = SON_COLLECTE
	son.Volume = 0.6
	son.PlaybackSpeed = info.pitch
	son.Parent = cristal

	creerEmetteur(cristal, { -- éclat de particules à la collecte (déclenché par le script)
		Color = ColorSequence.new(info.couleur, Color3.new(1, 1, 1)),
		Size = NumberSequence.new(0.9, 0.2),
		Lifetime = NumberRange.new(0.5, 1),
		Rate = 0,
		Speed = NumberRange.new(4, 9),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Enabled = false,
	})
	return cristal
end

local function placerCristauxZone(def, nb, rayonMin)
	semer(def.centre, rayonMin or 8, def.rayon - 8, nb, function(pos)
		creerCristalCollectible(pos + Vector3.new(0, 2.6, 0), 1)
	end)
end

--------------------------------------------------------------------------------
-- 7. LE GRAND CRISTAL (le landmark visible depuis toute la map)
--------------------------------------------------------------------------------

do
	local def = ILES.Cristal
	local d = def.dossier
	local base = def.centre

	-- socle de pierre en 3 marches
	local y = base.Y
	for _, info in ipairs({ { 26, 1.8 }, { 20, 1.6 }, { 14, 1.4 } }) do
		cylindreVertical(Vector3.new(base.X, y + info[2] / 2, base.Z), info[2], info[1], {
			Material = Enum.Material.Slate, Color = PALETTE.Pierre,
			Parent = d, Name = "Socle",
		})
		y += info[2]
	end
	local sommetSocle = Vector3.new(base.X, y, base.Z)

	-- le cristal géant : un coeur néon dans une enveloppe de verre
	creerPart({
		Size = Vector3.new(7, 44, 7),
		CFrame = CFrame.new(sommetSocle + Vector3.new(0, 18, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon, Color = PALETTE.Cristal,
		Parent = d, Name = "GrandCristal",
	})
	creerPart({
		Size = Vector3.new(10.5, 36, 10.5),
		CFrame = CFrame.new(sommetSocle + Vector3.new(0, 15, 0)) * CFrame.Angles(0, math.rad(67), 0),
		Material = Enum.Material.Glass, Color = PALETTE.CristalClair, Transparency = 0.55,
		CanCollide = false, Parent = d, Name = "EnveloppeCristal",
	})

	-- cristaux satellites plantés autour du socle
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local dist = rng:NextNumber(8.5, 11.5)
		local hauteur = rng:NextNumber(8, 16)
		creerPart({
			Size = Vector3.new(2.2, hauteur, 2.2),
			CFrame = CFrame.new(sommetSocle + Vector3.new(math.cos(angle) * dist, hauteur / 2 - 1, math.sin(angle) * dist))
				* CFrame.Angles(math.rad(jitter(14)), angle + math.rad(45), math.rad(jitter(14))),
			Material = Enum.Material.Neon,
			Color = (i % 2 == 0) and PALETTE.Cristal or PALETTE.Turquoise,
			Parent = d, Name = "CristalSatellite",
		})
	end

	-- pilier de lumière qui monte vers le ciel
	cylindreVertical(sommetSocle + Vector3.new(0, 120, 0), 240, 2.6, {
		Material = Enum.Material.Neon, Color = PALETTE.CristalClair, Transparency = 0.68,
		CanCollide = false, CastShadow = false, Parent = d, Name = "PilierDeLumiere",
	})

	-- anneaux lumineux inclinés (le script de jeu les fait tourner)
	for _, info in ipairs({ { 30, 12, 0.5 }, { 24, 21, -0.75 }, { 17, 30, 1.05 } }) do
		local anneau = creerPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, info[1], info[1]),
			CFrame = CFrame.new(sommetSocle + Vector3.new(0, info[2], 0)) * CFrame.Angles(math.rad(12), 0, math.rad(90)),
			Material = Enum.Material.Neon, Color = PALETTE.CristalClair, Transparency = 0.55,
			CanCollide = false, CastShadow = false, Parent = dossierRotors, Name = "Anneau",
		})
		anneau:SetAttribute("VitesseRotation", info[3])
	end

	-- éclats de cristal en orbite (animés par le script de jeu)
	for i = 1, 6 do
		local eclat = creerPart({
			Size = Vector3.new(1.1, 2.6, 1.1),
			Position = sommetSocle + Vector3.new(0, 18, 0),
			Material = Enum.Material.Neon, Color = PALETTE.Turquoise,
			CanCollide = false, CastShadow = false, Parent = dossierOrbites, Name = "EclatOrbital",
		})
		eclat:SetAttribute("CentreOrbite", sommetSocle + Vector3.new(0, 18, 0))
		eclat:SetAttribute("RayonOrbite", 13 + i * 1.4)
		eclat:SetAttribute("VitesseOrbite", (i % 2 == 0) and 0.45 or -0.6)
		eclat:SetAttribute("Phase", i * (math.pi / 3))
	end

	-- lumières du coeur + étincelles qui montent le long du pilier
	local coeur = blocInvisible(sommetSocle + Vector3.new(0, 16, 0), Vector3.new(1, 1, 1), d)
	creerLumiere(coeur, PALETTE.Cristal, 60, 1.6)
	creerLumiere(coeur, PALETTE.Turquoise, 32, 0.8)
	local souffle = blocInvisible(sommetSocle + Vector3.new(0, 3, 0), Vector3.new(10, 2, 10), d)
	creerEmetteur(souffle, {
		Color = ColorSequence.new(PALETTE.CristalClair, PALETTE.Turquoise),
		Size = NumberSequence.new(0.6, 0.25),
		Lifetime = NumberRange.new(3, 5),
		Rate = 8,
		Speed = NumberRange.new(2, 4.5),
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 2, 0),
		LightEmission = 1,
	})

	-- runes lumineuses au sol + menhirs penchés vers le cristal
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local pos = base + Vector3.new(math.cos(angle) * 16, 0.25, math.sin(angle) * 16)
		creerPart({
			Size = Vector3.new(2.2, 0.35, 1.3),
			CFrame = CFrame.lookAt(pos, Vector3.new(base.X, pos.Y, base.Z)),
			Material = Enum.Material.Neon, Color = PALETTE.Turquoise, Transparency = 0.25,
			CanCollide = false, Parent = d, Name = "Rune",
		})
	end
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2 + 0.4
		local pos = base + Vector3.new(math.cos(angle) * 21, 0, math.sin(angle) * 21)
		creerPart({
			Size = Vector3.new(2.8, rng:NextNumber(5.5, 7.5), 1.9),
			CFrame = CFrame.lookAt(pos + Vector3.new(0, 3.2, 0), Vector3.new(base.X, pos.Y + 3.2, base.Z))
				* CFrame.Angles(math.rad(-8), 0, math.rad(jitter(5))),
			Material = Enum.Material.Slate, Color = PALETTE.Roche,
			Parent = d, Name = "Menhir",
		})
	end

	-- ceinture d'arbres à lucioles et de lanternes autour du sanctuaire du cristal
	semer(base, 30, 40, quantite(4), function(pos)
		creerArbre(pos, rng:NextNumber(0.9, 1.2), "luciole", d)
	end)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + 0.25
		creerLanterne(base + Vector3.new(math.cos(angle) * 26, 0, math.sin(angle) * 26), d)
	end
	semer(base, 24, def.rayon - 9, quantite(14), function(pos) creerFleur(pos, d) end)

	placerCristauxZone(def, 6, 26)
end

--------------------------------------------------------------------------------
-- 8. LE BELVÉDÈRE (île de spawn — la première impression, la plus belle vue)
--------------------------------------------------------------------------------

do
	local def = ILES.Spawn
	local d = def.dossier
	local c = def.centre
	local versCristal = ILES.Cristal.centre

	-- place dallée avec un parvis clair
	cylindreVertical(c + Vector3.new(-6, 0.25, 0), 0.5, 30, {
		Material = Enum.Material.Cobblestone, Color = PALETTE.Pierre, Parent = d, Name = "Place",
	})
	cylindreVertical(c + Vector3.new(-6, 0.56, 0), 0.35, 21, {
		Material = Enum.Material.Slate, Color = PALETTE.PierreClaire, Parent = d, Name = "Place",
	})

	-- le spawn regarde droit vers le Grand Cristal
	local lieuApparition = Instance.new("SpawnLocation")
	lieuApparition.Anchored = true
	lieuApparition.Neutral = true
	lieuApparition.Duration = 0
	lieuApparition.Size = Vector3.new(10, 1, 10)
	lieuApparition.Material = Enum.Material.Slate
	lieuApparition.Color = PALETTE.PierreClaire
	lieuApparition.CFrame = CFrame.lookAt(c + Vector3.new(-6, 1.1, 0), Vector3.new(versCristal.X, c.Y + 1.1, versCristal.Z))
	lieuApparition.Parent = d

	-- lanternes autour de la place + banc face au panorama
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + math.pi / 4
		creerLanterne(c + Vector3.new(-6 + math.cos(angle) * 13, 0.6, math.sin(angle) * 13), d)
	end
	local posBanc = c + Vector3.new(9, 0.4, 8)
	creerBanc(CFrame.lookAt(posBanc, Vector3.new(versCristal.X, posBanc.Y, versCristal.Z)), d)

	creerPanneau(c + Vector3.new(-2, 0.3, -13), "☁ Le Belvedere d'Aurora ☁", d)

	-- un bosquet derrière le spawn (le côté cristal reste dégagé pour la vue)
	for _, decalage in ipairs({ Vector3.new(-26, 0, -14), Vector3.new(-30, 0, 4), Vector3.new(-22, 0, 16) }) do
		creerArbre(c + decalage, rng:NextNumber(0.9, 1.3), "classique", d)
	end
	creerArbre(c + Vector3.new(-14, 0, 26), 1, "luciole", d)

	semer(c, 16, def.rayon - 7, quantite(14), function(pos)
		if pos.X < c.X + 8 then creerFleur(pos, d) end -- on garde le devant net
	end)
	semer(c, 24, def.rayon - 8, quantite(4), function(pos)
		creerRocher(pos, rng:NextNumber(1.5, 2.8), d)
	end)

	placerCristauxZone(def, 4, 14)
end

--------------------------------------------------------------------------------
-- 9. LA FORÊT LUMINEUSE (arbres roses, lucioles, clairière aux champignons)
--------------------------------------------------------------------------------

do
	local def = ILES.Foret
	local d = def.dossier
	local c = def.centre

	-- la canopée : un mélange d'arbres classiques et d'arbres à lucioles
	semer(c, 12, def.rayon - 8, quantite(13), function(pos)
		creerArbre(pos, rng:NextNumber(0.8, 1.4), "classique", d)
	end)
	semer(c, 14, def.rayon - 10, quantite(5), function(pos)
		creerArbre(pos, rng:NextNumber(0.9, 1.2), "luciole", d)
	end)

	-- la clairière au coeur de la forêt : un grand arbre rose cerclé de champignons
	local clairiere = c + Vector3.new(4, 0, 6)
	creerArbre(clairiere, 1.7, "luciole", d)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		creerChampignon(clairiere + Vector3.new(math.cos(angle) * 7, 0, math.sin(angle) * 7), rng:NextNumber(0.8, 1.3), d)
	end

	-- nappes de lucioles qui flottent entre les arbres
	for _ = 1, 3 do
		local zone = blocInvisible(c + Vector3.new(jitter(def.rayon * 0.5), 4, jitter(def.rayon * 0.5)), Vector3.new(22, 6, 22), d)
		creerEmetteur(zone, {
			Color = ColorSequence.new(Color3.fromRGB(214, 255, 150), Color3.fromRGB(255, 236, 150)),
			Size = NumberSequence.new(0.25, 0.12),
			Transparency = NumberSequence.new(0.2, 1),
			Lifetime = NumberRange.new(4, 7),
			Rate = 3,
			Speed = NumberRange.new(0.3, 0.8),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
		})
	end

	-- un sentier de lanternes depuis le pont jusqu'à la clairière
	local entree = pointBord(def, ILES.Cristal.centre)
	for _, t in ipairs({ 0.25, 0.55, 0.85 }) do
		local pos = entree:Lerp(clairiere, t) + Vector3.new(jitter(2) + 3, 0, jitter(2))
		creerLanterne(Vector3.new(pos.X, c.Y, pos.Z), d)
	end

	creerPanneau(entree + Vector3.new(2, 0, 5), "✿ Foret Lumineuse ✿", d)

	semer(c, 8, def.rayon - 7, quantite(18), function(pos) creerFleur(pos, d) end)
	semer(c, 10, def.rayon - 8, quantite(6), function(pos)
		creerRocher(pos, rng:NextNumber(1.4, 3), d)
	end)

	placerCristauxZone(def, 10, 10)
end

--------------------------------------------------------------------------------
-- 10. L'ÎLE DES CASCADES (bassin, rivière, chute dans le vide + GROTTE SECRÈTE)
--------------------------------------------------------------------------------

do
	local def = ILES.Cascades
	local d = def.dossier
	local c = def.centre
	local r = def.rayon
	local dirChute = Vector3.new(1, 0, 0.22).Unit -- direction de la grande cascade

	-- le bassin central bordé de rochers
	local centreBassin = c + Vector3.new(-8, 0, -4)
	cylindreVertical(centreBassin + Vector3.new(0, 0.45, 0), 0.9, 24, {
		Material = Enum.Material.Glass, Color = PALETTE.Eau, Transparency = 0.35,
		Parent = d, Name = "Bassin",
	})
	local eauBassin = blocInvisible(centreBassin + Vector3.new(0, 1, 0), Vector3.new(18, 0.5, 18), d)
	creerEmetteur(eauBassin, { -- reflets scintillants sur l'eau
		Color = ColorSequence.new(Color3.fromRGB(240, 252, 255)),
		Size = NumberSequence.new(0.35, 0.1),
		Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 4,
		Speed = NumberRange.new(0.1, 0.4),
		LightEmission = 0.8,
	})
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2 + jitter(0.12)
		local dirRocher = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if dirRocher:Dot(dirChute) < 0.72 then -- on laisse l'ouverture côté rivière
			creerRocher(centreBassin + dirRocher * 12.5, rng:NextNumber(1.8, 3.2), d)
		end
	end

	-- la source : un empilement de rochers d'où l'eau jaillit dans le bassin
	local posSource = centreBassin - dirChute * 13
	creerRocher(posSource, 4.5, d)
	creerRocher(posSource + Vector3.new(1.5, 2.2, -1), 3.4, d)
	creerRocher(posSource + Vector3.new(-1, 4, 0.8), 2.6, d)
	creerCascade(posSource + Vector3.new(0, 5, 0) + dirChute * 2, dirChute, 4, 5.5, d)

	-- la rivière qui traverse l'île jusqu'au bord
	local departRiviere = centreBassin + dirChute * 12
	local bordChute = pointBord(def, c + dirChute * 200)
	local nbSegments = 4
	for i = 0, nbSegments - 1 do
		local t1 = i / nbSegments
		local t2 = (i + 1) / nbSegments
		local p1 = departRiviere:Lerp(bordChute, t1)
		local p2 = departRiviere:Lerp(bordChute, t2)
		local milieu = (p1 + p2) / 2
		creerPart({
			Size = Vector3.new(6.5, 0.45, (p2 - p1).Magnitude + 1.2),
			CFrame = CFrame.lookAt(Vector3.new(milieu.X, c.Y + 0.18, milieu.Z), Vector3.new(p2.X, c.Y + 0.18, p2.Z)),
			Material = Enum.Material.Glass, Color = PALETTE.Eau, Transparency = 0.4,
			CanCollide = false, Parent = d, Name = "Riviere",
		})
	end

	-- LA grande cascade qui plonge dans le vide + deux petites décoratives
	creerCascade(bordChute + Vector3.new(0, 0.3, 0), dirChute, 15, 30, d)
	for _, decalage in ipairs({ 1.9, -2.1 }) do
		local dirMini = tourner(dirChute, decalage)
		creerCascade(pointBord(def, c + dirMini * 200) + Vector3.new(0, 0.2, 0), dirMini, 5, 16, d)
	end

	-- ✦ SECRET N°1 : la corniche derrière la cascade descend vers une grotte ✦
	local marchesTotal = 6
	for i = 1, marchesTotal do
		local dirMarche = tourner(dirChute, 0.17 * i)
		local rayonMarche = r - 1 - i * 1.1
		local posMarche = Vector3.new(c.X, 0, c.Z) + dirMarche * rayonMarche + Vector3.new(0, c.Y - 1.5 * i, 0)
		local marche = creerPart({
			Size = Vector3.new(4.8, 0.8, 3.6),
			CFrame = CFrame.lookAt(posMarche, Vector3.new(c.X, posMarche.Y, c.Z)),
			Material = Enum.Material.Slate, Color = PALETTE.RochePale,
			Parent = d, Name = "Corniche",
		})
		if i == 2 or i == 4 then -- des étincelles discrètes guident les curieux
			creerEmetteur(marche, {
				Color = ColorSequence.new(PALETTE.Turquoise),
				Size = NumberSequence.new(0.3, 0.1),
				Lifetime = NumberRange.new(2, 3),
				Rate = 2,
				Speed = NumberRange.new(0.3, 0.8),
				SpreadAngle = Vector2.new(180, 180),
				LightEmission = 1,
			})
		end
	end

	-- la grotte accrochée sous le flanc de l'île
	local dirGrotte = tourner(dirChute, 0.17 * (marchesTotal + 1.5))
	local posGrotte = Vector3.new(c.X, 0, c.Z) + dirGrotte * (r - 8) + Vector3.new(0, c.Y - 10.6, 0)
	local repere = CFrame.lookAt(posGrotte, posGrotte + dirGrotte) -- la porte regarde vers l'extérieur

	local murs = {
		{ Vector3.new(13, 1, 11), CFrame.new(0, 0, 0) },        -- sol
		{ Vector3.new(13, 1, 11), CFrame.new(0, 7.5, 0) },      -- plafond
		{ Vector3.new(13, 7, 1), CFrame.new(0, 4, 5) },         -- mur du fond
		{ Vector3.new(1, 7, 11), CFrame.new(6, 4, 0) },         -- mur gauche
		{ Vector3.new(1, 7, 11), CFrame.new(-6, 4, 0) },        -- mur droit
		{ Vector3.new(4.5, 7, 1), CFrame.new(4.25, 4, -5) },    -- façade (côté porte)
		{ Vector3.new(4.5, 7, 1), CFrame.new(-4.25, 4, -5) },
		{ Vector3.new(4, 1.6, 1), CFrame.new(0, 6.7, -5) },     -- linteau de la porte
	}
	for _, mur in ipairs(murs) do
		creerPart({
			Size = mur[1], CFrame = repere * mur[2],
			Material = Enum.Material.Slate, Color = PALETTE.Roche,
			Parent = d, Name = "Grotte",
		})
	end
	creerPart({ -- palier devant la porte
		Size = Vector3.new(5.5, 0.8, 4.5), CFrame = repere * CFrame.new(0, 0.1, -7),
		Material = Enum.Material.Slate, Color = PALETTE.RochePale,
		Parent = d, Name = "Grotte",
	})
	for _ = 1, 8 do -- camouflage : la grotte ressemble à un éperon rocheux
		local decalage = CFrame.new(jitter(7), rng:NextNumber(0, 7), rng:NextNumber(-2, 6))
		creerPart({
			Size = Vector3.new(rng:NextNumber(3, 6.5), rng:NextNumber(3, 6.5), rng:NextNumber(3, 6.5)),
			CFrame = repere * decalage * CFrame.Angles(jitter(0.5), jitter(3), jitter(0.5)),
			Material = Enum.Material.Slate, Color = PALETTE.Roche,
			Parent = d, Name = "Grotte",
		})
	end

	-- l'intérieur : champignons lumineux et cristaux bonus (5 points chacun)
	for _, decalage in ipairs({ Vector3.new(-4, 0.5, 3.5), Vector3.new(4.2, 0.5, 3), Vector3.new(-4.5, 0.5, -2), Vector3.new(3.8, 0.5, -2.5) }) do
		creerChampignon((repere * CFrame.new(decalage)).Position, rng:NextNumber(0.7, 1.1), d)
	end
	local lueurGrotte = blocInvisible(repere * CFrame.new(0, 4, 1), Vector3.new(1, 1, 1), d)
	creerLumiere(lueurGrotte, PALETTE.Turquoise, 18, 0.7)
	for _, decalage in ipairs({ Vector3.new(-2.8, 2.3, 2.4), Vector3.new(0.4, 2.3, 3.4), Vector3.new(3, 2.3, 1.6) }) do
		creerCristalCollectible((repere * CFrame.new(decalage)).Position, 5)
	end

	-- habillage du plateau
	semer(c, 14, r - 9, quantite(4), function(pos)
		if (pos - centreBassin).Magnitude > 16 then
			creerArbre(pos, rng:NextNumber(0.8, 1.15), "classique", d)
		end
	end)
	semer(c, 10, r - 7, quantite(9), function(pos)
		if (pos - centreBassin).Magnitude > 14 then creerFleur(pos, d) end
	end)
	creerLanterne(centreBassin + Vector3.new(0, 0, 14.5), d)
	creerPanneau(pointBord(def, ILES.Cristal.centre) + Vector3.new(-3, 0, 5), "≋ Ile des Cascades ≋", d)

	placerCristauxZone(def, 8, 16)
end

--------------------------------------------------------------------------------
-- 11. LES RUINES D'ELYNDOR (colonnes brisées, arche, autel à améthyste)
--------------------------------------------------------------------------------

do
	local def = ILES.Ruines
	local d = def.dossier
	local c = def.centre
	local versCristal = ILES.Cristal.centre

	-- dalles anciennes disséminées sur la place
	semer(c, 2, 11, quantite(12), function(pos)
		creerPart({
			Size = Vector3.new(rng:NextNumber(2.6, 3.8), 0.4, rng:NextNumber(2.6, 3.8)),
			CFrame = CFrame.new(Vector3.new(pos.X, c.Y + 0.18, pos.Z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Material = Enum.Material.Sandstone, Color = PALETTE.PierreClaire,
			Parent = d, Name = "Dalle",
		})
	end)

	-- le cercle de colonnes (certaines effondrées par les siècles)
	local cassees = { [2] = true, [5] = true, [7] = true }
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		creerColonne(c + Vector3.new(math.cos(angle) * 15, 0, math.sin(angle) * 15), 9, cassees[i] == true, d)
	end

	-- la grande arche tournée vers le pont
	local dirArche = Vector3.new(versCristal.X - c.X, 0, versCristal.Z - c.Z).Unit
	local perpArche = tourner(dirArche, math.pi / 2)
	local posArche = c + dirArche * 20
	creerColonne(posArche + perpArche * 4, 10, false, d)
	creerColonne(posArche - perpArche * 4, 10, false, d)
	creerPart({
		Size = Vector3.new(11, 2, 2.6),
		CFrame = CFrame.lookAt(posArche + Vector3.new(0, 12, 0), posArche + Vector3.new(0, 12, 0) + dirArche),
		Material = Enum.Material.Sandstone, Color = PALETTE.Pierre,
		Parent = d, Name = "Arche",
	})

	-- l'autel central et son améthyste (5 points)
	creerPart({ Size = Vector3.new(5, 1.2, 5), Position = c + Vector3.new(0, 0.6, 0),
		Material = Enum.Material.Sandstone, Color = PALETTE.Pierre, Parent = d, Name = "Autel" })
	creerPart({ Size = Vector3.new(3.6, 1.2, 3.6), Position = c + Vector3.new(0, 1.8, 0),
		Material = Enum.Material.Sandstone, Color = PALETTE.PierreClaire, Parent = d, Name = "Autel" })
	creerCristalCollectible(c + Vector3.new(0, 4.4, 0), 5)

	creerPanneau(pointBord(def, versCristal) + Vector3.new(3, 0, 4), "🏛 Ruines d'Elyndor 🏛", d)

	creerLanterne(c + Vector3.new(9, 0, -9), d)
	creerLanterne(c + Vector3.new(-10, 0, 8), d)
	creerArbre(c + Vector3.new(-16, 0, -14), 1.1, "classique", d)
	creerArbre(c + Vector3.new(18, 0, 12), 0.9, "classique", d)
	semer(c, 8, def.rayon - 8, quantite(7), function(pos) creerFleur(pos, d) end)

	placerCristauxZone(def, 7, 12)
end

--------------------------------------------------------------------------------
-- 12. LE SANCTUAIRE CÉLESTE (secret n°2 : au-dessus des nuages)
--------------------------------------------------------------------------------

do
	local def = ILES.Sanctuaire
	local d = def.dossier
	local c = def.centre

	-- l'Arbre d'Aurora, feuillage d'or
	creerArbre(c + Vector3.new(0, 0, -4), 1.5, "or", d)

	-- quatre piliers coiffés d'or autour du reliquaire
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + math.pi / 4
		local pos = c + Vector3.new(math.cos(angle) * 9.5, 0, math.sin(angle) * 9.5)
		cylindreVertical(pos + Vector3.new(0, 2.2, 0), 4.4, 1.6, {
			Material = Enum.Material.Sandstone, Color = PALETTE.PierreClaire,
			Parent = d, Name = "Pilier",
		})
		local coiffe = creerPart({
			Size = Vector3.new(1.3, 1.3, 1.3),
			CFrame = CFrame.new(pos + Vector3.new(0, 5.1, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Material = Enum.Material.Neon, Color = PALETTE.Or,
			CanCollide = false, Parent = d, Name = "Pilier",
		})
		creerLumiere(coiffe, PALETTE.Or, 10, 0.8)
	end

	-- le Cristal d'Or (20 points) sur son piédestal
	cylindreVertical(c + Vector3.new(0, 0.5, 3), 1, 5, {
		Material = Enum.Material.Slate, Color = PALETTE.Pierre, Parent = d, Name = "Piedestal",
	})
	cylindreVertical(c + Vector3.new(0, 1.3, 3), 0.6, 3.4, {
		Material = Enum.Material.Slate, Color = PALETTE.PierreClaire, Parent = d, Name = "Piedestal",
	})
	creerCristalCollectible(c + Vector3.new(0, 4.6, 3), 20)
	creerCristalCollectible(c + Vector3.new(-7, 2.6, -7), 1)
	creerCristalCollectible(c + Vector3.new(8, 2.6, 5), 1)

	-- des bancs de nuages qui enveloppent l'île
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + 0.5
		local centreNuage = c + Vector3.new(math.cos(angle) * 24, -2.5, math.sin(angle) * 24)
		for _ = 1, 3 do
			local taille = rng:NextNumber(6, 11)
			creerPart({
				Shape = Enum.PartType.Ball, Size = Vector3.new(taille, taille, taille),
				Position = centreNuage + Vector3.new(jitter(5), jitter(1.5), jitter(5)),
				Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(255, 244, 234),
				Transparency = 0.35, CanCollide = false, CastShadow = false,
				Parent = d, Name = "Nuage",
			})
		end
	end

	creerPanneau(c + Vector3.new(6, 0, -8), "★ Sanctuaire Celeste ★", d)
	semer(c, 5, def.rayon - 4, quantite(8), function(pos) creerFleur(pos, d) end)
end

--------------------------------------------------------------------------------
-- 13. PONTS DE BOIS, CHEMINS DE PIERRES VOLANTES ET PADS DE SAUT
--------------------------------------------------------------------------------

-- Pont suspendu : planches qui s'affaissent au milieu, poteaux et cordes.
local function creerPont(a, b)
	local dossier = Instance.new("Folder")
	dossier.Name = "Pont"
	dossier.Parent = dossierPonts

	local longueur = (b - a).Magnitude
	local nbPlanches = math.max(8, math.floor(longueur / 3.2))
	local affaissement = math.clamp(longueur * 0.07, 2.5, 7)

	local function pointPont(t)
		local p = a:Lerp(b, t)
		return p - Vector3.new(0, affaissement * math.sin(math.pi * t), 0)
	end

	local dernierPoteau = nil
	for i = 0, nbPlanches do
		local t = i / nbPlanches
		local pos = pointPont(t)
		local devant = pointPont(math.min(t + 1 / nbPlanches, 1))
		if (devant - pos).Magnitude < 0.05 then
			devant = pos + (pos - pointPont(t - 1 / nbPlanches))
		end
		local cf = CFrame.lookAt(pos, devant)
		creerPart({
			Size = Vector3.new(5.6, 0.5, 2.6), CFrame = cf,
			Material = Enum.Material.WoodPlanks,
			Color = (i % 2 == 0) and PALETTE.BoisClair or PALETTE.Bois,
			Parent = dossier, Name = "Planche",
		})

		if i % 3 == 0 then -- poteaux et cordes des garde-fous
			local poteaux = {}
			for _, cote in ipairs({ -2.5, 2.5 }) do
				creerPart({
					Size = Vector3.new(0.35, 2.3, 0.35), CFrame = cf * CFrame.new(cote, 1.4, 0),
					Material = Enum.Material.Wood, Color = PALETTE.Bois,
					CanCollide = false, Parent = dossier, Name = "Poteau",
				})
				table.insert(poteaux, (cf * CFrame.new(cote, 2.4, 0)).Position)
			end
			if dernierPoteau then
				for j = 1, 2 do
					local depart, arrivee = dernierPoteau[j], poteaux[j]
					local milieu = (depart + arrivee) / 2 - Vector3.new(0, 0.3, 0)
					creerPart({
						Shape = Enum.PartType.Cylinder,
						Size = Vector3.new((arrivee - depart).Magnitude + 0.4, 0.22, 0.22),
						CFrame = CFrame.lookAt(milieu, arrivee) * CFrame.Angles(0, math.rad(90), 0),
						Material = Enum.Material.Fabric, Color = PALETTE.Bois,
						CanCollide = false, CastShadow = false, Parent = dossier, Name = "Corde",
					})
				end
			end
			dernierPoteau = poteaux
		end
	end

	return pointPont(0.5) -- le milieu du pont (on y pose un cristal)
end

-- Les 4 ponts en étoile autour du Grand Cristal
local milieuxPonts = {}
for _, cle in ipairs({ "Spawn", "Foret", "Cascades", "Ruines" }) do
	local def = ILES[cle]
	local depart = pointBord(def, ILES.Cristal.centre)
	local arrivee = pointBord(ILES.Cristal, def.centre)
	table.insert(milieuxPonts, creerPont(depart, arrivee))
end
for _, milieu in ipairs(milieuxPonts) do
	creerCristalCollectible(milieu + Vector3.new(0, 3, 0), 1)
end

-- Chemins de pierres volantes entre les îles extérieures (routes alternatives)
--
-- Le nombre de pierres dépend de la distance entre les îles : avec un saut
-- Roblox par défaut (≈ 8 studs de portée à plat, moins en montée), un écart
-- fixe de 7 pierres laissait des vides de 9 à 15 studs, donc des chemins
-- impossibles (détecté par pipeline/validate). On vise ~7,5 studs entre deux
-- centres, soit ~2,5 à 4 studs de vide : facile, y compris sur mobile.
local ESPACEMENT_PIERRES = 7.5
local DECALAGE_LATERAL_MAX = 1.2

local function creerCheminPierres(defA, defB)
	local dossier = Instance.new("Folder")
	dossier.Name = "CheminPierres"
	dossier.Parent = dossierPonts

	local a = pointBord(defA, defB.centre)
	local b = pointBord(defB, defA.centre)
	local distance = ((b - a) * Vector3.new(1, 0, 1)).Magnitude
	local nb = math.max(3, math.ceil(distance / ESPACEMENT_PIERRES) - 1)
	-- Décalage latéral (perpendiculaire au chemin) : garde un tracé vivant sans
	-- jamais allonger les sauts de plus de quelques dixièmes de stud.
	local lateral = tourner((b - a) * Vector3.new(1, 0, 1), math.pi / 2).Unit
	local sommets = {}
	for i = 1, nb do
		local t = i / (nb + 1)
		local pos = a:Lerp(b, t)
			+ lateral * jitter(DECALAGE_LATERAL_MAX)
			+ Vector3.new(0, math.sin(math.pi * t) * 7, 0)
		local diametre = rng:NextNumber(5, 7)
		cylindreVertical(pos, 1.7, diametre, {
			Material = Enum.Material.Slate, Color = PALETTE.Roche,
			Parent = dossier, Name = "PierreVolante",
		})
		cylindreVertical(pos + Vector3.new(0, 1, 0), 0.4, diametre - 0.9, {
			Material = Enum.Material.Grass, Color = PALETTE.HerbeClaire,
			Parent = dossier, Name = "PierreVolante",
		})
		table.insert(sommets, pos + Vector3.new(0, 1.4, 0))
	end
	return sommets
end

for _, route in ipairs({ { "Foret", "Cascades" }, { "Cascades", "Ruines" } }) do
	local sommets = creerCheminPierres(ILES[route[1]], ILES[route[2]])
	creerCristalCollectible(sommets[math.max(1, math.floor(#sommets / 3))] + Vector3.new(0, 2.2, 0), 1)
	creerCristalCollectible(sommets[math.max(1, math.floor(#sommets * 2 / 3))] + Vector3.new(0, 2.2, 0), 1)
end

-- Pads de saut : l'escalier céleste des Ruines jusqu'au Sanctuaire
local function vitesseSaut(depuis, vers)
	local delta = vers - depuis
	local g = workspace.Gravity
	local vitesseVerticale = math.sqrt(2 * g * (math.max(delta.Y, 0) + 14))
	local duree = (vitesseVerticale / g) * 1.15
	local horizontale = Vector3.new(delta.X, 0, delta.Z) / math.max(duree, 0.1)
	return horizontale + Vector3.new(0, vitesseVerticale, 0)
end

local function creerPadSaut(position, cible)
	local pad = creerPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.7, 6, 6),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon, Color = PALETTE.Turquoise,
		Parent = dossierPads, Name = "PadSaut",
	})
	pad:SetAttribute("Vitesse", vitesseSaut(position, cible))
	creerPart({ -- l'anneau qui souligne le pad
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 7.6, 7.6),
		CFrame = CFrame.new(position - Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon, Color = PALETTE.CristalClair, Transparency = 0.45,
		CanCollide = false, Parent = dossierPads, Name = "AnneauPad",
	})
	creerLumiere(pad, PALETTE.Turquoise, 10, 0.8)
	creerEmetteur(pad, {
		Color = ColorSequence.new(PALETTE.Turquoise, Color3.new(1, 1, 1)),
		Size = NumberSequence.new(0.7, 0.2),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 0,
		Speed = NumberRange.new(5, 10),
		SpreadAngle = Vector2.new(25, 25),
		LightEmission = 1,
		Enabled = false,
	})
	return pad
end

do
	local departEscalier = pointBord(ILES.Ruines, ILES.Sanctuaire.centre) + Vector3.new(0, 0.3, 0)
	local arriveeEscalier = pointBord(ILES.Sanctuaire, ILES.Ruines.centre)
	local nbPads = 5
	local perpEscalier = tourner((arriveeEscalier - departEscalier) * Vector3.new(1, 0, 1), math.pi / 2).Unit

	local positions = { departEscalier }
	for i = 1, nbPads - 1 do
		local t = i / nbPads
		local pos = departEscalier:Lerp(arriveeEscalier, t) + perpEscalier * (math.sin(t * math.pi * 2) * 9)
		table.insert(positions, pos)
	end
	table.insert(positions, arriveeEscalier + Vector3.new(0, 1, 0))

	for i = 1, nbPads do
		creerPadSaut(positions[i], positions[i + 1])
		if i > 1 then -- un rocher porte chaque pad flottant
			creerPart({
				Shape = Enum.PartType.Ball, Size = Vector3.new(4.5, 4.5, 4.5),
				Position = positions[i] - Vector3.new(0, 2.6, 0),
				Material = Enum.Material.Slate, Color = PALETTE.Roche,
				Parent = dossierPads, Name = "SoclePad",
			})
		end
	end

	creerPanneau(departEscalier + Vector3.new(4, 0, -3), "☄ Vers le ciel... ☄", ILES.Ruines.dossier)
end

-- Poussière dorée qui flotte dans l'air (magie ambiante de l'archipel)
for _, def in ipairs({ ILES.Cristal, ILES.Spawn }) do
	local zone = blocInvisible(def.centre + Vector3.new(0, 9, 0), Vector3.new(def.rayon, 12, def.rayon), dossierEffets)
	creerEmetteur(zone, {
		Color = ColorSequence.new(Color3.fromRGB(255, 226, 170)),
		Size = NumberSequence.new(0.2, 0.08),
		Transparency = NumberSequence.new(0.35, 1),
		Lifetime = NumberRange.new(5, 8),
		Rate = 4,
		Speed = NumberRange.new(0.2, 0.6),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.7,
	})
end

map.Parent = workspace

--------------------------------------------------------------------------------
-- 14. LE SCRIPT DE JEU (installé dans ServerScriptService, tourne en Play)
--------------------------------------------------------------------------------

local sourceJeu = [==[
-- Script de jeu des Îles Célestes d'Aurora (généré par le script de construction)
-- Gère : leaderboard, collecte/réapparition des cristaux, pads de saut, animations.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local map = workspace:WaitForChild("MapIlesCelestes")
local dossierCristaux = map:WaitForChild("Collectibles")
local dossierRotors = map:WaitForChild("Rotors")
local dossierOrbites = map:WaitForChild("Orbites")
local dossierPads = map:WaitForChild("JumpPads")

local TEMPS_REAPPARITION = map:GetAttribute("TempsReapparition") or 25
local MULTIPLICATEUR_PADS = map:GetAttribute("MultiplicateurPads") or 1

-- ── Leaderboard ──────────────────────────────────────────────────────────────
local function preparerJoueur(joueur)
	if joueur:FindFirstChild("leaderstats") then return end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cristaux = Instance.new("IntValue")
	cristaux.Name = "🔮 Cristaux"
	cristaux.Value = 0
	cristaux.Parent = stats
	stats.Parent = joueur
end
Players.PlayerAdded:Connect(preparerJoueur)
for _, joueur in ipairs(Players:GetPlayers()) do
	preparerJoueur(joueur)
end

-- ── Collecte des cristaux ────────────────────────────────────────────────────
local function brancherCristal(cristal)
	cristal.Touched:Connect(function(hit)
		if cristal:GetAttribute("Pris") then return end
		local joueur = Players:GetPlayerFromCharacter(hit.Parent)
		if not joueur then return end
		cristal:SetAttribute("Pris", true)

		local stats = joueur:FindFirstChild("leaderstats")
		local compteur = stats and stats:FindFirstChild("🔮 Cristaux")
		if compteur then
			compteur.Value += cristal:GetAttribute("Valeur") or 1
		end

		local son = cristal:FindFirstChildOfClass("Sound")
		if son then son:Play() end
		local eclat = cristal:FindFirstChildOfClass("ParticleEmitter")
		if eclat then eclat:Emit(30) end
		local lumiere = cristal:FindFirstChildOfClass("PointLight")
		if lumiere then lumiere.Enabled = false end
		cristal.Transparency = 1
		cristal.CanTouch = false

		task.delay(TEMPS_REAPPARITION, function()
			if not cristal.Parent then return end
			cristal.Transparency = 0
			cristal.CanTouch = true
			if lumiere then lumiere.Enabled = true end
			cristal:SetAttribute("Pris", false)
		end)
	end)
end
for _, cristal in ipairs(dossierCristaux:GetChildren()) do
	if cristal:IsA("BasePart") then
		brancherCristal(cristal)
	end
end

-- ── Pads de saut ─────────────────────────────────────────────────────────────
for _, pad in ipairs(dossierPads:GetChildren()) do
	if pad:IsA("BasePart") and pad:GetAttribute("Vitesse") then
		local recharge = {}
		pad.Touched:Connect(function(hit)
			local perso = hit.Parent
			if not perso or recharge[perso] then return end
			local humanoide = perso:FindFirstChildOfClass("Humanoid")
			local racine = perso:FindFirstChild("HumanoidRootPart")
			if not humanoide or not racine then return end
			recharge[perso] = true
			racine.AssemblyLinearVelocity = pad:GetAttribute("Vitesse") * MULTIPLICATEUR_PADS
			local effet = pad:FindFirstChildOfClass("ParticleEmitter")
			if effet then effet:Emit(14) end
			task.delay(0.5, function()
				recharge[perso] = nil
			end)
		end)
	end
end

-- ── Animations : cristaux flottants, anneaux, éclats en orbite ───────────────
local listeCristaux, basesCristaux = {}, {}
for _, cristal in ipairs(dossierCristaux:GetChildren()) do
	if cristal:IsA("BasePart") then
		table.insert(listeCristaux, cristal)
		basesCristaux[cristal] = cristal.CFrame
	end
end

local listeRotors, basesRotors = {}, {}
for _, rotor in ipairs(dossierRotors:GetChildren()) do
	if rotor:IsA("BasePart") then
		table.insert(listeRotors, rotor)
		basesRotors[rotor] = rotor.CFrame
	end
end

local listeOrbites = {}
for _, eclat in ipairs(dossierOrbites:GetChildren()) do
	if eclat:IsA("BasePart") then
		table.insert(listeOrbites, eclat)
	end
end

local temps = 0
RunService.Heartbeat:Connect(function(dt)
	temps += dt

	for i, cristal in ipairs(listeCristaux) do
		if not cristal:GetAttribute("Pris") then
			local base = basesCristaux[cristal]
			cristal.CFrame = base
				* CFrame.new(0, math.sin(temps * 2 + i) * 0.5, 0)
				* CFrame.Angles(0, temps * 1.6 + i, 0)
		end
	end

	for _, rotor in ipairs(listeRotors) do
		local base = basesRotors[rotor]
		local vitesse = rotor:GetAttribute("VitesseRotation") or 0.5
		rotor.CFrame = CFrame.new(base.Position)
			* CFrame.Angles(0, temps * vitesse, 0)
			* base.Rotation
	end

	for _, eclat in ipairs(listeOrbites) do
		local centre = eclat:GetAttribute("CentreOrbite")
		if centre then
			local rayon = eclat:GetAttribute("RayonOrbite") or 12
			local vitesse = eclat:GetAttribute("VitesseOrbite") or 0.5
			local phase = eclat:GetAttribute("Phase") or 0
			local angle = temps * vitesse + phase
			eclat.CFrame = CFrame.new(centre + Vector3.new(
				math.cos(angle) * rayon,
				math.sin(temps * 0.8 + phase) * 3,
				math.sin(angle) * rayon
			)) * CFrame.Angles(temps * 0.6 + phase, angle, 0)
		end
	end
end)
]==]

local scriptJeu = Instance.new("Script")
scriptJeu.Name = "IlesCelestes_Script"
scriptJeu.Source = sourceJeu
scriptJeu.Parent = ServerScriptService

--------------------------------------------------------------------------------
-- 15. RÉCAPITULATIF
--------------------------------------------------------------------------------

print("=====================================================")
print("✦ LES ÎLES CÉLESTES D'AURORA — map construite ! ✦")
print("• Parts créées : " .. #map:GetDescendants())
print("• Cristaux à collecter : " .. #dossierCollectibles:GetChildren())
print("• Script de jeu installé : ServerScriptService.IlesCelestes_Script")
print("• Lance Play : tu apparais sur le Belvédère, face au Grand Cristal.")
print("• 2 secrets à trouver : derrière la grande cascade... et au-dessus des nuages.")
print("=====================================================")
