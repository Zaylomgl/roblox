--========================================================================================
--  ✦ L'ÎLE D'AURACIEL ✦ — v1.0
--
--  THÈME CHOISI : île flottante fantasy au crépuscule doré ("golden hour"),
--  cascades qui tombent dans le vide, arbre-cristal géant, village de lanternes,
--  ruines célestes et deux zones secrètes à découvrir.
--
--  ▸ COMMENT L'UTILISER
--    1. Ouvre Roblox Studio dans une place (Baseplate ou vide, peu importe).
--    2. Affiche la barre de commande : View → Command Bar.
--    3. Colle TOUT ce script dans la barre de commande, puis appuie sur Entrée.
--    4. La construction prend quelques secondes (le terrain est la partie la plus longue).
--    5. Appuie sur ▶ Play : leaderboard, collecte d'Éclats, animations et secrets
--       fonctionnent immédiatement (un Script "IF_Runtime" est installé dans
--       ServerScriptService automatiquement).
--
--  ▸ CE QUE LE SCRIPT CONSTRUIT
--    · Terrain sculpté : île flottante en cône rocheux strié, prairies vallonnées,
--      lagon, rivière, cascade dans le vide, grotte cachée, îlots satellites.
--    · Lighting complet "golden hour" : Atmosphere, Bloom, ColorCorrection,
--      SunRays, DepthOfField, nuages volumétriques.
--    · Landmark central : YGGDRALUMA, l'arbre-cristal géant, visible de partout.
--    · 5 zones : Belvédère de l'Aube (spawn), Hameau des Lucioles (village),
--      Bosquet d'Auréline, Lagon du Voile, Ruines de l'Ordre Céleste.
--    · 2 zones secrètes : la Grotte de Lune (derrière la cascade) et le
--      Jardin d'Éther (îlot volant accessible par des pierres de saut cachées).
--    · ~50 Éclats d'Auréline à collecter (rotation, son, particules, respawn),
--      leaderstats, éclats rares dorés ×5 et un Éclat Prismatique ×25.
--    · Décor procédural : auraciers (arbres), rochers, fleurs, champignons lumineux,
--      lucioles, brume au sol, pétales dans le vent, aurores lointaines.
--
--  ▸ RÉGLAGES : tout se pilote depuis la table CONFIG ci-dessous.
--  ▸ RE-EXÉCUTABLE : relancer le script détruit l'ancienne île et la reconstruit
--    (le dossier workspace.Map, les effets "IF_" et la région de terrain sont nettoyés).
--  ▸ AUCUN asset externe : uniquement des textures/sons intégrés à Roblox (rbxasset).
--========================================================================================

--------------------------------------------------------------------------------
-- SECTION 0 · CONFIG — le tableau de bord de l'île
--------------------------------------------------------------------------------
local CONFIG = {
	-- Graine aléatoire : change-la pour obtenir une variation du relief et du décor.
	SEED = 20260704,

	ILE = {
		RAYON      = 230,  -- rayon de l'île en studs (⚠ le temps de génération grandit avec le carré du rayon)
		ALTITUDE   = 140,  -- hauteur de la surface au-dessus du vide
		PROFONDEUR = 165,  -- profondeur du cône rocheux sous l'île
		RELIEF     = 16,   -- amplitude des collines
	},

	-- "mobile" = décor allégé · "normale" = équilibré · "ultra" = décor dense
	QUALITE = "normale",

	DENSITE = { -- quantités de base (multipliées par le préréglage QUALITE)
		ARBRES    = 42,
		ROCHERS   = 48,
		FLORE     = 64,  -- touffes de fleurs / champignons
		LANTERNES = 12,  -- le long des chemins (en plus de celles du village)
		LUCIOLES  = 9,   -- émetteurs de lucioles
		BRUME     = 8,   -- nappes de brume au sol
	},

	COLLECTIBLES = {
		NOMBRE        = 50,   -- éclats "normaux" sur l'île
		RESPAWN       = 25,   -- secondes avant réapparition
		VALEUR        = 1,    -- valeur d'un éclat normal
		VALEUR_SECRET = 5,    -- valeur des éclats dorés des zones secrètes
		VALEUR_PRISME = 25,   -- l'Éclat Prismatique unique du Jardin d'Éther
		SECRETS       = true, -- construire les zones secrètes et leurs éclats
	},

	HEURE = 17.4, -- heure du jour (17.4 = golden hour ; essaie 5.8 pour l'aube, 22 pour la nuit)

	PALETTE = { -- 4 couleurs dominantes, tout le reste en découle
		OR_AMBRE    = Color3.fromRGB(255, 178,  96), -- soleil, lanternes, éclats rares
		ROSE_CORAIL = Color3.fromRGB(238, 122, 108), -- toits, auraciers en fleurs, ciel
		TURQUOISE   = Color3.fromRGB( 88, 216, 202), -- cristaux, eau, éclats
		VIOLET_NUIT = Color3.fromRGB(122, 102, 170), -- ombres, roche, brume, ruines
	},

	NETTOYER_REGION     = true, -- efface le terrain dans la zone de l'île avant de construire
	SUPPRIMER_BASEPLATE = true, -- supprime Baseplate/SpawnLocation du template pour révéler le vide
}

--------------------------------------------------------------------------------
-- SECTION 1 · SERVICES, NETTOYAGE & ÉTAT PARTAGÉ
--------------------------------------------------------------------------------
local Lighting            = game:GetService("Lighting")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService   = game:GetService("CollectionService")

local debutChrono = os.clock()
local rng   = Random.new(CONFIG.SEED)
local P     = CONFIG.PALETTE
local R     = CONFIG.ILE.RAYON
local ALT   = CONFIG.ILE.ALTITUDE
local ECH   = R / 230 -- échelle : toutes les coordonnées de zones suivent le rayon choisi
local terrain = workspace.Terrain

local U = {} -- boîte à outils (fonctions utilitaires)
local M = {  -- état partagé de la construction
	nbParts    = 0,
	nbTerrains = 0,
	poi        = {}, -- points d'intérêt où poser des éclats (récompenses d'exploration)
	arbresPos  = {}, -- positions des arbres (pour l'espacement)
}

-- multiplicateur de densité selon la qualité choisie
local QUALITES = { mobile = 0.55, normale = 1.0, ultra = 1.5 }
local DENS = QUALITES[CONFIG.QUALITE] or 1.0

-- ▸ nettoyage d'une éventuelle construction précédente (script re-exécutable)
do
	local ancienneMap = workspace:FindFirstChild("Map")
	if ancienneMap then ancienneMap:Destroy() end

	local ancienRuntime = ServerScriptService:FindFirstChild("IF_Runtime")
	if ancienRuntime then ancienRuntime:Destroy() end

	-- on retire les effets post-process / atmosphère existants pour repartir proprement
	for _, effet in ipairs(Lighting:GetChildren()) do
		if effet:IsA("Atmosphere") or effet:IsA("BloomEffect") or effet:IsA("ColorCorrectionEffect")
			or effet:IsA("SunRaysEffect") or effet:IsA("DepthOfFieldEffect") or effet.Name:sub(1, 3) == "IF_" then
			effet:Destroy()
		end
	end
	for _, enfant in ipairs(terrain:GetChildren()) do
		if enfant:IsA("Clouds") then enfant:Destroy() end
	end

	if CONFIG.SUPPRIMER_BASEPLATE then
		local baseplate = workspace:FindFirstChild("Baseplate")
		if baseplate then baseplate:Destroy() end
		local spawnDefaut = workspace:FindFirstChild("SpawnLocation")
		if spawnDefaut then spawnDefaut:Destroy() end
	end

	if CONFIG.NETTOYER_REGION then
		local etendue = R + 320
		local region = Region3.new(
			Vector3.new(-etendue, ALT - CONFIG.ILE.PROFONDEUR - 120, -etendue - 120),
			Vector3.new(etendue, ALT + 220, etendue)
		):ExpandToGrid(4)
		terrain:FillRegion(region, 4, Enum.Material.Air)
	end

	pcall(function() workspace.FallenPartsDestroyHeight = ALT - 380 end)
end

-- ▸ hiérarchie des dossiers : tout est rangé sous workspace.Map
M.racine       = Instance.new("Folder"); M.racine.Name = "Map";          M.racine.Parent = workspace
M.dZones       = Instance.new("Folder"); M.dZones.Name = "Zones";        M.dZones.Parent = M.racine
M.dDecor       = Instance.new("Folder"); M.dDecor.Name = "Decor";        M.dDecor.Parent = M.racine
M.dChemins     = Instance.new("Folder"); M.dChemins.Name = "Chemins";    M.dChemins.Parent = M.racine
M.dCollecte    = Instance.new("Folder"); M.dCollecte.Name = "Collectibles"; M.dCollecte.Parent = M.racine
M.dSecrets     = Instance.new("Folder"); M.dSecrets.Name = "Secrets";    M.dSecrets.Parent = M.racine
M.dEffets      = Instance.new("Folder"); M.dEffets.Name = "Effets";      M.dEffets.Parent = M.dDecor
M.dArbres      = Instance.new("Folder"); M.dArbres.Name = "Arbres";      M.dArbres.Parent = M.dDecor
M.dRochers     = Instance.new("Folder"); M.dRochers.Name = "Rochers";    M.dRochers.Parent = M.dDecor
M.dFlore       = Instance.new("Folder"); M.dFlore.Name = "Flore";        M.dFlore.Parent = M.dDecor
M.dLanternes   = Instance.new("Folder"); M.dLanternes.Name = "Lanternes"; M.dLanternes.Parent = M.dDecor
M.dCiel        = Instance.new("Folder"); M.dCiel.Name = "Ciel";          M.dCiel.Parent = M.dDecor

-- ▸ ancres des zones (coordonnées XZ, mises à l'échelle du rayon choisi)
local A = {
	SPAWN    = Vector2.new(   0,  178) * ECH,
	VILLAGE  = Vector2.new( 118,   40) * ECH,
	BOSQUET  = Vector2.new(   0,  -45) * ECH,
	LAGON    = Vector2.new(-105,   25) * ECH,
	RUINES   = Vector2.new(  95, -118) * ECH,
	ARBRE    = Vector2.new(   0,  -38) * ECH, -- pied de l'arbre-cristal
	JARDIN   = Vector2.new( 150, -190) * ECH, -- îlot secret
}

print("🏝️  [Île d'Auraciel] Construction lancée — graine " .. CONFIG.SEED .. ", qualité « " .. CONFIG.QUALITE .. " »")

--------------------------------------------------------------------------------
-- SECTION 2 · BOÎTE À OUTILS
--------------------------------------------------------------------------------

-- crée une Part ancrée avec des valeurs propres par défaut
function U.part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.CanCollide ~= false
	p.CastShadow = props.CastShadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then p.Shape = props.Shape end
	p.Size = props.Size or Vector3.new(1, 1, 1)
	p.CFrame = props.CFrame or CFrame.new()
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Transparency = props.Transparency or 0
	if props.Reflectance then p.Reflectance = props.Reflectance end
	p.Name = props.Name or "Part"
	p.Parent = props.Parent
	M.nbParts = M.nbParts + 1
	return p
end

function U.model(nom, parent)
	local m = Instance.new("Model")
	m.Name = nom
	m.Parent = parent
	return m
end

-- cylindre vertical posé sur sa base (les cylindres Roblox ont leur axe sur X)
function U.cylindreVertical(base, hauteur, rayon, o)
	o = o or {}
	local inclinaison = CFrame.Angles(math.rad(o.TiltX or 0), math.rad(o.Yaw or 0), math.rad(o.TiltZ or 0))
	local cf = CFrame.new(base) * inclinaison * CFrame.new(0, hauteur / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	return U.part{
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(hauteur, rayon * 2, rayon * 2),
		CFrame = cf,
		Material = o.Material, Color = o.Color, Parent = o.Parent, Name = o.Name,
		CanCollide = o.CanCollide, CastShadow = o.CastShadow, Transparency = o.Transparency,
	}
end

-- cylindre tendu entre deux points (troncs, branches, racines, cordes, roseaux…)
function U.tube(a, b, rayon, o)
	o = o or {}
	local direction = b - a
	local haut = Vector3.new(0, 1, 0)
	if math.abs(direction.Unit:Dot(haut)) > 0.99 then haut = Vector3.new(1, 0, 0) end
	local cf = CFrame.lookAt((a + b) / 2, b, haut) * CFrame.Angles(0, math.rad(90), 0)
	return U.part{
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(direction.Magnitude + (o.Rallonge or 0), rayon * 2, rayon * 2),
		CFrame = cf,
		Material = o.Material, Color = o.Color, Parent = o.Parent, Name = o.Name,
		CanCollide = o.CanCollide, CastShadow = o.CastShadow, Transparency = o.Transparency,
	}
end

function U.boule(centre, rayon, o)
	o = o or {}
	return U.part{
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(rayon * 2, rayon * 2, rayon * 2),
		CFrame = CFrame.new(centre),
		Material = o.Material, Color = o.Color, Parent = o.Parent, Name = o.Name,
		CanCollide = o.CanCollide, CastShadow = o.CastShadow, Transparency = o.Transparency,
	}
end

function U.lumiere(parent, couleur, portee, brillance, ombres)
	local l = Instance.new("PointLight")
	l.Color = couleur
	l.Range = portee or 16
	l.Brightness = brillance or 1
	l.Shadows = ombres == true
	l.Parent = parent
	return l
end

-- émetteur de particules générique (textures rbxasset uniquement → zéro asset externe)
function U.particules(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = props.Name or "Particules"
	e.Texture = props.Texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = props.Color or ColorSequence.new(Color3.new(1, 1, 1))
	e.Size = props.Size or NumberSequence.new(0.3)
	e.Transparency = props.Transparency or NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.8, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = props.Lifetime or NumberRange.new(2, 4)
	e.Rate = (props.Rate or 5) * DENS
	e.Speed = props.Speed or NumberRange.new(0.4, 1)
	e.SpreadAngle = props.Spread or Vector2.new(180, 180)
	e.Acceleration = props.Acceleration or Vector3.new(0, 0, 0)
	e.LightEmission = props.LightEmission or 0.6
	e.LightInfluence = props.LightInfluence or 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = props.RotSpeed or NumberRange.new(-25, 25)
	e.EmissionDirection = props.Direction or Enum.NormalId.Top
	e.ZOffset = props.ZOffset or 0
	e.Enabled = props.Enabled ~= false
	e.Parent = parent
	return e
end

-- part invisible servant de support à des émetteurs (brume, lucioles, cascade…)
function U.ancre(cf, taille, parent, nom)
	return U.part{
		Size = taille or Vector3.new(2, 2, 2), CFrame = cf,
		Transparency = 1, CanCollide = false, CastShadow = false,
		Parent = parent, Name = nom or "AncreEffet",
	}
end

-- raycast vers le bas pour trouver le sol du terrain (place le décor avec précision)
do
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	params.IgnoreWater = true
	function U.sol(x, z)
		local resultat = workspace:Raycast(Vector3.new(x, ALT + 180, z), Vector3.new(0, -430, 0), params)
		if resultat then return resultat.Position, resultat.Normal end
		return nil
	end
end

-- variation aléatoire douce autour d'une couleur (évite l'effet "copier-coller")
function U.nuance(couleur, amplitude)
	amplitude = amplitude or 0.06
	local function v(c)
		return math.clamp(c + rng:NextNumber(-amplitude, amplitude), 0, 1)
	end
	return Color3.new(v(couleur.R), v(couleur.G), v(couleur.B))
end

-- grappe de cristaux : la signature visuelle de l'île
-- (une hauteur négative crée une grappe inversée, suspendue à un plafond)
function U.cristal(pos, hauteur, couleur, o)
	o = o or {}
	local m = U.model(o.Nom or "Cristal", o.Parent or M.dFlore)
	local nBranches = o.Branches or rng:NextInteger(3, 5)
	local inverse = hauteur < 0
	local ampleur = math.abs(hauteur)
	for i = 1, nBranches do
		local h = ampleur * rng:NextNumber(0.45, 1) * (inverse and -1 or 1)
		local hAbs = math.abs(h)
		local ecart = ampleur * 0.16
		local base = pos + Vector3.new(rng:NextNumber(-ecart, ecart), inverse and 0.6 or -0.6, rng:NextNumber(-ecart, ecart))
		local orientation = CFrame.new(base)
			* CFrame.Angles(math.rad(rng:NextNumber(-26, 26)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-26, 26)))
			* CFrame.new(0, h / 2, 0)
			* CFrame.Angles(0, math.rad(45), 0)
		local teinte = U.nuance(couleur, 0.05)
		U.part{ -- gaine translucide
			Size = Vector3.new(hAbs * 0.26, hAbs, hAbs * 0.26), CFrame = orientation,
			Material = Enum.Material.Glass, Color = teinte, Transparency = 0.25,
			Reflectance = 0.08, Parent = m, Name = "Facette", CanCollide = i == 1,
		}
		U.part{ -- cœur lumineux
			Size = Vector3.new(hAbs * 0.12, hAbs * 0.66, hAbs * 0.12), CFrame = orientation,
			Material = Enum.Material.Neon, Color = teinte:Lerp(Color3.new(1, 1, 1), 0.35),
			Parent = m, Name = "Coeur", CanCollide = false, CastShadow = false,
		}
	end
	if o.Lumiere ~= false then
		local socle = U.ancre(CFrame.new(pos + Vector3.new(0, hauteur * 0.4, 0)), nil, m, "Halo")
		U.lumiere(socle, couleur, o.Portee or ampleur * 3.4, o.Brillance or 0.7)
		if o.Scintille then
			U.particules(socle, {
				Color = ColorSequence.new(couleur), Rate = 1.2,
				Size = NumberSequence.new(0.22), Lifetime = NumberRange.new(2, 4),
				Speed = NumberRange.new(0.3, 0.8),
			})
		end
	end
	return m
end

--------------------------------------------------------------------------------
-- SECTION 3 · LUMIÈRE & ATMOSPHÈRE — la "golden hour" permanente
--------------------------------------------------------------------------------
do
	Lighting.ClockTime = CONFIG.HEURE
	Lighting.GeographicLatitude = 15
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(92, 72, 96)            -- ombres teintées violet crépuscule
	Lighting.OutdoorAmbient = Color3.fromRGB(142, 108, 100)  -- rebond chaud
	Lighting.ColorShift_Top = Color3.fromRGB(255, 172, 112)  -- lumière directe ambrée
	Lighting.ColorShift_Bottom = Color3.fromRGB(118, 92, 132)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.22
	Lighting.ExposureCompensation = 0.15
	-- Astuce : pour un rendu encore plus beau, passe Lighting.Technology sur
	-- "Future" dans les propriétés de Lighting (non modifiable par script).

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "IF_Atmosphere"
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.6
	atmosphere.Color = Color3.fromRGB(228, 176, 158)  -- brume rosée
	atmosphere.Decay = Color3.fromRGB(148, 100, 142)  -- horizon violet
	atmosphere.Glare = 0.32
	atmosphere.Haze = 1.9
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "IF_Bloom"
	bloom.Intensity = 0.65
	bloom.Size = 36
	bloom.Threshold = 1.08
	bloom.Parent = Lighting

	local correction = Instance.new("ColorCorrectionEffect")
	correction.Name = "IF_ColorCorrection"
	correction.Brightness = 0.02
	correction.Contrast = 0.08
	correction.Saturation = 0.12
	correction.TintColor = Color3.fromRGB(255, 241, 228)
	correction.Parent = Lighting

	local rayons = Instance.new("SunRaysEffect")
	rayons.Name = "IF_SunRays"
	rayons.Intensity = 0.18
	rayons.Spread = 0.8
	rayons.Parent = Lighting

	local profondeur = Instance.new("DepthOfFieldEffect")
	profondeur.Name = "IF_DepthOfField"
	profondeur.FarIntensity = 0.15
	profondeur.FocusDistance = 55
	profondeur.InFocusRadius = 120
	profondeur.NearIntensity = 0.2
	profondeur.Parent = Lighting

	local nuages = Instance.new("Clouds")
	nuages.Name = "IF_Nuages"
	nuages.Cover = 0.52
	nuages.Density = 0.24
	nuages.Color = Color3.fromRGB(255, 214, 190) -- nuages embrasés par le couchant
	nuages.Parent = terrain

	-- couleurs des matériaux du terrain, accordées à la palette
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(110, 146, 78))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(130, 134, 68))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(124, 94, 72))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(116, 100, 118))
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(138, 118, 132))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(84, 70, 92))

	-- eau turquoise lumineuse
	terrain.WaterColor = Color3.fromRGB(52, 168, 172)
	terrain.WaterTransparency = 0.88
	terrain.WaterReflectance = 0.35
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 14
	terrain.Decoration = true -- herbe animée sur le matériau Grass

	print("🌇 [1/9] Lumière « golden hour » installée (Atmosphere, Bloom, SunRays, nuages)")
