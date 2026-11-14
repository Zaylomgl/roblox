--------------------------------------------------------------------------------
-- MOTEUR DE PARCOURS (formats « tour » et « evasion »)
--
-- Un TRACÉ donne, pour une distance `s` parcourue, la position du chemin, sa
-- direction et son côté extérieur. Les MODULES d'obstacles posent leurs
-- plateformes le long du tracé : le même module sert donc à la tour (tracé en
-- hélice) et à l'évasion (tracé sinueux).
--
-- Règle de conception : le chemin obligatoire n'utilise QUE des plateformes
-- fixes. Les pièges (barres, braises, tapis, dalles fragiles) ne font
-- qu'ajouter du danger. Le validateur du pipeline, qui ne voit que la
-- géométrie fixe, prouve donc bien que chaque étape est franchissable.
--------------------------------------------------------------------------------

local Y_DEPART = 40 -- altitude du sol de départ
local SAUT_MAX = 6.9 -- plus grand vide à franchir (studs, bord à bord) ; le validateur en accepte ≈ 8,3
local EP_DALLE = 0.6

local P = { etapes = {}, nbPlateformes = 0 }

--------------------------------------------------------------------------------
-- Tracés
--------------------------------------------------------------------------------

local TRACES = {}

-- Hélice autour d'une tour : un tour complet monte de `pasVertical` studs.
function TRACES.tour()
	local rayonTour = 20
	local rayon = rayonTour + 9
	local pente = 22 / (2 * math.pi * rayon)
	local socle = 1.5 -- le chemin démarre un peu au-dessus de l'île : on y monte en sautant (même vers une première marche haute)
	-- margeChute : tombé de cette hauteur sous sa dernière borne, le joueur y est ramené.
	local trace = { rayonTour = rayonTour, rayon = rayon, pente = pente, latBorne = 1.5, latMin = -2.5, latMax = 3.5, coteBonus = 1, margeChute = 14 }
	function trace.point(s)
		-- Sens horaire vu du dessus : ainsi l'axe X des repères pointe vers l'extérieur.
		local angle = -s / rayon
		local dehors = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local avant = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local hauteur = (s > 0) and (socle + pente * s) or 0
		return Vector3.new(0, Y_DEPART + hauteur, 0) + dehors * rayon, avant, dehors
	end
	return trace
end

-- Chemin sinueux vers +Z, avec de légères ondulations de hauteur.
function TRACES.evasion()
	local amplitude, periode = 12, 260
	local vague, periodeVague = 3, 300
	local trace = { latBorne = 0, latMin = -3, latMax = 3, coteBonus = 0, margeChute = 18 }
	function trace.point(s)
		local phase = 2 * math.pi * s / periode
		local x = (s > 0) and amplitude * math.sin(phase) or 0
		local derive = (s > 0) and amplitude * 2 * math.pi / periode * math.cos(phase) or 0
		local avant = Vector3.new(derive, 0, 1).Unit
		local dehors = Vector3.new(-avant.Z, 0, avant.X) -- = axe X du repère
		local y = Y_DEPART + ((s > 0) and vague * math.sin(2 * math.pi * s / periodeVague) or 0)
		return Vector3.new(x, y, s), avant, dehors
	end
	return trace
end

local trace = TRACES[FABRIQUE.format]()

-- Repère d'un point du chemin : `lat` studs vers l'extérieur, `dy` studs au-dessus.
function P.repere(s, lat, dy)
	local position, avant, dehors = trace.point(s)
	return K.repere(position + dehors * (lat or 0) + Vector3.new(0, dy or 0, 0), avant)
end

function P.borner(lat)
	return math.clamp(lat, trace.latMin, trace.latMax)
end

--------------------------------------------------------------------------------
-- Plateformes
--------------------------------------------------------------------------------

local EP_CORPS = 2.5 -- épaisseur du corps sculpté sous le plateau