end

--------------------------------------------------------------------------------
-- SECTION 4 · TERRAIN — sculpture de l'île flottante
--------------------------------------------------------------------------------
local hauteurIle -- hauteurIle(x, z) → hauteur de la surface (nil hors de l'île)
do
	local NX, NZ = rng:NextNumber(0, 1000), rng:NextNumber(0, 1000)
	local RELIEF = CONFIG.ILE.RELIEF

	local function hauteurBrute(x, z)
		local d = math.sqrt(x * x + z * z) / R
		if d >= 1 then return nil end
		local falloff = 1 - d ^ 2.4 -- plateau central, bord qui plonge
		local collines = math.noise(x * 0.012 + NX, z * 0.012 + NZ) * RELIEF * 0.9
		local details  = math.noise(x * 0.05 + NX, z * 0.05 + NZ) * 3.2
		return ALT + falloff * (RELIEF + collines + details)
	end

	-- les zones jouables sont aplanies en douceur pour rester constructibles
	local zonesPlates = {}
	for _, def in ipairs({
		{ ancre = A.SPAWN,   rayon = 30, force = 0.85 },
		{ ancre = A.VILLAGE, rayon = 42, force = 0.80 },
		{ ancre = A.BOSQUET, rayon = 34, force = 0.55 },
		{ ancre = A.LAGON,   rayon = 46, force = 0.90 },
		{ ancre = A.RUINES,  rayon = 34, force = 0.80 },
	}) do
		table.insert(zonesPlates, {
			pos = def.ancre, rayon = def.rayon, force = def.force,
			h = hauteurBrute(def.ancre.X, def.ancre.Y) or ALT,
		})
	end

	hauteurIle = function(x, z)
		local h = hauteurBrute(x, z)
		if not h then return nil end
		for _, zp in ipairs(zonesPlates) do
			local d = (Vector2.new(x, z) - zp.pos).Magnitude
			if d < zp.rayon then
				local f = 1 - d / zp.rayon
				f = f * f * (3 - 2 * f) -- lissage (smoothstep)
				h = h + (zp.h - h) * f * zp.force
			end
		end
		return h
	end

	local function remplir(fonction, ...)
		terrain[fonction](terrain, ...)
		M.nbTerrains = M.nbTerrains + 1
	end

	-- ▸ 4a. la prairie : couche d'herbe + sous-couche de terre, cellule par cellule
	local pas = 10
	local materiaux = { Enum.Material.Grass, Enum.Material.LeafyGrass }
	for x = -R, R, pas do
		for z = -R, R, pas do
			local h = hauteurIle(x, z)
			if h then
				local mat = materiaux[math.noise(x * 0.03 + NZ, z * 0.03 + NX) > 0.14 and 2 or 1]
				remplir("FillBall", Vector3.new(x, h - 3, z), 7.5, mat)
				remplir("FillBall", Vector3.new(x, h - 10, z), 9, Enum.Material.Ground)
			end
		end
	end

	-- ▸ 4b. le cône rocheux sous l'île, en strates (Rock / Slate / Basalt)
	local strates = { Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Rock, Enum.Material.Basalt }
	local nCouches = 12
	for i = 0, nCouches do
		local t = i / nCouches
		local y = ALT - 4 - t * CONFIG.ILE.PROFONDEUR
		local rayonCouche = (R * 0.94) * (1 - t) ^ 1.35 + 6
		local mat = strates[(i % #strates) + 1]
		local nBoules = math.max(3, math.floor(rayonCouche / 9))
		for k = 1, nBoules do
			local angle = (k / nBoules) * math.pi * 2 + t * 2.1
			local excentre = rayonCouche - 8 + rng:NextNumber(-5, 5)
			remplir("FillBall",
				Vector3.new(math.cos(angle) * excentre, y + rng:NextNumber(-4, 4), math.sin(angle) * excentre),
				rng:NextNumber(11, 16), mat)
		end
		remplir("FillBall", Vector3.new(rng:NextNumber(-6, 6), y, rng:NextNumber(-6, 6)),
			math.min(rayonCouche * 0.55, 38), mat)
	end

	-- ▸ 4c. bord déchiqueté : éperons rocheux qui débordent de la falaise
	for k = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local excentre = R + rng:NextNumber(-6, 8)
		remplir("FillBall",
			Vector3.new(math.cos(angle) * excentre, ALT - rng:NextNumber(3, 12), math.sin(angle) * excentre),
			rng:NextNumber(5, 9), Enum.Material.Rock)
	end

	-- ▸ 4d. le lagon : bassin creusé puis rempli d'eau
	local solLagon = hauteurIle(A.LAGON.X, A.LAGON.Y) or ALT
	M.niveauLagon = solLagon - 1.6
	remplir("FillCylinder",
		CFrame.new(A.LAGON.X, solLagon - 4, A.LAGON.Y), 9, 34, Enum.Material.Air)
	remplir("FillCylinder",
		CFrame.new(A.LAGON.X, M.niveauLagon - 2.4, A.LAGON.Y), 5, 31, Enum.Material.Water)
	-- berges sableuses
	for k = 1, 14 do
		local angle = (k / 14) * math.pi * 2
		remplir("FillBall",
			Vector3.new(A.LAGON.X + math.cos(angle) * 34, solLagon - 2.5, A.LAGON.Y + math.sin(angle) * 34),
			5, Enum.Material.Ground)
	end

	-- ▸ 4e. la rivière : du lagon jusqu'au bord du vide
	local sortie = Vector2.new(-(R + 6), 20 * ECH)
	M.sortieCascade = sortie
	local nPasRiviere = 26
	local dernierH = solLagon -- au-delà de la falaise, on garde la dernière hauteur connue
	for i = 0, nPasRiviere do
		local t = i / nPasRiviere
		local pos2 = A.LAGON:Lerp(sortie, t)
		local serpente = math.sin(t * math.pi * 2.2) * 7 * (1 - t)
		local x, z = pos2.X, pos2.Y + serpente
		local h = hauteurIle(x, z) or dernierH
		dernierH = h
		remplir("FillBall", Vector3.new(x, h - 1, z), 6, Enum.Material.Air)
		if t < 0.97 then
			remplir("FillBall", Vector3.new(x, h - 3.4, z), 4.2, Enum.Material.Water)
		end
	end

	-- ▸ 4f. îlots satellites décoratifs (profondeur visuelle autour de l'île)
	local function ilot(cx, cy, cz, rayon)
		remplir("FillBall", Vector3.new(cx, cy, cz), rayon, Enum.Material.Rock)
		remplir("FillBall", Vector3.new(cx, cy + rayon * 0.62, cz), rayon * 0.62, Enum.Material.Grass)
		remplir("FillBall", Vector3.new(cx, cy - rayon * 0.9, cz), rayon * 0.42, Enum.Material.Basalt)
	end
	ilot(-R - 190, ALT - 34, -R - 30, 26)
	ilot(R + 120, ALT + 12, R + 70, 17)

	-- ▸ 4g. l'îlot du Jardin d'Éther (zone secrète n°2)
	if CONFIG.COLLECTIBLES.SECRETS then
		M.jardinY = ALT + 34
		remplir("FillBall", Vector3.new(A.JARDIN.X, M.jardinY - 12, A.JARDIN.Y), 20, Enum.Material.Rock)
		remplir("FillBall", Vector3.new(A.JARDIN.X, M.jardinY - 2, A.JARDIN.Y), 13, Enum.Material.Grass)
		remplir("FillBall", Vector3.new(A.JARDIN.X, M.jardinY - 26, A.JARDIN.Y), 9, Enum.Material.Basalt)
	end

	-- ▸ 4h. la Grotte de Lune (zone secrète n°1), creusée derrière la cascade
	if CONFIG.COLLECTIBLES.SECRETS then
		local cc = Vector3.new(-R * 0.62, ALT - 36, 22 * ECH) -- centre de la chambre
		M.centreGrotte = cc
		-- on garantit d'abord une masse rocheuse pleine autour de la chambre…
		remplir("FillBall", cc, 24, Enum.Material.Rock)
		remplir("FillBall", cc + Vector3.new(-16, 2, 0), 20, Enum.Material.Rock)
		remplir("FillBall", cc + Vector3.new(-32, 4, 0), 18, Enum.Material.Rock)
		-- …puis on creuse la chambre…
		remplir("FillBall", cc + Vector3.new(0, 4, 0), 14, Enum.Material.Air)
		remplir("FillBall", cc + Vector3.new(8, 2, 4), 10, Enum.Material.Air)
		-- …le sol plat de la chambre…
		remplir("FillBall", cc + Vector3.new(0, -13, 0), 12, Enum.Material.Slate)
		remplir("FillBall", cc + Vector3.new(8, -13, 4), 9, Enum.Material.Slate)
		-- …et le tunnel d'entrée qui débouche sur la falaise, derrière la cascade
		local bouche = Vector3.new(-(R - 32), ALT - 30, 22 * ECH)
		M.boucheGrotte = bouche
		for i = 0, 8 do
			local t = i / 8
			local point = bouche:Lerp(cc + Vector3.new(0, 4, 0), t)
			remplir("FillBall", point, 6.5, Enum.Material.Air)
			remplir("FillBall", point - Vector3.new(0, 7, 0), 5.5, Enum.Material.Slate)
		end
	end

	print("⛰️  [2/9] Terrain sculpté : prairie, cône rocheux, lagon, rivière, grotte (" .. M.nbTerrains .. " opérations)")
end

--------------------------------------------------------------------------------
-- SECTION 5 · YGGDRALUMA, L'ARBRE-CRISTAL — le landmark visible de partout
--------------------------------------------------------------------------------
do
	local landmark = U.model("Landmark_Yggdraluma", M.racine)
	local solArbre = U.sol(A.ARBRE.X, A.ARBRE.Y)
	local base = solArbre or Vector3.new(A.ARBRE.X, ALT + CONFIG.ILE.RELIEF, A.ARBRE.Y)
	local ECORCE = Color3.fromRGB(88, 62, 78) -- écorce mauve sombre, accordée au violet de la palette

	-- ▸ tronc : 7 segments en courbe douce (léger "S") qui s'affinent en montant
	local hauteurTronc = 46
	local points = {}
	for i = 0, 7 do
		local t = i / 7
		table.insert(points, base + Vector3.new(
			math.sin(t * math.pi) * 5.5,
			t * hauteurTronc,
			math.sin(t * math.pi * 0.5) * -2.5
		))
	end
	for i = 1, #points - 1 do
		local t = (i - 1) / (#points - 1)
		U.tube(points[i], points[i + 1], 5.4 * (1 - t * 0.62), {
			Material = Enum.Material.Slate, Color = ECORCE,
			Parent = landmark, Name = "Tronc_" .. i, Rallonge = 1.6,
		})
	end
	local sommet = points[#points]

	-- ▸ racines massives qui plongent dans le sol
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + 0.4
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		U.tube(base + dir * 2 + Vector3.new(0, 3, 0), base + dir * rng:NextNumber(9, 14) - Vector3.new(0, 3.5, 0),
			rng:NextNumber(1.3, 1.9), { Material = Enum.Material.Slate, Color = ECORCE, Parent = landmark, Name = "Racine_" .. i })
	end

	-- ▸ branches + grappes de cristal au bout de chacune
	local teintesCanopee = { P.TURQUOISE, P.TURQUOISE, P.VIOLET_NUIT, P.TURQUOISE, P.ROSE_CORAIL }
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2 + 0.9
		local dir = Vector3.new(math.cos(angle), rng:NextNumber(0.55, 0.9), math.sin(angle)).Unit
		local depart = sommet - Vector3.new(0, rng:NextNumber(2, 7), 0)
		local bout = depart + dir * rng:NextNumber(11, 16)
		U.tube(depart, bout, rng:NextNumber(1.1, 1.5), {
			Material = Enum.Material.Slate, Color = ECORCE, Parent = landmark, Name = "Branche_" .. i, Rallonge = 1,
		})
		U.cristal(bout, rng:NextNumber(7, 10), teintesCanopee[i], {
			Parent = landmark, Nom = "Canopee_" .. i, Branches = 4,
			Portee = 26, Brillance = 0.9, Scintille = i <= 2,
		})
	end

	-- ▸ cœur de la couronne : sphère de lumière + grand cristal central
	local coeurPos = sommet + Vector3.new(0, 6, 0)
	local halo = U.boule(coeurPos, 5, {
		Material = Enum.Material.Neon, Color = P.TURQUOISE:Lerp(Color3.new(1, 1, 1), 0.45),
		Transparency = 0.35, CanCollide = false, CastShadow = false, Parent = landmark, Nom = "Halo",
	})
	halo.Name = "IF_HaloArbre"
	CollectionService:AddTag(halo, "IF_HaloArbre")
	U.cristal(coeurPos - Vector3.new(0, 3, 0), 14, P.TURQUOISE, {
		Parent = landmark, Nom = "CouronneCentrale", Branches = 5, Lumiere = false,
	})
	local coeurAncre = U.ancre(CFrame.new(coeurPos), nil, landmark, "CoeurAncre")
	local coeurLumiere = U.lumiere(coeurAncre, P.TURQUOISE, 85, 1.6, true)
	CollectionService:AddTag(coeurLumiere, "IF_CoeurArbre")

	-- ▸ colonne de lumière : le repère que l'on voit depuis toute la map
	U.part{
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(115, 2.4, 2.4),
		CFrame = CFrame.new(coeurPos + Vector3.new(0, 57, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon, Color = P.TURQUOISE, Transparency = 0.88,
		CanCollide = false, CastShadow = false, Parent = landmark, Name = "ColonneDeLumiere",
	}

	-- ▸ particules : spores lumineuses qui montent + poussière d'étoile qui retombe
	U.particules(coeurAncre, {
		Name = "Spores", Color = ColorSequence.new(P.TURQUOISE, Color3.new(1, 1, 1)),
		Rate = 7, Size = NumberSequence.new(0.35), Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(1.2, 2.4), Direction = Enum.NormalId.Top, Spread = Vector2.new(40, 40),
	})
	U.particules(coeurAncre, {
		Name = "PoussiereEtoile", Color = ColorSequence.new(P.OR_AMBRE),
		Rate = 3.5, Size = NumberSequence.new(0.24), Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(0.8, 1.6), Direction = Enum.NormalId.Bottom, Spread = Vector2.new(70, 70),
		Acceleration = Vector3.new(0.4, 0, 0),
	})

	-- ▸ rochers en orbite lente autour de la couronne (animés par le runtime)
	landmark:SetAttribute("CentreOrbite", coeurPos)
	for i = 1, 6 do
		local taille = rng:NextNumber(1.4, 2.8)
		local rocher = U.part{
			Size = Vector3.new(taille, taille * 0.8, taille * 1.1),
			CFrame = CFrame.new(coeurPos + Vector3.new(14 + i, 0, 0)),
			Material = Enum.Material.Rock, Color = Color3.fromRGB(110, 96, 116),
			CanCollide = false, Parent = landmark, Name = "RocherOrbite_" .. i,
		}
		rocher:SetAttribute("Centre", coeurPos)
		rocher:SetAttribute("Rayon", rng:NextNumber(13, 20))
		rocher:SetAttribute("Vitesse", rng:NextNumber(0.12, 0.3) * (i % 2 == 0 and 1 or -1))
		rocher:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
		CollectionService:AddTag(rocher, "IF_Orbite")
	end

	-- ▸ le Nid d'Aurore : petites vigies à escalader le long du tronc (verticalité)
	local nid
	for i = 1, 6 do
		local t = i / 6
		local angle = t * math.pi * 2.6
		local appui = base:Lerp(sommet, t * 0.72) + Vector3.new(math.cos(angle) * 7.2, 0, math.sin(angle) * 7.2)
		local marche = U.part{
			Size = Vector3.new(4.4, 0.8, 3.2),
			CFrame = CFrame.new(appui) * CFrame.Angles(0, -angle, 0),
			Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(112, 82, 62),
			Parent = landmark, Name = "Vigie_" .. i,
		}
		nid = marche
	end
	if nid then
		local posNid = nid.Position + Vector3.new(0, 2.6, 0)
		table.insert(M.poi, posNid)
		table.insert(M.poi, posNid + Vector3.new(2, 0.5, 1))
	end

	-- ▸ le sanctuaire au pied de l'arbre : cercle de menhirs runiques
	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		local pos2 = A.ARBRE + Vector2.new(math.cos(angle), math.sin(angle)) * 30
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol then
			local yaw = -angle + math.pi / 2
			local menhir = U.part{
				Size = Vector3.new(2.4, rng:NextNumber(5.5, 7.5), 1.7),
				CFrame = CFrame.new(posSol + Vector3.new(0, 2.6, 0))
					* CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), yaw, math.rad(rng:NextNumber(-6, 6))),
				Material = Enum.Material.Granite, Color = Color3.fromRGB(122, 108, 128),
				Parent = landmark, Name = "Menhir_" .. i,
			}
			U.part{ -- rune gravée lumineuse
				Size = Vector3.new(0.5, 3.2, 0.3),
				CFrame = menhir.CFrame * CFrame.new(0, 0.4, -0.78),
				Material = Enum.Material.Neon, Color = P.TURQUOISE, Transparency = 0.25,
				CanCollide = false, CastShadow = false, Parent = landmark, Name = "Rune_" .. i,
			}
		end
	end

	-- ▸ racine de cristal : la pointe inversée sous l'île (visible depuis les îlots)
	U.cristal(Vector3.new(0, ALT - CONFIG.ILE.PROFONDEUR - 6, 0), -16, P.TURQUOISE, {
		Parent = landmark, Nom = "RacineDeCristal", Branches = 4, Portee = 40, Brillance = 1,
	})

	M.coeurArbre = coeurPos
	M.baseArbre = base
	print("🌳 [3/9] Yggdraluma dressé : tronc en S, 5 grappes de cristal, orbites, sanctuaire")
end

--------------------------------------------------------------------------------
-- SECTION 6 · LES CINQ ZONES
--------------------------------------------------------------------------------

-- ▸ petites fabriques réutilisées par plusieurs zones -------------------------

-- lanterne sur poteau : la signature lumineuse des chemins
function U.lanterne(pos, o)
	o = o or {}
	local m = U.model("Lanterne", o.Parent or M.dLanternes)
	local BOIS = Color3.fromRGB(86, 60, 48)
	local h = o.Hauteur or 7
	local yaw = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	U.part{ Size = Vector3.new(0.7, h, 0.7), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)),
		Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Poteau" }
	U.part{ Size = Vector3.new(2.8, 0.5, 0.6),
		CFrame = CFrame.new(pos + Vector3.new(0, h - 0.4, 0) + dir * 1) * CFrame.Angles(0, -yaw, 0),
		Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Bras" }
	local suspension = pos + dir * 2 + Vector3.new(0, h - 1.4, 0)
	U.part{ Size = Vector3.new(0.14, 1, 0.14), CFrame = CFrame.new(suspension + Vector3.new(0, 0.8, 0)),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 56, 54), Parent = m, Name = "Chaine", CanCollide = false }
	U.part{ Size = Vector3.new(1.25, 1.5, 1.25), CFrame = CFrame.new(suspension),
		Material = Enum.Material.Glass, Color = P.OR_AMBRE, Transparency = 0.5,
		Parent = m, Name = "Verre", CanCollide = false, CastShadow = false }
	local flamme = U.part{ Size = Vector3.new(0.6, 0.85, 0.6), CFrame = CFrame.new(suspension),
		Material = Enum.Material.Neon, Color = P.OR_AMBRE, Parent = m, Name = "Flamme",
		CanCollide = false, CastShadow = false }
	U.part{ Size = Vector3.new(1.6, 0.35, 1.6), CFrame = CFrame.new(suspension + Vector3.new(0, 0.9, 0)),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(52, 48, 50), Parent = m, Name = "Chapeau", CanCollide = false }
	local lum = U.lumiere(flamme, P.OR_AMBRE, o.Portee or 19, 1.15)
	CollectionService:AddTag(lum, "IF_Lanterne") -- le runtime fait vaciller la flamme
	U.particules(flamme, {
		Color = ColorSequence.new(P.OR_AMBRE), Rate = 0.6, Size = NumberSequence.new(0.18),
		Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(0.3, 0.7),
	})
	return m
end

-- panneau de zone en bois avec nom flottant (lisible à l'approche)
function U.panneau(pos, titre, sousTitre, parent)
	local m = U.model("Panneau_" .. titre, parent)
	local BOIS = Color3.fromRGB(96, 68, 52)
	U.part{ Size = Vector3.new(0.6, 4.6, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 2.3, 0)),
		Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Poteau" }
	local planche = U.part{ Size = Vector3.new(4.6, 1.5, 0.4), CFrame = CFrame.new(pos + Vector3.new(0, 3.7, 0)),
		Material = Enum.Material.WoodPlanks, Color = BOIS, Parent = m, Name = "Planche" }
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 240, 0, 64)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 90
	gui.Parent = planche
	local titreLabel = Instance.new("TextLabel")
	titreLabel.Size = UDim2.new(1, 0, 0.62, 0)
	titreLabel.BackgroundTransparency = 1
	titreLabel.Font = Enum.Font.FredokaOne
	titreLabel.TextScaled = true
	titreLabel.Text = titre
	titreLabel.TextColor3 = Color3.fromRGB(255, 232, 190)
	titreLabel.TextStrokeTransparency = 0.35
	titreLabel.Parent = gui
	local sousLabel = Instance.new("TextLabel")
	sousLabel.Size = UDim2.new(1, 0, 0.38, 0)
	sousLabel.Position = UDim2.new(0, 0, 0.62, 0)
	sousLabel.BackgroundTransparency = 1
	sousLabel.Font = Enum.Font.Fondamento
	sousLabel.TextScaled = true
	sousLabel.Text = sousTitre or ""
	sousLabel.TextColor3 = Color3.fromRGB(214, 198, 224)
	sousLabel.TextStrokeTransparency = 0.5
	sousLabel.Parent = gui
	return m
end

-- ▸ ZONE 1 · LE BELVÉDÈRE DE L'AUBE (spawn) -----------------------------------
do
	local zone = U.model("Zone_BelvedereDeLAube", M.dZones)
	local posSol = U.sol(A.SPAWN.X, A.SPAWN.Y) or Vector3.new(A.SPAWN.X, ALT + 14, A.SPAWN.Y)
	local centre = posSol + Vector3.new(0, 0.4, 0)
	local versArbre = CFrame.lookAt(centre, Vector3.new(M.baseArbre.X, centre.Y, M.baseArbre.Z))
	local PIERRE = Color3.fromRGB(168, 158, 148)

	-- plate-forme circulaire en pierre avec liseré lumineux ambré
	U.cylindreVertical(centre - Vector3.new(0, 1.2, 0), 1.5, 11.8, {
		Material = Enum.Material.Neon, Color = P.OR_AMBRE, Transparency = 0.55,
		Parent = zone, Name = "Lisere", CastShadow = false,
	})
	U.cylindreVertical(centre - Vector3.new(0, 0.6, 0), 1.4, 11, {
		Material = Enum.Material.Cobblestone, Color = PIERRE, Parent = zone, Name = "Plateforme",
	})
	U.cylindreVertical(centre + Vector3.new(0, 0.75, 0), 0.25, 7.5, {
		Material = Enum.Material.Marble, Color = Color3.fromRGB(214, 202, 188),
		Parent = zone, Name = "Rosace",
	})

	-- le point d'apparition regarde l'arbre-cristal : première image = la plus belle
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = versArbre * CFrame.new(0, 0.95, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Name = "SpawnPrincipal"
	spawn.Parent = zone
	M.nbParts = M.nbParts + 1

	-- la Porte de l'Aube : arche qui cadre l'arbre et le soleil couchant
	local arche = versArbre * CFrame.new(0, 0, -10.5)
	for cote = -1, 1, 2 do
		U.part{ Size = Vector3.new(2, 10, 2), CFrame = arche * CFrame.new(cote * 5.4, 5, 0),
			Material = Enum.Material.Granite, Color = PIERRE, Parent = zone, Name = "PilierPorte" }
		U.part{ Size = Vector3.new(1.4, 1.4, 1.4), CFrame = arche * CFrame.new(cote * 5.4, 10.6, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
			Material = Enum.Material.Glass, Color = P.TURQUOISE, Transparency = 0.25,
			Parent = zone, Name = "OrnementPorte", CanCollide = false }
	end
	U.part{ Size = Vector3.new(13.6, 1.7, 2.4), CFrame = arche * CFrame.new(0, 10.6, 0),
		Material = Enum.Material.Granite, Color = PIERRE, Parent = zone, Name = "Linteau" }
	U.cristal(arche:PointToWorldSpace(Vector3.new(0, 11.6, 0)), 3.4, P.TURQUOISE, { Parent = zone, Nom = "JoyauPorte", Branches = 3 })

	-- muret en arc derrière le spawn + oriflammes
	for i = -2, 2 do
		local angle = math.rad(i * 24)
		U.part{
			Size = Vector3.new(5.4, 2, 1.2),
			CFrame = versArbre * CFrame.Angles(0, angle, 0) * CFrame.new(0, 1, 12.6),
			Material = Enum.Material.Cobblestone, Color = PIERRE, Parent = zone, Name = "Muret",
		}
	end
	for cote = -1, 1, 2 do
		local pied = versArbre:PointToWorldSpace(Vector3.new(cote * 10.5, 0, 9))
		U.part{ Size = Vector3.new(0.5, 9, 0.5), CFrame = CFrame.new(pied + Vector3.new(0, 4.5, 0)),
			Material = Enum.Material.Wood, Color = Color3.fromRGB(86, 60, 48), Parent = zone, Name = "Mat" }
		U.part{ Size = Vector3.new(2.6, 3.6, 0.12), CFrame = CFrame.new(pied + Vector3.new(0, 7.4, 0)) * versArbre.Rotation * CFrame.new(1.4, 0, 0),
			Material = Enum.Material.Fabric, Color = P.ROSE_CORAIL, Parent = zone, Name = "Oriflamme", CanCollide = false }
	end

	U.lanterne(versArbre:PointToWorldSpace(Vector3.new(-8, 0, -6)), { Parent = zone })
	U.lanterne(versArbre:PointToWorldSpace(Vector3.new(8, 0, -6)), { Parent = zone })
	U.panneau(versArbre:PointToWorldSpace(Vector3.new(9, 0, 3)), "Belvédère de l'Aube", "Le voyage commence ici", zone)

	table.insert(M.poi, centre + Vector3.new(0, 3.4, 0)) -- un éclat au centre de la rosace
	M.posSpawn = centre
	M.cfSpawn = versArbre
	print("🚪 [4/9] Belvédère de l'Aube : spawn face à l'arbre, Porte de l'Aube, oriflammes")
end

-- ▸ ZONE 2 · LE HAMEAU DES LUCIOLES (village) ---------------------------------
do
	local zone = U.model("Zone_HameauDesLucioles", M.dZones)
	local BOIS = Color3.fromRGB(86, 60, 48)
	local CREME = Color3.fromRGB(234, 220, 196)

	-- maison à colombages : murs percés d'une vraie porte, fenêtres qui rayonnent
	local function maison(cf, L, Prof, H, couleurToit, nom)
		local m = U.model(nom or "Maison", zone)
		local demiL, demiP = L / 2, Prof / 2
		local teinteMur = U.nuance(CREME, 0.04)
		U.part{ Size = Vector3.new(L + 1.6, 0.9, Prof + 1.6), CFrame = cf * CFrame.new(0, 0.45, 0),
			Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(150, 142, 134), Parent = m, Name = "Socle" }
		-- mur arrière et murs latéraux
		U.part{ Size = Vector3.new(L, H, 0.8), CFrame = cf * CFrame.new(0, H / 2 + 0.9, demiP - 0.4),
			Material = Enum.Material.SmoothPlastic, Color = teinteMur, Parent = m, Name = "MurArriere" }
		for cote = -1, 1, 2 do
			U.part{ Size = Vector3.new(0.8, H, Prof), CFrame = cf * CFrame.new(cote * (demiL - 0.4), H / 2 + 0.9, 0),
				Material = Enum.Material.SmoothPlastic, Color = teinteMur, Parent = m, Name = "MurLateral" }
			-- fenêtre chaleureuse : vitre + panneau lumineux + lumière intérieure
			local fenetre = cf * CFrame.new(cote * (demiL - 0.4), H * 0.58 + 0.9, Prof * 0.08)
			U.part{ Size = Vector3.new(1, 2.1, 2.5), CFrame = fenetre,
				Material = Enum.Material.Glass, Color = Color3.fromRGB(200, 226, 220), Transparency = 0.35,
				Parent = m, Name = "Fenetre", CanCollide = false }
			local lueur = U.part{ Size = Vector3.new(0.3, 1.9, 2.3), CFrame = fenetre,
				Material = Enum.Material.Neon, Color = P.OR_AMBRE, Transparency = 0.3,
				Parent = m, Name = "LueurFenetre", CanCollide = false, CastShadow = false }
			U.lumiere(lueur, P.OR_AMBRE, 13, 0.8)
			-- jardinière fleurie sous la fenêtre
			U.part{ Size = Vector3.new(1.2, 0.5, 2.3), CFrame = fenetre * CFrame.new(cote * 0.5, -1.5, 0),
				Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Jardiniere", CanCollide = false }
			U.part{ Size = Vector3.new(0.9, 0.5, 2), CFrame = fenetre * CFrame.new(cote * 0.5, -1.1, 0),
				Material = Enum.Material.Grass, Color = P.ROSE_CORAIL, Parent = m, Name = "Fleurs", CanCollide = false }
		end
		-- façade avant : deux pans + linteau, la porte est une vraie ouverture
		local largPorte, hautPorte = 3, 4.6
		local largPan = (L - largPorte) / 2
		for cote = -1, 1, 2 do
			U.part{ Size = Vector3.new(largPan, H, 0.8),
				CFrame = cf * CFrame.new(cote * (largPorte / 2 + largPan / 2), H / 2 + 0.9, -demiP + 0.4),
				Material = Enum.Material.SmoothPlastic, Color = teinteMur, Parent = m, Name = "MurAvant" }
		end
		U.part{ Size = Vector3.new(largPorte, H - hautPorte, 0.8),
			CFrame = cf * CFrame.new(0, hautPorte + (H - hautPorte) / 2 + 0.9, -demiP + 0.4),
			Material = Enum.Material.SmoothPlastic, Color = teinteMur, Parent = m, Name = "LinteauPorte" }
		U.part{ Size = Vector3.new(largPorte - 0.5, hautPorte - 0.3, 0.35),
			CFrame = cf * CFrame.new(-0.8, hautPorte / 2 + 0.75, -demiP - 0.25) * CFrame.Angles(0, math.rad(24), 0),
			Material = Enum.Material.WoodPlanks, Color = BOIS, Parent = m, Name = "PorteEntrouverte" }
		-- colombages : poteaux d'angle + sablières
		for cx = -1, 1, 2 do
			for cz = -1, 1, 2 do
				U.part{ Size = Vector3.new(1, H + 0.6, 1), CFrame = cf * CFrame.new(cx * demiL, H / 2 + 0.9, cz * demiP),
					Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Colombage" }
			end
		end
		for cz = -1, 1, 2 do
			U.part{ Size = Vector3.new(L + 1.2, 0.8, 1), CFrame = cf * CFrame.new(0, H + 0.9, cz * demiP),
				Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Sabliere" }
		end
		-- toit à deux pans + faîtage + pignons
		local angleToit = math.rad(33)
		local demiPortee = demiP + 1.5
		local montee = demiPortee * math.tan(angleToit)
		local longueurPan = demiPortee / math.cos(angleToit) + 0.7
		for s = -1, 1, 2 do
			U.part{
				Size = Vector3.new(L + 2.8, 0.5, longueurPan),
				CFrame = cf * CFrame.new(0, H + 0.9 + montee / 2, s * demiPortee / 2) * CFrame.Angles(-s * angleToit, 0, 0),
				Material = Enum.Material.Slate, Color = U.nuance(couleurToit, 0.04), Parent = m, Name = "PanDeToit",
			}
		end
		U.part{ Size = Vector3.new(L + 3, 0.9, 0.9), CFrame = cf * CFrame.new(0, H + 0.9 + montee, 0),
			Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Faitage" }
		for cz = -1, 1, 2 do
			U.part{ Size = Vector3.new(L * 0.55, montee, 0.7), CFrame = cf * CFrame.new(0, H + 0.9 + montee / 2, cz * (demiP - 0.35)),
				Material = Enum.Material.SmoothPlastic, Color = teinteMur, Parent = m, Name = "Pignon", CanCollide = false }
		end
		-- cheminée fumante
		local cheminee = U.part{ Size = Vector3.new(1.7, 3.6, 1.7), CFrame = cf * CFrame.new(L * 0.26, H + montee * 0.6 + 1.6, Prof * 0.18),
			Material = Enum.Material.Brick, Color = Color3.fromRGB(140, 110, 100), Parent = m, Name = "Cheminee" }
		U.particules(cheminee, {
			Name = "Fumee", Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(216, 200, 196)), Rate = 1.4,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.4) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(1, 1.8),
			Spread = Vector2.new(12, 12), LightEmission = 0,
		})
		return m
	end

	-- cinq maisons + l'auberge, en cercle autour de la place du puits
	local defsMaisons = {
		{ angle = 15,  L = 11, P = 10, H = 6, toit = P.ROSE_CORAIL },
		{ angle = 80,  L = 15, P = 13, H = 7.5, toit = P.VIOLET_NUIT, nom = "Auberge_DuCristalQuiChante" },
		{ angle = 150, L = 10, P = 10, H = 6, toit = P.VIOLET_NUIT },
		{ angle = 215, L = 12, P = 11, H = 6.5, toit = P.ROSE_CORAIL },
		{ angle = 292, L = 10, P = 9,  H = 5.5, toit = P.ROSE_CORAIL },
	}
	for i, def in ipairs(defsMaisons) do
		local rad = math.rad(def.angle)
		local pos2 = A.VILLAGE + Vector2.new(math.cos(rad), math.sin(rad)) * 27
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol then
			local cf = CFrame.lookAt(posSol, Vector3.new(A.VILLAGE.X, posSol.Y, A.VILLAGE.Y))
			maison(cf, def.L, def.P, def.H, def.toit, def.nom or ("Maison_" .. i))
		end
	end

	-- enseigne suspendue de l'auberge
	local posAuberge = U.sol(A.VILLAGE.X + math.cos(math.rad(80)) * 20, A.VILLAGE.Y + math.sin(math.rad(80)) * 20)
	if posAuberge then
		local m = U.model("EnseigneAuberge", zone)
		U.part{ Size = Vector3.new(0.5, 5.4, 0.5), CFrame = CFrame.new(posAuberge + Vector3.new(0, 2.7, 0)),
			Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Poteau" }
		U.part{ Size = Vector3.new(2.4, 0.4, 0.4), CFrame = CFrame.new(posAuberge + Vector3.new(0.9, 5, 0)),
			Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Potence" }
		local enseigne = U.part{ Size = Vector3.new(2, 1.5, 0.2), CFrame = CFrame.new(posAuberge + Vector3.new(1.5, 4, 0)),
			Material = Enum.Material.WoodPlanks, Color = U.nuance(BOIS), Parent = m, Name = "Enseigne", CanCollide = false }
		U.part{ Size = Vector3.new(0.5, 0.8, 0.28), CFrame = enseigne.CFrame * CFrame.Angles(0, 0, math.rad(45)),
			Material = Enum.Material.Neon, Color = P.TURQUOISE, Parent = m, Name = "CristalPeint", CanCollide = false, CastShadow = false }
	end

	-- la place : puits central sous son toit, dalles rayonnantes
	local posPuits = U.sol(A.VILLAGE.X, A.VILLAGE.Y)
	if posPuits then
		local m = U.model("PuitsAuxVoeux", zone)
		U.cylindreVertical(posPuits - Vector3.new(0, 0.4, 0), 0.6, 8.5, {
			Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(152, 144, 136), Parent = m, Name = "Place",
		})
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			U.part{ Size = Vector3.new(1.6, 1.7, 1),
				CFrame = CFrame.new(posPuits + Vector3.new(math.cos(angle) * 2.4, 0.9, math.sin(angle) * 2.4)) * CFrame.Angles(0, -angle, 0),
				Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(134, 126, 122), Parent = m, Name = "Margelle" }
		end
		local eauPuits = U.cylindreVertical(posPuits + Vector3.new(0, 0.25, 0), 0.3, 2.1, {
			Material = Enum.Material.Glass, Color = P.TURQUOISE, Transparency = 0.35, Parent = m, Name = "EauDuPuits", CanCollide = false,
		})
		U.lumiere(eauPuits, P.TURQUOISE, 10, 0.6)
		for cote = -1, 1, 2 do
			U.part{ Size = Vector3.new(0.5, 4.2, 0.5), CFrame = CFrame.new(posPuits + Vector3.new(cote * 2.6, 2.5, 0)),
				Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "PoteauPuits" }
		end
		U.tube(posPuits + Vector3.new(-2.6, 4.5, 0), posPuits + Vector3.new(2.6, 4.5, 0), 0.2,
			{ Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Treuil" })
		for s = -1, 1, 2 do
			U.part{ Size = Vector3.new(6.6, 0.4, 2.6), CFrame = CFrame.new(posPuits + Vector3.new(0, 5.3, s * 1.05)) * CFrame.Angles(-s * math.rad(30), 0, 0),
				Material = Enum.Material.Slate, Color = P.ROSE_CORAIL, Parent = m, Name = "ToitPuits" }
		end
		U.part{ Size = Vector3.new(0.12, 1.6, 0.12), CFrame = CFrame.new(posPuits + Vector3.new(0, 3.7, 0)),
			Material = Enum.Material.Fabric, Color = Color3.fromRGB(120, 100, 84), Parent = m, Name = "Corde", CanCollide = false }
		U.cylindreVertical(posPuits + Vector3.new(0, 2.4, 0), 0.7, 0.55, {
			Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Seau", CanCollide = false,
		})
		table.insert(M.poi, posPuits + Vector3.new(0, 3.2, 2.8)) -- éclat posé sur la margelle
	end

	-- deux étals de marché
	for k = 1, 2 do
		local rad = math.rad(k == 1 and 45 or 260)
		local pos2 = A.VILLAGE + Vector2.new(math.cos(rad), math.sin(rad)) * 13
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol then
			local m = U.model("Etal_" .. k, zone)
			local cf = CFrame.lookAt(posSol, Vector3.new(A.VILLAGE.X, posSol.Y, A.VILLAGE.Y))
			U.part{ Size = Vector3.new(5, 0.5, 2.6), CFrame = cf * CFrame.new(0, 1.5, 0),
				Material = Enum.Material.WoodPlanks, Color = BOIS, Parent = m, Name = "Comptoir" }
			for cote = -1, 1, 2 do
				U.part{ Size = Vector3.new(0.45, 4.4, 0.45), CFrame = cf * CFrame.new(cote * 2.2, 2.2, 0.9),
					Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Montant" }
			end
			U.part{ Size = Vector3.new(5.6, 0.3, 3.6), CFrame = cf * CFrame.new(0, 4.5, 0.4) * CFrame.Angles(math.rad(14), 0, 0),
				Material = Enum.Material.Fabric, Color = k == 1 and P.ROSE_CORAIL or P.TURQUOISE, Parent = m, Name = "Auvent" }
			U.part{ Size = Vector3.new(1.2, 1.2, 1.2), CFrame = cf * CFrame.new(-1.4, 2.3, 0),
				Material = Enum.Material.WoodPlanks, Color = U.nuance(BOIS), Parent = m, Name = "Caisse", CanCollide = false }
			U.boule(cf:PointToWorldSpace(Vector3.new(1.2, 2.2, 0)), 0.55,
				{ Material = Enum.Material.Neon, Color = P.OR_AMBRE, Parent = m, Name = "FruitLumineux", CanCollide = false, CastShadow = false })
		end
	end

	-- lanternes et tonneaux qui habillent la place
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + 0.5
		local pos2 = A.VILLAGE + Vector2.new(math.cos(angle), math.sin(angle)) * 15
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol then U.lanterne(posSol, { Parent = zone }) end
	end
	for i = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local pos2 = A.VILLAGE + Vector2.new(math.cos(angle), math.sin(angle)) * rng:NextNumber(17, 24)
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol then
			U.cylindreVertical(posSol, rng:NextNumber(1.6, 2.2), 0.9, {
				Material = Enum.Material.WoodPlanks, Color = U.nuance(BOIS), Parent = zone, Name = "Tonneau",
				TiltX = rng:NextNumber(-4, 4),
			})
		end
	end

	local posPanneau = U.sol(A.VILLAGE.X - 24, A.VILLAGE.Y + 20)
	if posPanneau then U.panneau(posPanneau, "Hameau des Lucioles", "On y dort bien, dit-on", zone) end
	print("🏘️  [5/9] Hameau des Lucioles : 5 maisons à colombages, auberge, puits, étals")
end

-- ▸ ZONE 3 · LE BOSQUET D'AURÉLINE (autour de l'arbre) ------------------------
do
	local zone = U.model("Zone_BosquetDAureline", M.dZones)
	-- cercles de cristaux sauvages autour du sanctuaire
	for i = 1, math.floor(8 * DENS) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local pos2 = A.BOSQUET + Vector2.new(math.cos(angle), math.sin(angle)) * rng:NextNumber(16, 42)
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol then
			local teinte = rng:NextNumber() > 0.3 and P.TURQUOISE or P.VIOLET_NUIT
			U.cristal(posSol, rng:NextNumber(2.4, 5.5), teinte, { Parent = zone, Scintille = rng:NextNumber() > 0.6 })
		end
	end
	local posPanneau = U.sol(A.BOSQUET.X + 20, A.BOSQUET.Y + 26)
	if posPanneau then U.panneau(posPanneau, "Bosquet d'Auréline", "Les cristaux y chantent la nuit", zone) end
end

-- ▸ ZONE 4 · LE LAGON DU VOILE (lagon, cascade, ponton) -----------------------
do
	local zone = U.model("Zone_LagonDuVoile", M.dZones)
	local BOIS = Color3.fromRGB(86, 60, 48)

	-- pierres de nénuphar : traversée sautillante du lagon
	local depart = A.LAGON + Vector2.new(-24, 18)
	local arrivee = A.LAGON + Vector2.new(26, -14)
	for i = 0, 6 do
		local t = i / 6
		local pos2 = depart:Lerp(arrivee, t) + Vector2.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3))
		local pierre = U.cylindreVertical(Vector3.new(pos2.X, M.niveauLagon - 0.4, pos2.Y), 0.9, rng:NextNumber(1.5, 2.3), {
			Material = Enum.Material.Slate, Color = Color3.fromRGB(128, 122, 130), Parent = zone, Name = "PierreNenuphar_" .. i,
		})
		if i == 3 then table.insert(M.poi, pierre.Position + Vector3.new(0, 3, 0)) end
	end

	-- ponton du pêcheur d'étoiles
	local basePonton = U.sol(A.LAGON.X + 30, A.LAGON.Y + 22)
	if basePonton then
		local m = U.model("PontonDuPecheur", zone)
		local cf = CFrame.lookAt(basePonton + Vector3.new(0, 0.8, 0), Vector3.new(A.LAGON.X, basePonton.Y, A.LAGON.Y))
		for i = 0, 4 do
			U.part{ Size = Vector3.new(3.4, 0.4, 2), CFrame = cf * CFrame.new(0, 0, -i * 2.05),
				Material = Enum.Material.WoodPlanks, Color = U.nuance(BOIS), Parent = m, Name = "Planche" }
		end
		for cote = -1, 1, 2 do
			for i = 0, 1 do
				U.part{ Size = Vector3.new(0.5, 3.4, 0.5), CFrame = cf * CFrame.new(cote * 1.6, -1.2, -3 - i * 5),
					Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "Pilotis" }
			end
		end
		U.lanterne(cf:PointToWorldSpace(Vector3.new(1.4, 0.2, -8.4)), { Parent = m, Hauteur = 5 })
		table.insert(M.poi, cf:PointToWorldSpace(Vector3.new(0, 3, -9)))
	end

	-- roseaux sur les berges
	for i = 1, math.floor(12 * DENS) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local pos2 = A.LAGON + Vector2.new(math.cos(angle), math.sin(angle)) * rng:NextNumber(30, 37)
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol and posSol.Y > M.niveauLagon - 1 then
			for k = 1, rng:NextInteger(3, 6) do
				local pied = posSol + Vector3.new(rng:NextNumber(-1.4, 1.4), 0, rng:NextNumber(-1.4, 1.4))
				U.tube(pied, pied + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(2.2, 3.6), rng:NextNumber(-0.4, 0.4)), 0.12, {
					Material = Enum.Material.Grass, Color = Color3.fromRGB(96, 128, 70), Parent = zone, Name = "Roseau",
					CanCollide = false, CastShadow = false,
				})
			end
		end
	end

	-- ▸ LA CASCADE : l'eau du lagon se jette dans le vide
	local ex = M.sortieCascade
	local hautChute = ALT - 2
	local voile = U.model("CascadeDuVoile", zone)
	for i, transparence in ipairs({ 0.35, 0.55, 0.72 }) do
		U.part{
			Size = Vector3.new(1 + i * 0.4, 95, 11 - i),
			CFrame = CFrame.new(ex.X + 1 - i * 1.2, hautChute - 47, ex.Y),
			Material = Enum.Material.Glass, Color = Color3.fromRGB(190, 236, 232),
			Transparency = transparence, CanCollide = false, CastShadow = false,
			Parent = voile, Name = "VoileDEau_" .. i,
		}
	end
	local ecume = U.ancre(CFrame.new(ex.X + 1, hautChute + 1, ex.Y), Vector3.new(2, 1, 10), voile, "Ecume")
	U.particules(ecume, {
		Name = "Embruns", Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(228, 248, 246)), Rate = 9,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 3.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(2, 4),
		Direction = Enum.NormalId.Top, Spread = Vector2.new(35, 35), LightEmission = 0.15,
	})
	local chute = U.ancre(CFrame.new(ex.X - 1, hautChute - 4, ex.Y), Vector3.new(2, 2, 9), voile, "Chute")
	U.particules(chute, {
		Name = "EauQuiTombe", Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(206, 240, 238), Color3.fromRGB(168, 216, 224)), Rate = 14,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 5.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2.6, 3.4), Speed = NumberRange.new(26, 34),
		Direction = Enum.NormalId.Bottom, Spread = Vector2.new(8, 8), LightEmission = 0.1,
	})
	local brumeVide = U.ancre(CFrame.new(ex.X - 4, hautChute - 88, ex.Y), Vector3.new(6, 3, 14), voile, "BrumeDuVide")
	U.particules(brumeVide, {
		Name = "Dispersion", Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(214, 206, 232)), Rate = 4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(1, 2.5),
		Spread = Vector2.new(180, 180), LightEmission = 0.2,
	})

	-- passerelle de bois au-dessus de la rivière + belvédère de la cascade
	local xPont = ex.X + 44
	local zRiviere = A.LAGON:Lerp(ex, 1 - 44 / (A.LAGON - ex).Magnitude).Y
	local solNord = U.sol(xPont, zRiviere - 12)
	local solSud = U.sol(xPont, zRiviere + 12)
	if solNord and solSud then
		local m = U.model("PasserelleDuVoile", zone)
		local yTablier = math.max(solNord.Y, solSud.Y) + 1.2
		for i = 0, 11 do
			local t = i / 11
			local zPlanche = solNord.Z + t * (solSud.Z - solNord.Z)
			U.part{
				Size = Vector3.new(3.6, 0.35, 1.75),
				CFrame = CFrame.new(xPont, yTablier + math.sin(t * math.pi) * 1.3, zPlanche)
					* CFrame.Angles(math.rad(rng:NextNumber(-2, 2)), 0, math.rad(rng:NextNumber(-3, 3))),
				Material = Enum.Material.WoodPlanks, Color = U.nuance(BOIS), Parent = m, Name = "Planche_" .. i,
			}
		end
		for cote = -1, 1, 2 do
			for _, extremite in ipairs({ solNord, solSud }) do
				U.part{ Size = Vector3.new(0.5, 3.2, 0.5),
					CFrame = CFrame.new(xPont + cote * 1.7, yTablier + 1, extremite.Z),
					Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "PoteauGardeCorps" }
			end
			U.tube(Vector3.new(xPont + cote * 1.7, yTablier + 2.4, solNord.Z),
				Vector3.new(xPont + cote * 1.7, yTablier + 2.4, solSud.Z), 0.14,
				{ Material = Enum.Material.Fabric, Color = Color3.fromRGB(122, 102, 86), Parent = m, Name = "CordeGardeCorps", CanCollide = false })
		end
		-- petit belvédère qui surplombe la chute
		local posBelvedere = U.sol(ex.X + 16, ex.Y - 14)
		if posBelvedere then
			U.cylindreVertical(posBelvedere - Vector3.new(0, 0.3, 0), 0.7, 4.4, {
				Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(150, 142, 136), Parent = m, Name = "BelvedereCascade",
			})
			U.lanterne(posBelvedere + Vector3.new(2.6, 0.4, 0), { Parent = m, Hauteur = 5.5 })
			table.insert(M.poi, posBelvedere + Vector3.new(0, 3.4, 0))
		end
	end

	local posPanneau = U.sol(A.LAGON.X + 34, A.LAGON.Y + 30)
	if posPanneau then U.panneau(posPanneau, "Lagon du Voile", "L'eau y tombe vers nulle part", zone) end
	print("🌊 [6/9] Lagon du Voile : nénuphars de pierre, ponton, cascade et passerelle")
end

-- ▸ ZONE 5 · LES RUINES DE L'ORDRE CÉLESTE (verticalité) ----------------------
do
	local zone = U.model("Zone_RuinesDeLOrdreCeleste", M.dZones)
	local MARBRE = Color3.fromRGB(212, 200, 192)
	local solRuines = U.sol(A.RUINES.X, A.RUINES.Y) or Vector3.new(A.RUINES.X, ALT + 10, A.RUINES.Y)

	-- colonne antique : tambours empilés légèrement décalés
	local function colonne(pos, hauteur, brisee)
		local m = U.model("Colonne", zone)
		U.cylindreVertical(pos, 0.8, 2, { Material = Enum.Material.Marble, Color = MARBRE, Parent = m, Name = "Base" })
		local nTambours = math.max(1, math.floor(hauteur / 2.6))
		for i = 1, nTambours do
			U.cylindreVertical(
				pos + Vector3.new(rng:NextNumber(-0.15, 0.15), 0.8 + (i - 1) * 2.6, rng:NextNumber(-0.15, 0.15)),
				2.55, 1.45 - i * 0.03,
				{ Material = Enum.Material.Marble, Color = U.nuance(MARBRE, 0.03), Parent = m,
					Name = "Tambour_" .. i, Yaw = rng:NextNumber(0, 25) }
			)
		end
		if not brisee then
			U.part{ Size = Vector3.new(3.4, 0.9, 3.4), CFrame = CFrame.new(pos + Vector3.new(0, 0.8 + nTambours * 2.6 + 0.45, 0)),
				Material = Enum.Material.Marble, Color = MARBRE, Parent = m, Name = "Chapiteau" }
		end
		-- mousse : le temps a repris ses droits
		if rng:NextNumber() > 0.4 then
			U.part{ Size = Vector3.new(2.2, 0.3, 2.2), CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.5, 0.5), 0.95, rng:NextNumber(-0.5, 0.5))),
				Material = Enum.Material.Grass, Color = Color3.fromRGB(104, 138, 76), Parent = m, Name = "Mousse", CanCollide = false }
		end
		return m
	end

	-- le temple circulaire : colonnes debout, brisées et couchées
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local pos2 = A.RUINES + Vector2.new(math.cos(angle), math.sin(angle)) * 17
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol then
			if i % 3 == 0 then
				colonne(posSol, rng:NextNumber(3, 6), true) -- brisée
			elseif i % 4 == 0 then
				-- couchée dans l'herbe (l'axe des cylindres Roblox est sur X)
				U.part{ Size = Vector3.new(8, 2.8, 2.8),
					CFrame = CFrame.new(posSol + Vector3.new(2, 1.1, 0))
						* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0),
					Shape = Enum.PartType.Cylinder,
					Material = Enum.Material.Marble, Color = MARBRE, Parent = zone, Name = "ColonneCouchee",
				}
			else
				colonne(posSol, 12, false)
			end
		end
	end

	-- autel central : un cristal violet flotte au-dessus (le runtime ne le touche pas, il veille)
	local autel = U.part{ Size = Vector3.new(4.4, 2.2, 4.4), CFrame = CFrame.new(solRuines + Vector3.new(0, 1.1, 0)),
		Material = Enum.Material.Marble, Color = MARBRE, Parent = zone, Name = "Autel" }
	U.part{ Size = Vector3.new(5.2, 0.5, 5.2), CFrame = autel.CFrame * CFrame.new(0, 1.35, 0),
		Material = Enum.Material.Granite, Color = U.nuance(MARBRE, 0.05), Parent = zone, Name = "TableDAutel" }
	U.cristal(solRuines + Vector3.new(0, 6.4, 0), 4.6, P.VIOLET_NUIT,
		{ Parent = zone, Nom = "GardienDeLAutel", Branches = 3, Portee = 24, Brillance = 1, Scintille = true })

	-- arche d'entrée effondrée à moitié
	local posArche = U.sol(A.RUINES.X - 14, A.RUINES.Y + 22)
	if posArche then
		colonne(posArche, 10, false)
		colonne(posArche + Vector3.new(9, 0, 0), 7, true)
		U.part{ Size = Vector3.new(6.4, 1.4, 2.2),
			CFrame = CFrame.new(posArche + Vector3.new(2.4, 11.4, 0)) * CFrame.Angles(0, 0, math.rad(-16)),
			Material = Enum.Material.Marble, Color = MARBRE, Parent = zone, Name = "LinteauEffondre" }
	end

	-- ▸ l'ascension : marches volantes en spirale vers la Couronne Céleste
	local sommetCouronne = solRuines + Vector3.new(0, 58, 0)
	for i = 1, 11 do
		local t = i / 11
		local angle = t * math.pi * 2.1
		local rayon = 17 - t * 5
		local marche = U.part{
			Size = Vector3.new(5, 0.9, 5),
			CFrame = CFrame.new(solRuines + Vector3.new(math.cos(angle) * rayon, 3 + i * 4.7, math.sin(angle) * rayon))
				* CFrame.Angles(0, -angle, 0),
			Material = Enum.Material.Limestone, Color = U.nuance(MARBRE, 0.04),
			Parent = zone, Name = "MarcheVolante_" .. i,
		}
		if i == 4 or i == 8 then
			table.insert(M.poi, marche.Position + Vector3.new(0, 3, 0))
		end
	end
	-- la plate-forme sommitale et son anneau brisé
	local couronne = U.model("CouronneCeleste", zone)
	U.cylindreVertical(sommetCouronne, 1.1, 8.5, { Material = Enum.Material.Marble, Color = MARBRE, Parent = couronne, Name = "Plateforme" })
	U.cylindreVertical(sommetCouronne + Vector3.new(0, -0.5, 0), 0.5, 9.2, {
		Material = Enum.Material.Neon, Color = P.VIOLET_NUIT, Transparency = 0.6, Parent = couronne, Name = "LisereCouronne", CastShadow = false,
	})
	for k = 0, 7 do
		if k <= 4 then -- l'anneau est brisé : il ne reste que l'arc supérieur
			local angle = math.rad(20 + k * 28)
			U.part{
				Size = Vector3.new(1.1, 4.2, 1.1),
				CFrame = CFrame.new(sommetCouronne + Vector3.new(math.cos(angle) * 6.2, 1.1 + math.sin(angle) * 6.2 + 4, 0))
					* CFrame.Angles(0, 0, angle),
				Material = Enum.Material.Marble, Color = MARBRE, Parent = couronne, Name = "SegmentAnneau_" .. k,
			}
		end
	end
	local lueurCouronne = U.ancre(CFrame.new(sommetCouronne + Vector3.new(0, 6, 0)), nil, couronne, "LueurCouronne")
	U.lumiere(lueurCouronne, P.VIOLET_NUIT, 26, 0.8)
	table.insert(M.poi, sommetCouronne + Vector3.new(0, 3.6, 2))
	table.insert(M.poi, sommetCouronne + Vector3.new(-2, 3.6, -2))

	local posPanneau = U.sol(A.RUINES.X - 20, A.RUINES.Y + 28)
	if posPanneau then U.panneau(posPanneau, "Ruines de l'Ordre Céleste", "Ils regardaient déjà les étoiles", zone) end
	print("🏛️  [7/9] Ruines célestes : temple brisé, autel gardé, 11 marches volantes, Couronne")
end

--------------------------------------------------------------------------------
-- SECTION 7 · CHEMINS & LIAISONS — pour que chaque zone en appelle une autre
--------------------------------------------------------------------------------
do
	local function chemin(depart, arrivee, poserLanternes)
		local distance = (arrivee - depart).Magnitude
		local n = math.floor(distance / 5.2)
		local direction = (arrivee - depart) / distance
		local perpendiculaire = Vector2.new(-direction.Y, direction.X)
		for i = 0, n do
			local t = i / n
			local serpente = math.sin(t * math.pi * 1.7) * distance * 0.06
			local pos2 = depart:Lerp(arrivee, t) + perpendiculaire * serpente
				+ Vector2.new(rng:NextNumber(-1.2, 1.2), rng:NextNumber(-1.2, 1.2))
			local posSol = U.sol(pos2.X, pos2.Y)
			if posSol then
				U.part{
					Size = Vector3.new(rng:NextNumber(2.6, 3.6), 0.5, rng:NextNumber(2.4, 3.2)),
					CFrame = CFrame.new(posSol + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
					Material = rng:NextNumber() > 0.35 and Enum.Material.Cobblestone or Enum.Material.Slate,
					Color = U.nuance(Color3.fromRGB(158, 148, 142), 0.05),
					Parent = M.dChemins, Name = "Dalle",
				}
			end
			-- lanternes espacées le long des grands axes
			if poserLanternes and (i == math.floor(n * 0.33) or i == math.floor(n * 0.66)) then
				local posLanterne = U.sol(pos2.X + perpendiculaire.X * 3.4, pos2.Y + perpendiculaire.Y * 3.4)
				if posLanterne and M.lanternesRestantes > 0 then
					U.lanterne(posLanterne)
					M.lanternesRestantes = M.lanternesRestantes - 1
				end
			end
		end
	end

	M.lanternesRestantes = math.floor(CONFIG.DENSITE.LANTERNES * DENS)
	-- la grande boucle : spawn → village → ruines → bosquet → lagon → spawn
	chemin(A.SPAWN, A.VILLAGE, true)
	chemin(A.VILLAGE, A.RUINES, true)
	chemin(A.RUINES, A.BOSQUET, true)
	chemin(A.BOSQUET, A.LAGON, true)
	chemin(A.LAGON, A.SPAWN, true)
	-- raccourci central : spawn → bosquet (l'arbre appelle, on y va tout droit)
	chemin(A.SPAWN, A.BOSQUET, false)
	-- promenade vers le haut de la cascade
	chemin(A.LAGON, Vector2.new(-(R - 42), 44 * ECH), false)
	print("🛤️  [8/9] Chemins pavés : grande boucle, raccourci du bosquet, promenade de la cascade")
end

--------------------------------------------------------------------------------
-- SECTION 8 · DÉCOR PROCÉDURAL — arbres, rochers, flore, lucioles, brume, ciel
--------------------------------------------------------------------------------
do
	-- ▸ auraciers : les arbres de l'île (30 % sont en fleurs roses et perdent leurs pétales)
	local function auracier(posSol, echelle)
		local m = U.model("Auracier", M.dArbres)
		local BOIS = Color3.fromRGB(96, 68, 56)
		local fleuri = rng:NextNumber() < 0.3
		local teinteFeuillage = fleuri and U.nuance(P.ROSE_CORAIL, 0.05) or U.nuance(Color3.fromRGB(112, 150, 80), 0.06)
		local h = rng:NextNumber(9, 14) * echelle
		local sommet = posSol + Vector3.new(rng:NextNumber(-1.6, 1.6), h, rng:NextNumber(-1.6, 1.6))
		local coude = posSol:Lerp(sommet, 0.5) + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		U.tube(posSol - Vector3.new(0, 1, 0), coude, 0.95 * echelle, { Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "TroncBas", Rallonge = 0.5 })
		U.tube(coude, sommet, 0.62 * echelle, { Material = Enum.Material.Wood, Color = BOIS, Parent = m, Name = "TroncHaut", Rallonge = 0.5 })
		for k = 1, rng:NextInteger(3, 4) do
			local angle = rng:NextNumber(0, math.pi * 2)
			local rayonBoule = rng:NextNumber(3.2, 5.2) * echelle
			U.boule(sommet + Vector3.new(math.cos(angle) * rayonBoule * 0.55, rng:NextNumber(-1, 2.4) * echelle, math.sin(angle) * rayonBoule * 0.55),
				rayonBoule, { Material = Enum.Material.Grass, Color = U.nuance(teinteFeuillage, 0.03), Parent = m, Name = "Feuillage", CanCollide = false })
		end
		if fleuri then
			local coeur = U.ancre(CFrame.new(sommet), nil, m, "CoeurFleuri")
			U.particules(coeur, {
				Name = "Petales", Color = ColorSequence.new(P.ROSE_CORAIL, Color3.fromRGB(255, 208, 200)),
				Rate = 1.1, Size = NumberSequence.new(0.22), Lifetime = NumberRange.new(4, 7),
				Speed = NumberRange.new(0.6, 1.2), Direction = Enum.NormalId.Bottom,
				Spread = Vector2.new(60, 60), Acceleration = Vector3.new(1.1, 0, 0.4), LightEmission = 0.25,
			})
		end
	end

	local nArbres = math.floor(CONFIG.DENSITE.ARBRES * DENS)
	local essais = 0
	while #M.arbresPos < nArbres and essais < nArbres * 14 do
		essais = essais + 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber(0.04, 0.88)) * R
		local pos2 = Vector2.new(math.cos(angle) * distance, math.sin(angle) * distance)
		local libre = true
		for _, ancre in pairs(A) do
			if (pos2 - ancre).Magnitude < 32 then libre = false end
		end
		if libre then
			for _, autre in ipairs(M.arbresPos) do
				if (pos2 - autre).Magnitude < 13 then libre = false break end
			end
		end
		if libre then
			local posSol = U.sol(pos2.X, pos2.Y)
			if posSol then
				table.insert(M.arbresPos, pos2)
				auracier(posSol, rng:NextNumber(0.75, 1.35))
			end
		end
	end

	-- un auracier sur chaque îlot satellite : la vie s'accroche partout
	for _, coords in ipairs({ Vector2.new(-R - 190, -R - 30), Vector2.new(R + 120, R + 70) }) do
		local posSol = U.sol(coords.X, coords.Y)
		if posSol then auracier(posSol, 0.85) end
	end

	-- ▸ rochers : amas de blocs enfoncés dans la pente
	for i = 1, math.floor(CONFIG.DENSITE.ROCHERS * DENS) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber(0.05, 0.95)) * R
		local posSol = U.sol(math.cos(angle) * distance, math.sin(angle) * distance)
		if posSol then
			local m = U.model("Rocher", M.dRochers)
			local echelle = rng:NextNumber(0.7, 1.9)
			for k = 1, rng:NextInteger(2, 3) do
				U.part{
					Size = Vector3.new(rng:NextNumber(2.2, 4.2), rng:NextNumber(1.6, 3.2), rng:NextNumber(2, 4)) * echelle,
					CFrame = CFrame.new(posSol + Vector3.new(rng:NextNumber(-1.5, 1.5) * echelle, rng:NextNumber(0.1, 0.6), rng:NextNumber(-1.5, 1.5) * echelle))
						* CFrame.Angles(math.rad(rng:NextNumber(-24, 24)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-24, 24))),
					Material = rng:NextNumber() > 0.5 and Enum.Material.Rock or Enum.Material.Granite,
					Color = U.nuance(Color3.fromRGB(126, 114, 124), 0.05),
					Parent = m, Name = "Bloc",
				}
			end
		end
	end

	-- ▸ flore : parterres de fleurs le jour, champignons lumineux dans les recoins
	for i = 1, math.floor(CONFIG.DENSITE.FLORE * DENS) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber(0.03, 0.9)) * R
		local posSol = U.sol(math.cos(angle) * distance, math.sin(angle) * distance)
		if posSol then
			if rng:NextNumber() > 0.32 then
				-- touffe de fleurs : petits cubes tournés à 45°, couleurs de la palette
				local teintes = { P.ROSE_CORAIL, P.OR_AMBRE, Color3.fromRGB(236, 232, 218) }
				for k = 1, rng:NextInteger(3, 6) do
					U.part{
						Size = Vector3.new(0.42, 0.42, 0.42),
						CFrame = CFrame.new(posSol + Vector3.new(rng:NextNumber(-1.6, 1.6), 0.35, rng:NextNumber(-1.6, 1.6)))
							* CFrame.Angles(math.rad(45), rng:NextNumber(0, math.pi), math.rad(45)),
						Material = Enum.Material.SmoothPlastic, Color = U.nuance(teintes[rng:NextInteger(1, #teintes)], 0.06),
						Parent = M.dFlore, Name = "Fleur", CanCollide = false, CastShadow = false,
					}
				end
			else
				-- champignons-lampions turquoise
				for k = 1, rng:NextInteger(2, 4) do
					local pied = posSol + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8))
					local hautPied = rng:NextNumber(0.7, 1.5)
					U.cylindreVertical(pied, hautPied, 0.16, {
						Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(222, 214, 198),
						Parent = M.dFlore, Name = "PiedChampignon", CanCollide = false, CastShadow = false,
					})
					local chapeau = U.boule(pied + Vector3.new(0, hautPied + 0.18, 0), rng:NextNumber(0.35, 0.6), {
						Material = Enum.Material.Neon, Color = U.nuance(P.TURQUOISE, 0.05),
						Parent = M.dFlore, Name = "ChapeauChampignon", CanCollide = false, CastShadow = false,
					})
					if k == 1 and rng:NextNumber() > 0.7 then U.lumiere(chapeau, P.TURQUOISE, 7, 0.35) end
				end
			end
		end
	end

	-- ▸ lucioles : nappes d'étincelles ambrées dans les zones vivantes
	local foyersLucioles = { A.BOSQUET, A.VILLAGE, A.LAGON, A.SPAWN, A.RUINES }
	for i = 1, math.floor(CONFIG.DENSITE.LUCIOLES * DENS) do
		local foyer = foyersLucioles[(i % #foyersLucioles) + 1]
		local pos2 = foyer + Vector2.new(rng:NextNumber(-22, 22), rng:NextNumber(-22, 22))
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol then
			local ancre = U.ancre(CFrame.new(posSol + Vector3.new(0, 3.4, 0)), Vector3.new(16, 5, 16), M.dEffets, "Lucioles")
			U.particules(ancre, {
				Name = "Lucioles", Color = ColorSequence.new(P.OR_AMBRE, Color3.fromRGB(255, 232, 160)),
				Rate = 2.6, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0.1) }),
				Lifetime = NumberRange.new(4, 8), Speed = NumberRange.new(0.3, 0.9),
				Acceleration = Vector3.new(rng:NextNumber(-0.3, 0.3), 0.05, rng:NextNumber(-0.3, 0.3)),
				LightEmission = 1,
			})
		end
	end

	-- ▸ brume au sol : le bord de l'île fume doucement dans le vide
	for i = 1, math.floor(CONFIG.DENSITE.BRUME * DENS) do
		local angle = (i / math.max(1, math.floor(CONFIG.DENSITE.BRUME * DENS))) * math.pi * 2
		local pos2 = Vector2.new(math.cos(angle), math.sin(angle)) * (R - 18)
		local posSol = U.sol(pos2.X, pos2.Y)
		if posSol then
			local ancre = U.ancre(CFrame.new(posSol + Vector3.new(0, 1, 0)), Vector3.new(20, 2, 20), M.dEffets, "Brume")
			U.particules(ancre, {
				Name = "BrumeDuBord", Texture = "rbxasset://textures/particles/smoke_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(212, 196, 226)), Rate = 1.6,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 9.5) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.88), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(0.4, 1),
				Spread = Vector2.new(30, 30), LightEmission = 0.15,
			})
		end
	end

	-- ▸ le ciel raconte aussi l'histoire : voiles d'aurore et silhouettes lointaines
	for i, def in ipairs({
		{ y = 330, z = -860, teinte = P.VIOLET_NUIT, transparence = 0.9 },
		{ y = 395, z = -910, teinte = P.TURQUOISE, transparence = 0.93 },
		{ y = 452, z = -960, teinte = P.ROSE_CORAIL, transparence = 0.92 },
	}) do
		U.part{
			Size = Vector3.new(340, 70, 1.5),
			CFrame = CFrame.new(-120 + i * 60, def.y, def.z) * CFrame.Angles(math.rad(8), math.rad(-12 + i * 7), math.rad(-4 + i * 3)),
			Material = Enum.Material.Neon, Color = def.teinte, Transparency = def.transparence,
			CanCollide = false, CastShadow = false, Parent = M.dCiel, Name = "VoileDAurore_" .. i,
		}
	end
	for i = 1, 4 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(430, 640)
		U.part{
			Size = Vector3.new(rng:NextNumber(18, 34), rng:NextNumber(10, 22), rng:NextNumber(16, 30)),
			CFrame = CFrame.new(math.cos(angle) * distance, ALT + rng:NextNumber(-60, 50), math.sin(angle) * distance)
				* CFrame.Angles(rng:NextNumber(0, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(0, 0.4)),
			Material = Enum.Material.Rock, Color = Color3.fromRGB(96, 84, 104),
			CanCollide = false, Parent = M.dCiel, Name = "SilhouetteLointaine_" .. i,
		}
	end

	print("🌲 [9/9] Décor vivant : " .. #M.arbresPos .. " auraciers, rochers, flore, lucioles, brume, aurores")
end

--------------------------------------------------------------------------------
-- SECTION 9 · ZONES SECRÈTES — la Grotte de Lune et le Jardin d'Éther
--------------------------------------------------------------------------------
M.spotsSecrets = {}
if CONFIG.COLLECTIBLES.SECRETS then
	-- ▸ SECRET 1 · LA GROTTE DE LUNE (derrière la cascade)
	do
		local secret = U.model("Secret_GrotteDeLune", M.dSecrets)
		local cc = M.centreGrotte
		local bouche = M.boucheGrotte

		-- corniche taillée : l'escalier discret qui descend du haut de la cascade
		local departCorniche = U.sol(-(R - 40), 46 * ECH)
		if departCorniche then
			for i = 0, 9 do
				local t = i / 9
				local point = departCorniche:Lerp(bouche + Vector3.new(4, 0.6, 4), t)
				U.part{
					Size = Vector3.new(4.4, 0.7, 2.8),
					CFrame = CFrame.new(point) * CFrame.Angles(0, math.rad(-20 + t * 30), 0),
					Material = Enum.Material.Slate, Color = Color3.fromRGB(112, 104, 118),
					Parent = secret, Name = "Corniche_" .. i,
				}
			end
			-- de discrètes lucioles marquent le départ : le seul indice
			local indice = U.ancre(CFrame.new(departCorniche + Vector3.new(0, 2.4, 0)), Vector3.new(4, 3, 4), secret, "IndiceLucioles")
			U.particules(indice, {
				Color = ColorSequence.new(Color3.fromRGB(190, 230, 255)), Rate = 1.4,
				Size = NumberSequence.new(0.2), Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.3, 0.8),
				LightEmission = 1,
			})
		end
		-- palier devant la bouche du tunnel + marche intermédiaire depuis la corniche
		U.part{ Size = Vector3.new(7, 0.8, 6), CFrame = CFrame.new(bouche + Vector3.new(2, -6, 0)),
			Material = Enum.Material.Slate, Color = Color3.fromRGB(112, 104, 118), Parent = secret, Name = "PalierEntree" }
		U.part{ Size = Vector3.new(3.2, 0.8, 3.2), CFrame = CFrame.new(bouche + Vector3.new(4, -2.2, 5)),
			Material = Enum.Material.Slate, Color = Color3.fromRGB(112, 104, 118), Parent = secret, Name = "MarcheEntree" }

		-- l'intérieur : le Miroir de Lune et sa couronne de cristaux
		-- (le sol en ardoise de la chambre affleure à cc.Y - 1 environ)
		local solChambre = cc + Vector3.new(0, -1.2, 0)
		local miroir = U.cylindreVertical(solChambre + Vector3.new(0, 0.15, 0), 0.35, 5, {
			Material = Enum.Material.Glass, Color = Color3.fromRGB(214, 234, 255), Transparency = 0.15,
			Parent = secret, Name = "MiroirDeLune", CanCollide = false,
		})
		U.cylindreVertical(solChambre, 0.2, 5.5, {
			Material = Enum.Material.Neon, Color = Color3.fromRGB(188, 216, 255), Transparency = 0.5,
			Parent = secret, Name = "HaloDuMiroir", CanCollide = false, CastShadow = false,
		})
		U.lumiere(miroir, Color3.fromRGB(188, 216, 255), 30, 1.1)
		for i = 1, 6 do
			local angle = (i / 6) * math.pi * 2
			local teinte = i % 2 == 0 and P.TURQUOISE or P.VIOLET_NUIT
			U.cristal(solChambre + Vector3.new(math.cos(angle) * 8.5, 0, math.sin(angle) * 8.5),
				rng:NextNumber(2.6, 4.8), teinte, { Parent = secret, Scintille = i <= 2, Brillance = 0.5 })
		end
		-- cristaux suspendus au plafond, tête en bas
		for i = 1, 5 do
			local angle = rng:NextNumber(0, math.pi * 2)
			U.cristal(cc + Vector3.new(math.cos(angle) * rng:NextNumber(3, 8), 13.5, math.sin(angle) * rng:NextNumber(3, 8)),
				-rng:NextNumber(1.8, 3.4), P.TURQUOISE, { Parent = secret, Lumiere = false })
		end
		-- brume lunaire au ras du sol
		local brume = U.ancre(CFrame.new(solChambre + Vector3.new(0, 0.8, 0)), Vector3.new(14, 1.5, 14), secret, "BrumeLunaire")
		U.particules(brume, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(196, 214, 244)), Rate = 2,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.4), NumberSequenceKeypoint.new(1, 6.5) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0.3, 0.7), LightEmission = 0.2,
		})

		-- déclencheur de découverte + emplacements des éclats dorés
		local declencheur = U.ancre(CFrame.new(cc + Vector3.new(6, 0, 2)), Vector3.new(12, 10, 12), secret, "DeclencheurGrotte")
		declencheur:SetAttribute("NomSecret", "La Grotte de Lune")
		CollectionService:AddTag(declencheur, "IF_Secret")
		local sonSecret = Instance.new("Sound")
		sonSecret.Name = "SonSecret"
		sonSecret.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sonSecret.Volume = 0.7
		sonSecret.PlaybackSpeed = 0.62
		sonSecret.Parent = declencheur
		for i = 1, 4 do
			local angle = (i / 4) * math.pi * 2 + 0.4
			table.insert(M.spotsSecrets, {
				pos = solChambre + Vector3.new(math.cos(angle) * 5.4, 3, math.sin(angle) * 5.4),
				valeur = CONFIG.COLLECTIBLES.VALEUR_SECRET,
			})
		end
	end

	-- ▸ SECRET 2 · LE JARDIN D'ÉTHER (îlot volant, accessible par pierres de saut)
	do
		local secret = U.model("Secret_JardinDEther", M.dSecrets)
		local sommetJardin = U.sol(A.JARDIN.X, A.JARDIN.Y) or Vector3.new(A.JARDIN.X, M.jardinY + 10, A.JARDIN.Y)

		-- les pierres de saut partent cachées derrière les ruines
		local departSaut = U.sol(A.RUINES.X + 17, A.RUINES.Y - 30)
		if departSaut then
			-- un pan de mur effondré dissimule la première pierre
			U.part{ Size = Vector3.new(7, 4.4, 1.4),
				CFrame = CFrame.new(departSaut + Vector3.new(-3, 2, 3)) * CFrame.Angles(math.rad(-7), math.rad(24), 0),
				Material = Enum.Material.Marble, Color = Color3.fromRGB(206, 196, 188), Parent = secret, Name = "MurEffondre" }
			local indice = U.ancre(CFrame.new(departSaut + Vector3.new(0, 2.4, 0)), Vector3.new(4, 3, 4), secret, "IndiceLucioles")
			U.particules(indice, {
				Color = ColorSequence.new(Color3.fromRGB(190, 230, 255)), Rate = 1.4,
				Size = NumberSequence.new(0.2), Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.3, 0.8),
				LightEmission = 1,
			})
			local cible = sommetJardin + Vector3.new(0, 1, 0)
			for i = 1, 8 do
				local t = i / 9
				local pos = departSaut:Lerp(cible, t)
				U.part{
					Size = Vector3.new(rng:NextNumber(3.6, 4.6), 1.3, rng:NextNumber(3.4, 4.4)),
					CFrame = CFrame.new(pos + Vector3.new(math.sin(i * 2.1) * 3.5, 0, math.cos(i * 1.7) * 3.5))
						* CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-5, 5))),
					Material = Enum.Material.Rock, Color = Color3.fromRGB(110, 98, 114),
					Parent = secret, Name = "PierreDeSaut_" .. i,
				}
			end
		end

		-- le jardin lui-même : arche de marbre, auracier rose, couronne de fleurs
		U.part{ Size = Vector3.new(1.4, 7, 1.4), CFrame = CFrame.new(sommetJardin + Vector3.new(-4, 3.5, 0)),
			Material = Enum.Material.Marble, Color = Color3.fromRGB(222, 212, 202), Parent = secret, Name = "PilierJardin" }
		U.part{ Size = Vector3.new(1.4, 7, 1.4), CFrame = CFrame.new(sommetJardin + Vector3.new(4, 3.5, 0)),
			Material = Enum.Material.Marble, Color = Color3.fromRGB(222, 212, 202), Parent = secret, Name = "PilierJardin" }
		U.part{ Size = Vector3.new(10.4, 1.3, 1.7), CFrame = CFrame.new(sommetJardin + Vector3.new(0, 7.4, 0)),
			Material = Enum.Material.Marble, Color = Color3.fromRGB(222, 212, 202), Parent = secret, Name = "LinteauJardin" }
		for i = 1, 10 do
			local angle = (i / 10) * math.pi * 2
			U.part{
				Size = Vector3.new(0.42, 0.42, 0.42),
				CFrame = CFrame.new(sommetJardin + Vector3.new(math.cos(angle) * 7.5, 0.4, math.sin(angle) * 7.5))
					* CFrame.Angles(math.rad(45), angle, math.rad(45)),
				Material = Enum.Material.SmoothPlastic,
				Color = U.nuance(i % 2 == 0 and P.ROSE_CORAIL or P.OR_AMBRE, 0.05),
				Parent = secret, Name = "FleurDEther", CanCollide = false, CastShadow = false,
			}
		end

		-- le piédestal de l'Éclat Prismatique
		local piedestal = U.cylindreVertical(sommetJardin + Vector3.new(0, 0.2, 3), 1.6, 1.3, {
			Material = Enum.Material.Marble, Color = Color3.fromRGB(228, 218, 206), Parent = secret, Name = "Piedestal",
		})
		U.lumiere(piedestal, Color3.fromRGB(255, 244, 214), 22, 0.9)
		table.insert(M.spotsSecrets, {
			pos = piedestal.Position + Vector3.new(0, 3.6, 0),
			valeur = CONFIG.COLLECTIBLES.VALEUR_PRISME, prisme = true,
		})
		for i = 1, 4 do
			local angle = (i / 4) * math.pi * 2 + 0.6
			table.insert(M.spotsSecrets, {
				pos = sommetJardin + Vector3.new(math.cos(angle) * 5.5, 3, math.sin(angle) * 5.5),
				valeur = CONFIG.COLLECTIBLES.VALEUR_SECRET,
			})
		end

		local declencheur = U.ancre(CFrame.new(sommetJardin + Vector3.new(0, 4, 0)), Vector3.new(24, 10, 24), secret, "DeclencheurJardin")
		declencheur:SetAttribute("NomSecret", "Le Jardin d'Éther")
		CollectionService:AddTag(declencheur, "IF_Secret")
		local sonSecret = Instance.new("Sound")
		sonSecret.Name = "SonSecret"
		sonSecret.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		sonSecret.Volume = 0.7
		sonSecret.PlaybackSpeed = 0.62
		sonSecret.Parent = declencheur
	end
	print("🌙 Secrets scellés : la Grotte de Lune et le Jardin d'Éther attendent les curieux")
end

--------------------------------------------------------------------------------
-- SECTION 10 · LES ÉCLATS D'AURÉLINE — la boucle de collecte
--------------------------------------------------------------------------------
do
	local compteurEclats = 0

	-- fabrique un éclat : gemme + cœur + halo + particules + son + hitbox taguée
	local function eclat(pos, valeur, options)
		options = options or {}
		compteurEclats = compteurEclats + 1
		local m = U.model("Eclat_" .. compteurEclats, M.dCollecte)
		local echelle = options.Echelle or (valeur > 1 and 1.25 or 1)
		local teinte = options.Couleur or (valeur > 1 and P.OR_AMBRE or P.TURQUOISE)

		local gemme = U.part{
			Size = Vector3.new(1.1, 1.9, 1.1) * echelle,
			CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Material = Enum.Material.Glass, Color = teinte, Transparency = 0.15, Reflectance = 0.12,
			Parent = m, Name = "Gemme", CanCollide = false, CastShadow = false,
		}
		gemme:SetAttribute("TransparenceBase", 0.15)
		local coeur = U.part{
			Size = Vector3.new(0.55, 1.05, 0.55) * echelle,
			CFrame = gemme.CFrame,
			Material = Enum.Material.Neon, Color = teinte:Lerp(Color3.new(1, 1, 1), 0.5),
			Parent = m, Name = "Coeur", CanCollide = false, CastShadow = false,
		}
		coeur:SetAttribute("TransparenceBase", 0)
		U.lumiere(coeur, teinte, 11 * echelle, 0.75)

		local hitbox = U.part{
			Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8) * echelle,
			CFrame = CFrame.new(pos), Transparency = 1,
			CanCollide = false, CastShadow = false, Parent = m, Name = "Hitbox",
		}
		hitbox.CanQuery = false
		hitbox:SetAttribute("TransparenceBase", 1)
		m.PrimaryPart = hitbox

		U.particules(hitbox, {
			Name = "Scintillement", Color = ColorSequence.new(teinte),
			Rate = valeur > 1 and 2.4 or 1.1, Size = NumberSequence.new(0.22 * echelle),
			Lifetime = NumberRange.new(1.6, 3), Speed = NumberRange.new(0.3, 0.8),
		})
		U.particules(hitbox, {
			Name = "Explosion", Color = ColorSequence.new(teinte, Color3.new(1, 1, 1)),
			Rate = 0, Enabled = false, Size = NumberSequence.new(0.45 * echelle),
			Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(6, 11),
			Spread = Vector2.new(180, 180), LightEmission = 1,
		})
		local son = Instance.new("Sound")
		son.Name = "SonCollecte"
		son.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		son.Volume = 0.55
		son.PlaybackSpeed = valeur > 1 and 0.85 or 1.2
		son.Parent = hitbox

		m:SetAttribute("Valeur", valeur)
		m:SetAttribute("TempsRespawn", CONFIG.COLLECTIBLES.RESPAWN)
		CollectionService:AddTag(m, "IF_Collectible")
		return m
	end

	-- 1) les points d'intérêt accumulés pendant la construction (récompenses d'exploration)
	local aPoser = math.max(0, CONFIG.COLLECTIBLES.NOMBRE)
	for _, pos in ipairs(M.poi) do
		if aPoser <= 0 then break end
		eclat(pos, CONFIG.COLLECTIBLES.VALEUR)
		aPoser = aPoser - 1
	end

	-- 2) le reste est dispersé dans les zones, au sol, là où l'on flâne
	local quotas = {
		{ ancre = A.VILLAGE, rayon = 30, portion = 0.16 },
		{ ancre = A.BOSQUET, rayon = 40, portion = 0.20 },
		{ ancre = A.LAGON,   rayon = 40, portion = 0.14 },
		{ ancre = A.RUINES,  rayon = 30, portion = 0.14 },
		{ ancre = A.SPAWN,   rayon = 32, portion = 0.10 },
		{ ancre = Vector2.new(0, 60 * ECH), rayon = R * 0.7, portion = 0.26 }, -- le long des chemins et prairies
	}
	local resteInitial = aPoser
	for _, quota in ipairs(quotas) do
		local n = math.floor(resteInitial * quota.portion + 0.5)
		local essais = 0
		while n > 0 and aPoser > 0 and essais < 60 do
			essais = essais + 1
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = math.sqrt(rng:NextNumber(0.1, 1)) * quota.rayon
			local posSol = U.sol(quota.ancre.X + math.cos(angle) * distance, quota.ancre.Y + math.sin(angle) * distance)
			if posSol then
				eclat(posSol + Vector3.new(0, 3.2, 0), CONFIG.COLLECTIBLES.VALEUR)
				n = n - 1
				aPoser = aPoser - 1
			end
		end
	end

	-- 3) les trésors des zones secrètes
	for _, spot in ipairs(M.spotsSecrets) do
		eclat(spot.pos, spot.valeur, spot.prisme and {
			Echelle = 1.7, Couleur = Color3.fromRGB(255, 246, 222),
		} or nil)
	end

	M.totalEclats = compteurEclats
	print("💎 " .. compteurEclats .. " Éclats d'Auréline scellés (dont " .. #M.spotsSecrets .. " trésors secrets)")
end

--------------------------------------------------------------------------------
-- SECTION 11 · LE SCRIPT RUNTIME — installé dans ServerScriptService
--  (leaderstats, collecte, respawn, animations douces, découvertes secrètes)
--------------------------------------------------------------------------------
do
	local SOURCE_RUNTIME = [==[
--------------------------------------------------------------------------------
-- IF_Runtime · L'Île d'Auraciel — logique de jeu
-- Généré par le script de construction. Gère : leaderstats, collecte des
-- Éclats (son + particules + respawn), zones secrètes, et les animations
-- douces (rotation des éclats, flammes des lanternes, cœur de l'arbre,
-- rochers en orbite). Une seule boucle Heartbeat : léger, même sur mobile.
--------------------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- ▸ leaderstats : le compteur d'Éclats visible dans le classement
local function initJoueur(joueur)
	if joueur:FindFirstChild("leaderstats") then return end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local eclats = Instance.new("IntValue")
	eclats.Name = "Éclats"
	eclats.Value = 0
	eclats.Parent = stats
	stats.Parent = joueur
end
Players.PlayerAdded:Connect(initJoueur)
for _, joueur in ipairs(Players:GetPlayers()) do initJoueur(joueur) end

-- ▸ petite notification dorée en haut de l'écran
local function notifier(joueur, texte, couleur)
	local gui = Instance.new("ScreenGui")
	gui.Name = "IF_Notification"
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.7, 0, 0.065, 0)
	label.Position = UDim2.new(0.15, 0, 0.11, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = texte
	label.TextColor3 = couleur or Color3.fromRGB(255, 226, 168)
	label.TextStrokeColor3 = Color3.fromRGB(60, 40, 70)
	label.TextStrokeTransparency = 0.35
	label.Parent = gui
	local pg = joueur:FindFirstChild("PlayerGui")
	if pg then
		gui.Parent = pg
		task.delay(3.2, function() gui:Destroy() end)
	end
end

-- ▸ collecte des Éclats d'Auréline
local eclats = {}
for _, modele in ipairs(CollectionService:GetTagged("IF_Collectible")) do
	local hitbox = modele.PrimaryPart
	if hitbox then
		local info = {
			modele = modele,
			origine = modele:GetPivot(),
			vitesse = 0.9 + math.random() * 1.1,
			phase = math.random() * math.pi * 2,
			actif = true,
		}
		table.insert(eclats, info)
		local valeur = modele:GetAttribute("Valeur") or 1
		local tempsRespawn = modele:GetAttribute("TempsRespawn") or 25
		hitbox.Touched:Connect(function(morceau)
			if not info.actif then return end
			local joueur = Players:GetPlayerFromCharacter(morceau.Parent)
			if not joueur then return end
			info.actif = false
			local stats = joueur:FindFirstChild("leaderstats")
			local compteur = stats and stats:FindFirstChild("Éclats")
			if compteur then compteur.Value = compteur.Value + valeur end
			local son = hitbox:FindFirstChild("SonCollecte")
			if son then son:Play() end
			local explosion = hitbox:FindFirstChild("Explosion")
			if explosion then explosion:Emit(28) end
			for _, objet in ipairs(modele:GetDescendants()) do
				if objet:IsA("BasePart") and objet ~= hitbox then objet.Transparency = 1 end
				if objet:IsA("PointLight") then objet.Enabled = false end
				if objet:IsA("ParticleEmitter") and objet.Name ~= "Explosion" then objet.Enabled = false end
			end
			if valeur >= 20 then
				notifier(joueur, "✦ L'ÉCLAT PRISMATIQUE ! +" .. valeur .. " Éclats ✦", Color3.fromRGB(255, 248, 220))
			elseif valeur > 1 then
				notifier(joueur, "✦ Éclat rare ! +" .. valeur .. " Éclats ✦")
			end
			task.delay(tempsRespawn, function()
				for _, objet in ipairs(modele:GetDescendants()) do
					if objet:IsA("BasePart") and objet ~= hitbox then
						objet.Transparency = objet:GetAttribute("TransparenceBase") or 0
					end
					if objet:IsA("PointLight") then objet.Enabled = true end
					if objet:IsA("ParticleEmitter") and objet.Name ~= "Explosion" then objet.Enabled = true end
				end
				info.actif = true
			end)
		end)
	end
end

-- ▸ découverte des zones secrètes (une notification par joueur et par zone)
local decouvertes = {}
Players.PlayerRemoving:Connect(function(joueur) decouvertes[joueur] = nil end)
for _, declencheur in ipairs(CollectionService:GetTagged("IF_Secret")) do
	local nomSecret = declencheur:GetAttribute("NomSecret") or "Zone secrète"
	declencheur.Touched:Connect(function(morceau)
		local joueur = Players:GetPlayerFromCharacter(morceau.Parent)
		if not joueur then return end
		decouvertes[joueur] = decouvertes[joueur] or {}
		if decouvertes[joueur][nomSecret] then return end
		decouvertes[joueur][nomSecret] = true
		local son = declencheur:FindFirstChild("SonSecret")
		if son then son:Play() end
		notifier(joueur, "🌙 Zone secrète découverte : " .. nomSecret,
			Color3.fromRGB(190, 228, 255))
	end)
end

-- ▸ animations douces : une seule boucle pour tout
local lanternes = {}
for _, lumiere in ipairs(CollectionService:GetTagged("IF_Lanterne")) do
	table.insert(lanternes, lumiere)
end
local orbites = {}
for _, rocher in ipairs(CollectionService:GetTagged("IF_Orbite")) do
	table.insert(orbites, {
		part = rocher,
		centre = rocher:GetAttribute("Centre") or rocher.Position,
		rayon = rocher:GetAttribute("Rayon") or 15,
		vitesse = rocher:GetAttribute("Vitesse") or 0.2,
		phase = rocher:GetAttribute("Phase") or 0,
	})
end
local coeurArbre = CollectionService:GetTagged("IF_CoeurArbre")[1]
local haloArbre = CollectionService:GetTagged("IF_HaloArbre")[1]
local transparenceHalo = haloArbre and haloArbre.Transparency or 0.35

local temps = 0
RunService.Heartbeat:Connect(function(dt)
	temps = temps + dt
	for _, e in ipairs(eclats) do
		if e.actif then
			e.modele:PivotTo(
				e.origine
				* CFrame.Angles(0, temps * e.vitesse, 0)
				* CFrame.new(0, math.sin(temps * 1.7 + e.phase) * 0.45, 0)
			)
		end
	end
	for i, flamme in ipairs(lanternes) do
		flamme.Brightness = 1.15 + 0.18 * math.sin(temps * 2.6 + i * 1.7)
	end
	for _, o in ipairs(orbites) do
		local a = temps * o.vitesse + o.phase
		o.part.CFrame = CFrame.new(o.centre)
			* CFrame.Angles(0, a, 0)
			* CFrame.new(o.rayon, math.sin(temps * 0.6 + o.phase) * 2.4, 0)
			* CFrame.Angles(a * 0.9, a * 1.3, 0)
	end
	if coeurArbre then coeurArbre.Brightness = 1.6 + 0.5 * math.sin(temps * 1.15) end
	if haloArbre then haloArbre.Transparency = transparenceHalo + 0.12 * math.sin(temps * 1.15) end
end)

print("[Île d'Auraciel] Runtime actif — " .. #eclats .. " éclats, " .. #lanternes .. " lanternes, " .. #orbites .. " rochers en orbite.")
]==]

	local runtime = Instance.new("Script")
	runtime.Name = "IF_Runtime"
	runtime.Source = SOURCE_RUNTIME
	runtime.Parent = ServerScriptService
end

--------------------------------------------------------------------------------
-- SECTION 12 · RAPPORT FINAL & PLAN DE CAMÉRA
--------------------------------------------------------------------------------
do
	-- la caméra de l'éditeur se place sur le plus beau plan : depuis le spawn, vers l'arbre
	pcall(function()
		workspace.CurrentCamera.CFrame = CFrame.lookAt(
			M.posSpawn + M.cfSpawn.LookVector * -26 + Vector3.new(0, 12, 0),
			M.coeurArbre
		)
	end)

	local duree = math.floor((os.clock() - debutChrono) * 10 + 0.5) / 10
	print("──────────────────────────────────────────────────────")
	print("✦ L'ÎLE D'AURACIEL EST PRÊTE ✦   (" .. duree .. " s)")
	print("   · " .. M.nbParts .. " parts, " .. M.nbTerrains .. " opérations de terrain")
	print("   · " .. M.totalEclats .. " Éclats d'Auréline (dont " .. #M.spotsSecrets .. " trésors secrets)")
	print("   · 5 zones, 2 secrets, 1 arbre-cristal, 1 cascade dans le vide")
	print("   ▶ Appuie sur Play : leaderboard, collecte et animations démarrent.")
	print("   🔍 Indice : des lucioles bleutées marquent l'entrée des passages cachés…")
	print("──────────────────────────────────────────────────────")
end