-- Détail du thème tout en bas d'une plateforme : lueur, poutrelles ou stalactite.
local function dessous(cf, larg, long)
	local genre = THEME.dessous.genre
	local teinte = C[THEME.dessous.couleur] or C.structure
	local bas = cf * CFrame.new(0, -EP_DALLE - EP_CORPS, 0)
	if genre == "lueur" then
		K.deco({
			Size = Vector3.new(larg * 0.36, 0.3, long * 0.36),
			CFrame = bas * CFrame.new(0, -0.15, 0),
			Color = teinte,
			Material = Enum.Material[THEME.dessous.materiau or "Neon"],
			CastShadow = false,
			Name = "Lueur",
		})
	elseif genre == "poutre" then
		K.deco({ Size = Vector3.new(0.6, 0.7, long * 0.7), CFrame = bas * CFrame.new(0, 0.2, 0), Color = teinte, Material = Enum.Material.Metal, Name = "Poutre" })
		K.deco({ Size = Vector3.new(larg * 0.7, 0.5, 0.6), CFrame = bas * CFrame.new(0, 0.3, 0), Color = teinte, Material = Enum.Material.Metal, Name = "Traverse" })
	else -- "pointes" : une vraie pointe (stalactite, racine, coulure), taillée en pyramide
		local demi = math.min(larg, long) * 0.16
		K.pyramide(bas, demi, K.hasard(1.6, 3), {
			Color = K.nuance(teinte, 0.04),
			Material = Enum.Material[THEME.dessous.materiau or "SmoothPlastic"],
			Transparency = THEME.dessous.transparence or 0,
			Name = "Pointe",
		}, true)
	end
end

-- Dalle rectangulaire. `cf` : centre du DESSUS de la dalle. Renvoie la pièce où l'on marche.
-- Modelé : un plateau couleur d'accent dont on ne voit que le pourtour (il sert de
-- cadre, bien visible pour viser le saut), un dessus incrusté, un corps en deux
-- gradins qui se resserrent vers le bas, puis le détail du thème.
function P.dalle(cf, larg, long, options)
	options = options or {}
	P.nbPlateformes += 1
	local teinte = options.Color or K.nuance(C.sol, 0.03)
	local plateau = K.piece({
		Size = Vector3.new(larg, EP_DALLE, long),
		CFrame = cf * CFrame.new(0, -EP_DALLE / 2, 0),
		Color = options.nue and teinte or C.accent,
		Material = options.nue and (options.Material or MAT.sol) or MAT.structureAlt,
		Transparency = options.Transparency or 0,
		Parent = options.Parent or D.Structure,
		Name = options.Name or "Dalle",
	})
	if options.nue then
		return plateau
	end
	K.deco({
		Size = Vector3.new(larg - 0.8, 0.1, long - 0.8),
		CFrame = cf * CFrame.new(0, 0.03, 0),
		Color = teinte,
		Material = options.Material or MAT.sol,
		CastShadow = false,
		Name = "Dessus",
	})
	local gradins = { { 0.9, 1.2, C.structure, MAT.structure }, { 0.56, 1.3, C.structureAlt, MAT.structureAlt } }
	local y = -EP_DALLE
	for _, gradin in ipairs(gradins) do
		K.deco({
			Size = Vector3.new(larg * gradin[1], gradin[2], long * gradin[1]),
			CFrame = cf * CFrame.new(0, y - gradin[2] / 2, 0),
			Color = gradin[3],
			Material = gradin[4],
			Name = "Gradin",
		})
		y -= gradin[2]
	end
	-- Les pointes (quatre pièces chacune) ne garnissent qu'une plateforme sur deux : budget de pièces.
	if THEME.dessous.genre ~= "pointes" or P.nbPlateformes % 2 == 0 then
		dessous(cf, larg, long)
	end
	return plateau
end

-- Dalle posée sur le tracé. `s` : centre de la dalle.
function P.plateforme(s, lat, dy, long, larg, options)
	return P.dalle(P.repere(s, lat, dy), larg, long, options)
end

-- Plateforme ronde (pilier). Renvoie la pièce où l'on marche.
function P.pilier(s, lat, dy, diametre)
	P.nbPlateformes += 1
	local cf = P.repere(s, lat, dy)
	local dessus = K.cylindre(nil, EP_DALLE, diametre, {
		CFrame = cf * CFrame.new(0, -EP_DALLE / 2, 0),
		Color = K.nuance(C.solAlt, 0.03),
		Material = MAT.solAlt,
		Parent = D.Structure,
		Name = "Pilier",
	})
	local etages = { { 0.35, 1.08, C.accent, MAT.structureAlt }, { 4.6, 0.74, C.structure, MAT.structure }, { 0.5, 0.9, C.structureAlt, MAT.structureAlt }, { 3.4, 0.46, C.structureAlt, MAT.structureAlt } }
	local y = -EP_DALLE + 0.1
	for _, etage in ipairs(etages) do
		K.cylindre(nil, etage[1], diametre * etage[2], {
			CFrame = cf * CFrame.new(0, y - etage[1] / 2, 0),
			Color = etage[3],
			Material = etage[4],
			CanCollide = false,
			CanTouch = false,
			Name = "Fut",
		})
		y -= etage[1]
	end
	return dessus
end

-- Gemme flottant au-dessus d'une pièce où l'on marche.
function P.gemmeSur(piece, valeur)
	return K.gemme(piece.CFrame.Position + Vector3.new(0, piece.Size.Y / 2 + 3.4, 0), valeur or 1)
end

--------------------------------------------------------------------------------
-- Modules d'obstacles
-- module(s, d) : `s` = fin de la plateforme précédente, `d` = difficulté (0 → 1).
-- Renvoie le `s` de fin de sa dernière plateforme.
--
-- Retour de jeu sur la version 2 : « des cases partout, on pourrait presque tout
-- faire en marchant ». Les vides vont donc de 4,6 à 6,9 studs (au lieu de 3,4 à
-- 6,5), les dalles sont plus petites, et plus aucun module ne se traverse sans sauter.
--------------------------------------------------------------------------------

local function ecart(d, maxi)
	return math.min(maxi or SAUT_MAX, 4.6 + 2.2 * d + K.hasard(-0.25, 0.25))
end

local function largeur(d)
	return 6 - 2.5 * d
end

-- Lampe du thème posée au bord d'une longue plateforme.
function P.lampeBord(cf, larg, long)
	local cote = K.choisir({ -1, 1 })
	K.lampe((cf * CFrame.new(cote * (larg / 2 - 0.7), 0, cote * (long / 2 - 1.2))).Position)
end

local MODULES = {}

-- Dalles espacées, légèrement décalées d'un côté ou de l'autre.
function MODULES.dalles(s, d)
	local larg = largeur(d)
	local lat = 0
	for i = 1, 4 do
		local long = K.hasard(3.6, 4.6)
		s += ecart(d)
		lat = P.borner(lat + K.hasard(-1, 1) * math.min(1.8, larg - 2))
		local piece = P.plateforme(s + long / 2, lat, 0, long, larg)
		if i == 2 then
			P.gemmeSur(piece)
		end
		s += long
	end
	return s
end

-- Poutre étroite en deux tronçons décalés : il faut viser en sautant dessus.
function MODULES.poutre(s, d)
	local long = 6 + 2 * d
	local larg = 1.8 - 0.6 * d
	local lat = K.hasard(-1, 1)
	s += ecart(d, 5.5)
	local premier = P.plateforme(s + long / 2, lat, 0, long, larg, { Color = C.solAlt, Material = MAT.solAlt })
	P.gemmeSur(premier)
	s += long
	P.plateforme(s + long / 2, lat + K.choisir({ -1, 1 }) * (larg - 0.3), 0, long, larg, { Color = C.solAlt, Material = MAT.solAlt })
	return s + long
end

-- Piliers ronds en quinconce.
function MODULES.piliers(s, d)
	local diametre = 4 - 1.4 * d
	local decalage = 1.4 + 0.8 * d
	local lat = 0
	local nb = 5
	s += ecart(d, 6.2) + diametre / 2
	for i = 1, nb do
		local nouveau = (i == 1 or i == nb) and 0 or ((i % 2 == 0) and decalage or -decalage)
		if i > 1 then
			local vide = ecart(d, 6.2)
			local delta = nouveau - lat
			s += math.sqrt(math.max(1, (vide + diametre) ^ 2 - delta * delta))
		end
		lat = nouveau
		local piece = P.pilier(s, lat, 0, diametre)
		if i == 3 then
			P.gemmeSur(piece)
		end
	end
	return s + diametre / 2
end

-- Marches qui montent puis redescendent.
function MODULES.bosse(s, d)
	local larg = largeur(d)
	local long = 4
	local hauteurs = { 1.8, 3.6, 5, 2.6, 0 }
	for i, dy in ipairs(hauteurs) do
		s += ecart(d, 5.2)
		local piece = P.plateforme(s + long / 2, 0, dy, long, larg, { Color = K.melange(C.sol, C.solAlt, i / #hauteurs), Material = MAT.solAlt })
		if i == 3 then
			P.gemmeSur(piece)
		end
		s += long
	end
	return s
end

-- Petites dalles en zigzag : chaque saut part en diagonale.
function MODULES.zigzag(s, d)
	local cote = 3.4 - 0.6 * d
	local decalage = 2.3
	local lat = 0
	local sens = K.choisir({ -1, 1 })
	for i = 1, 5 do
		local nouveau = (i == 1) and 0 or sens * decalage
		local videLateral = math.max(0, math.abs(nouveau - lat) - cote)
		local vide = ecart(d, 6.2)
		s += math.sqrt(math.max(0.5, vide * vide - videLateral * videLateral))
		lat = nouveau
		sens = -sens
		local piece = P.plateforme(s + cote / 2, lat, 0, cote, cote)
		if i == 3 then
			P.gemmeSur(piece)
		end
		s += cote
	end
	return s
end

-- Plateforme balayée par des barres tournantes mortelles (à sauter).
function MODULES.lames(s, d)
	local long = 18
	local larg = math.max(largeur(d) + 1, 6.5)
	s += ecart(d, 5.5)
	local cf = P.repere(s + long / 2, 0, 0)
	local sol = P.dalle(cf, larg, long, { Color = C.solAlt, Material = MAT.solAlt })
	P.gemmeSur(sol)
	P.lampeBord(cf, larg, long)
	local positions = (d > 0.45) and { -4.5, 4.5 } or { 0 }
	for i, z in ipairs(positions) do
		K.cylindre(nil, 1.7, 1.5, {
			CFrame = cf * CFrame.new(0, 0.85, z),
			Color = C.structureAlt,
			Material = Enum.Material.Metal,
			Name = "Moyeu",
		})
		K.boule((cf * CFrame.new(0, 1.9, z)).Position, 1.1, { Color = C.danger, Material = Enum.Material.Metal, CanCollide = false, CanTouch = false, Name = "Coiffe" })
		local barre = K.piece({
			Size = Vector3.new(larg * 1.15, 1, 0.8),
			CFrame = cf * CFrame.new(0, 0.9, z),
			Color = C.danger,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = D.Dangers,
			Name = "Barre",
		})
		barre:SetAttribute("VitesseRotation", ((i % 2 == 0) and -1 or 1) * (1.1 + 1.1 * d))
	end
	return s + long
end

-- Plateforme coupée de bandes brûlantes (à sauter).
function MODULES.braises(s, d)
	local long = 18
	local larg = math.max(largeur(d), 5)
	s += ecart(d, 5.5)
	local cf = P.repere(s + long / 2, 0, 0)
	local sol = P.dalle(cf, larg, long)
	P.lampeBord(cf, larg, long)
	for i, z in ipairs({ -5, 0, 5 }) do
		local bande = K.piece({
			Size = Vector3.new(larg - 0.8, 0.5, 1.8 + 1.2 * d),
			CFrame = cf * CFrame.new(0, 0.15, z),
			Color = C.danger,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = D.Dangers,
			Name = "Braise",
		})
		if i == 2 then
			K.lumiere(bande, C.danger, 12, 1.2)
		end
	end
	K.gemme(sol.CFrame.Position + Vector3.new(0, 4.6, 0), 1) -- au-dessus de la bande centrale : à prendre en sautant
	return s + long
end

-- Dalles de verre : elles rougissent quand on marche dessus, puis s'effacent.
function MODULES.fragiles(s, d)
	local larg = largeur(d) + 0.5
	for i = 1, 4 do
		local long = 4.6
		s += ecart(d, 5.5)
		local cf = P.repere(s + long / 2, 0, 0)
		local piece = P.dalle(cf, larg, long, {
			Color = C.accent2,
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			Parent = D.Fragiles,
			Name = "Fragile",
			nue = true,
		})
		K.deco({
			Size = Vector3.new(larg + 0.4, 0.25, long + 0.4),
			CFrame = cf * CFrame.new(0, -EP_DALLE - 0.15, 0),
			Color = C.accent2,
			Material = MAT.structureAlt,
			Transparency = 0.2,
			CastShadow = false,
			Name = "Cadre",
		})
		if i == 3 then
			P.gemmeSur(piece)
		end
		s += long
	end
	return s
end

-- Tapis roulant qui pousse vers l'arrière.
function MODULES.tapis(s, d)
	local long = 18
	local larg = math.max(largeur(d), 5)
	s += ecart(d, 5.5)
	local cf = P.repere(s + long / 2, 0, 0)
	local tapis = P.dalle(cf, larg, long, { Color = C.noir, Material = Enum.Material.DiamondPlate, Parent = D.Tapis, Name = "Tapis" })
	local _, avant = trace.point(s + long / 2)
	tapis:SetAttribute("VitesseTapis", avant * -(5 + 5 * d))
	for z = -6, 6, 4 do
		for _, cote in ipairs({ -1, 1 }) do
			K.deco({
				Size = Vector3.new(larg * 0.36, 0.08, 0.45),
				CFrame = cf * CFrame.new(cote * larg * 0.14, 0.05, z) * CFrame.Angles(0, cote * math.rad(32), 0),
				Color = C.accent,
				Name = "Chevron",
			})
		end
	end
	P.gemmeSur(tapis)
	return s + long
end

-- Plateforme barrée de murets à enjamber.
function MODULES.murets(s, d)
	local long = 18
	local larg = math.max(largeur(d), 5.5)
	s += ecart(d, 5.5)
	local cf = P.repere(s + long / 2, 0, 0)
	local sol = P.dalle(cf, larg, long)
	P.lampeBord(cf, larg, long)
	local h = 2.2 + 1.6 * d
	for _, z in ipairs({ -5, 0, 5 }) do
		K.piece({
			Size = Vector3.new(larg, h, 1),
			CFrame = cf * CFrame.new(0, h / 2, z),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Parent = D.Structure,
			Name = "Muret",
		})
		K.deco({
			Size = Vector3.new(larg + 0.3, 0.3, 1.3),
			CFrame = cf * CFrame.new(0, h + 0.15, z),
			Color = C.accent,
			Material = MAT.structureAlt,
			Name = "Lisere",
		})
	end
	K.gemme(sol.CFrame.Position + Vector3.new(0, h + 3.6, 0), 1) -- au-dessus du muret central
	return s + long
end

local MODULES_CALMES = { "dalles", "poutre", "piliers", "bosse", "zigzag" }
local MODULES_PIEGES = { "lames", "braises", "fragiles", "tapis", "murets" }

--------------------------------------------------------------------------------
-- Bornes d'étape, arche, arrivée
--------------------------------------------------------------------------------

-- Arche en travers du chemin, avec un texte sur le linteau (des deux côtés).
function P.arche(cf, larg, texte)
	local hauteur = 8.5
	for _, cote in ipairs({ -1, 1 }) do
		local x = cote * (larg / 2 - 0.9)
		K.piece({ Size = Vector3.new(1.6, hauteur, 1.6), CFrame = cf * CFrame.new(x, hauteur / 2, 0), Color = C.structure, Material = MAT.structure, Name = "Montant" })
		K.deco({ Size = Vector3.new(2.1, 0.7, 2.1), CFrame = cf * CFrame.new(x, 0.35, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Base" })
		K.deco({ Size = Vector3.new(2, 0.5, 2), CFrame = cf * CFrame.new(x, hauteur - 1.4, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Chapiteau" })
		local bandeau = K.deco({ Size = Vector3.new(0.3, hauteur - 3, 0.3), CFrame = cf * CFrame.new(x - cote * 0.9, hauteur / 2 - 0.4, 0), Color = C.accent, Material = Enum.Material.Neon, CastShadow = false, Name = "Bandeau" })
		K.lumiere(bandeau, C.accent, 14, 1.2)
	end
	local linteau = K.piece({ Size = Vector3.new(larg + 1.4, 2.2, 1.8), CFrame = cf * CFrame.new(0, hauteur + 1.1, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Linteau" })
	K.deco({ Size = Vector3.new(larg + 2, 0.4, 2.3), CFrame = cf * CFrame.new(0, hauteur + 2.4, 0), Color = C.accent, Material = Enum.Material.Neon, CastShadow = false, Name = "Corniche" })
	K.texte(linteau, Enum.NormalId.Front, texte, C.accent2)
	K.texte(linteau, Enum.NormalId.Back, texte, C.accent2)
end

-- Borne d'étape : grande plateforme, arche numérotée, lampes, petit détour bonus.
function P.borne(s, numero, d)
	local long, larg = 12, 12
	s += ecart(d, 5)
	local milieu = s + long / 2
	local cf = P.repere(milieu, trace.latBorne, 0)
	P.dalle(cf, larg, long, { Color = C.solAlt, Material = MAT.solAlt, Name = "Palier" })
	K.deco({ -- disque lumineux au sol, sous l'arche
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 7, 7),
		CFrame = cf * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CastShadow = false,
		Name = "Halo",
	})
	P.arche(cf, larg, tostring(numero))

	local zone = K.piece({ -- zone de contact invisible : c'est elle qui valide l'étape
		Size = Vector3.new(larg - 3.4, 7, 3),
		CFrame = cf * CFrame.new(0, 3.5, 0),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = D.Etapes,
		Name = "Etape" .. numero,
	})
	zone:SetAttribute("Numero", numero)
	K.emetteur(zone, {
		Color = ColorSequence.new(C.accent, C.accent2),
		Size = NumberSequence.new(0.8, 0.1),
		Lifetime = NumberRange.new(0.6, 1.2),
		Rate = 0,
		Speed = NumberRange.new(8, 14),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Enabled = false,
	})
	local son = Instance.new("Sound")
	son.SoundId = SON_COLLECTE
	son.Volume = 0.28
	son.PlaybackSpeed = 1.35
	son.RollOffMaxDistance = 80
	son.Parent = zone

	-- Décor du palier : deux éléments du thème, aux coins de sortie.
	K.lampe((cf * CFrame.new(-(larg / 2 - 1.4), 0, -(long / 2 - 1.4))).Position)
	if numero % 2 == 0 then
		K.special((cf * CFrame.new(larg / 2 - 2.8, 0, long / 2 - 2.8)).Position)
	else
		K.cristaux((cf * CFrame.new(larg / 2 - 1.6, 0, long / 2 - 1.6)).Position, 3.2, C.accent2)
	end

	-- Détour bonus : deux petites dalles sur le côté, une gemme ×5 au bout.
	local cote = (trace.coteBonus ~= 0) and trace.coteBonus or K.choisir({ -1, 1 })
	local x = cote * (larg / 2)
	for i = 1, 2 do
		x += cote * (4.4 + 1.75)
		local dalle = P.dalle(cf * CFrame.new(x, 0.6 * i, 3), 3.5, 3.5, { Color = C.accent2, Material = MAT.solAlt })
		if i == 2 then
			P.gemmeSur(dalle, 5)
		end
		x += cote * 1.75
	end

	P.etapes[numero] = { s = milieu, cf = cf, larg = larg, long = long, cote = cote }
	return s + long
end

-- Cachette : une petite corniche sous un palier, côté détour bonus. On y descend
-- en se laissant tomber entre le palier et la première dalle bonus ; la relique
-- est sous le surplomb, presque invisible d'en haut.
function P.cachette(cf, larg, long, cote, numero)
	local corniche = cf * CFrame.new(cote * (larg / 2 + 0.6), -9, long / 2 - 2.2)
	P.dalle(corniche, 4.2, 4.2, { Color = C.structureAlt, Material = MAT.structureAlt, Name = "Corniche" })
	K.secret((corniche * CFrame.new(-cote * 0.9, 2.4, 0)).Position, numero)
end

-- Terrasse d'arrivée : trophée, zone de victoire, drapeaux.
function P.arrivee(s, numero)
	local long, larg = 26, 22
	s += 4
	local cf = P.repere(s + long / 2, trace.latBorne, 0)
	local sol = P.dalle(cf, larg, long, { Color = C.solAlt, Material = MAT.solAlt, Name = "Terrasse" })
	sol:SetAttribute("Arrivee", true)
	P.arche(cf * CFrame.new(0, 0, long / 2 - 2), larg, "🏁")

	-- Estrade ronde et trophée
	local estrade = cf * CFrame.new(0, 0, -3)
	K.cylindre(nil, 0.8, 11, { CFrame = estrade * CFrame.new(0, 0.4, 0), Color = C.structure, Material = MAT.structure, Parent = D.Structure, Name = "Estrade" })
	K.cylindre(nil, 0.3, 9.6, { CFrame = estrade * CFrame.new(0, 0.95, 0), Color = C.accent, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Anneau" })
	local socle = K.cylindre(nil, 2.2, 2.6, { CFrame = estrade * CFrame.new(0, 1.9, 0), Color = C.structureAlt, Material = MAT.structureAlt, Parent = D.Structure, Name = "Socle" })
	K.gemme(socle.CFrame.Position + Vector3.new(0, 1.1 + 2.6, 0), 25)

	local zone = K.piece({ -- zone de victoire invisible, sur l'estrade
		Size = Vector3.new(11, 7, 11),
		CFrame = estrade * CFrame.new(0, 4.3, 0),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = map,
		Name = "Arrivee",
	})
	zone:SetAttribute("Numero", numero)
	K.emetteur(zone, {
		Color = ColorSequence.new(C.accent, C.accent2),
		Size = NumberSequence.new(1, 0.2),
		Lifetime = NumberRange.new(1, 2),
		Rate = 0,
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Enabled = false,
	})
	K.etiquette(zone, "🏆", 6, C.accent2)

	-- Drapeaux et lampes aux quatre coins
	for _, coin in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local pied = cf * CFrame.new(coin[1] * (larg / 2 - 1.2), 0, coin[2] * (long / 2 - 1.2))
		K.deco({ Size = Vector3.new(0.4, 9, 0.4), CFrame = pied * CFrame.new(0, 4.5, 0), Color = C.structureAlt, Material = Enum.Material.Metal, Name = "Hampe" })
		K.deco({
			Size = Vector3.new(0.15, 2.2, 3.4),
			CFrame = pied * CFrame.new(0, 7.7, -1.9),
			Color = (coin[1] * coin[2] > 0) and C.accent or C.accent2,
			Material = Enum.Material.Fabric,
			Name = "Drapeau",
		})
	end
	K.lampe((cf * CFrame.new(-(larg / 2 - 3), 0, 0)).Position)
	K.lampe((cf * CFrame.new(larg / 2 - 3, 0, 0)).Position)

	P.fin = { s = s + long, cf = cf, hauteur = cf.Position.Y, larg = larg, long = long }
	return s + long
end

-- Ligne de départ : la franchir lance le chronomètre de la course.
function P.ligneDepart(cf, larg)
	return K.piece({
		Size = Vector3.new(larg - 3.6, 7, 2),
		CFrame = cf * CFrame.new(0, 3.5, 0),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = map,
		Name = "LigneDepart",
	})
end

--------------------------------------------------------------------------------
-- Construction du chemin complet
--------------------------------------------------------------------------------

function P.construireChemin()
	local nb = FABRIQUE.etapes
	local s = 6
	local precedent = nil
	for etape = 1, nb do
		local d = 0.05 + 0.85 * (etape - 1) / math.max(1, nb - 1)
		local choix = {}
		-- Première étape sans piège ; ensuite un piège par étape, deux à partir de la mi-parcours.
		-- Toujours deux modules de sauts purs ; un piège dès la 2e étape, deux en fin de parcours.
		local nbPieges = (etape == 1) and 0 or ((d > 0.6) and 2 or 1)
		local nbModules = 2 + math.max(1, nbPieges)
		local calmes, pieges = table.clone(MODULES_CALMES), table.clone(MODULES_PIEGES)
		for i = 1, nbModules do
			local reserve = (i > nbModules - nbPieges) and pieges or calmes
			local nom
			repeat
				nom = table.remove(reserve, rng:NextInteger(1, #reserve))
			until nom ~= precedent or #reserve == 0
			table.insert(choix, nom)
			precedent = nom
		end
		-- On mélange l'ordre (les pièges ne sont pas toujours en fin d'étape).
		for i = #choix, 2, -1 do
			local j = rng:NextInteger(1, i)
			choix[i], choix[j] = choix[j], choix[i]
		end
		precedent = choix[#choix]
		for _, nom in ipairs(choix) do
			s = MODULES[nom](s, d)
		end
		if etape < nb then
			s = P.borne(s, etape, d)
		else
			s = P.arrivee(s, nb)
		end
	end
	map:SetAttribute("NombreEtapes", nb)
	map:SetAttribute("MargeChute", trace.margeChute)

	-- Reliques secrètes : sous quatre paliers répartis le long du parcours, et sous l'arrivée.
	local nbBornes = nb - 1
	local nbCachettes = math.min(4, nbBornes)
	local dejaPrise = {}
	local numero = 0
	for k = 1, nbCachettes do
		local borne = math.clamp(math.floor(k * nbBornes / nbCachettes + 0.5), 1, nbBornes)
		if not dejaPrise[borne] then
			dejaPrise[borne] = true
			numero += 1
			local e = P.etapes[borne]
			P.cachette(e.cf, e.larg, e.long, e.cote, numero)
		end
	end
	numero += 1
	P.cachette(P.fin.cf, P.fin.larg, P.fin.long, (trace.coteBonus ~= 0) and trace.coteBonus or 1, numero)
	map:SetAttribute("NombreSecrets", numero)
	return s
end

--------------------------------------------------------------------------------
-- Vide mortel sous la map
--------------------------------------------------------------------------------

function P.vide(centre, taille)
	local V = THEME.vide
	-- Une pièce Roblox ne dépasse pas 2048 studs de côté : on pave en longueur si besoin.
	local nb = math.ceil(taille.Z / 1800)
	local longueur = taille.Z / nb
	for n = 1, nb do
		local milieu = centre + Vector3.new(0, 0, -taille.Z / 2 + (n - 0.5) * longueur)
		local dalle = Vector3.new(taille.X, taille.Y, longueur)
		K.piece({
			Size = dalle,
			Position = milieu,
			Color = K.rvb(V.couleur),
			Material = Enum.Material[V.materiau],
			Transparency = V.transparence,
			Reflectance = (V.genre == "eau") and 0.25 or 0,
			CanCollide = false,
			CastShadow = false,
			Parent = D.Dangers,
			Name = "Vide",
		})
		if V.genre == "eau" then
			K.deco({ Size = dalle, Position = milieu - Vector3.new(0, 6, 0), Color = K.melange(K.rvb(V.couleur), C.noir, 0.6), Name = "Fond" })
		end
	end
	workspace.FallenPartsDestroyHeight = centre.Y - 30
end

-- Brume qui monte du vide, autour d'un point.
function P.brume(position, teinte)
	local source = K.deco({ Size = Vector3.new(30, 1, 30), Position = position, Transparency = 1, CastShadow = false, Name = "Brume" })
	K.emetteur(source, {
		Texture = TEXTURE_FUMEE,
		Color = ColorSequence.new(teinte),
		Size = NumberSequence.new(9, 14),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(6, 9),
		Rate = 1.5,
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(30, 30),
	})
end

-- Point d'apparition (un seul : les étapes suivantes sont gérées par le script de jeu).
function P.spawn(cf)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Depart"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = cf * CFrame.new(0, 0.5, 0)
	spawn.Color = C.accent
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = map
	K.deco({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 13, 13),
		CFrame = cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.structureAlt,
		Material = MAT.structureAlt,
		Name = "Rosace",
	})
	return spawn
end
