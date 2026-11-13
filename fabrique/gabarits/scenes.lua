--------------------------------------------------------------------------------
-- SCÈNES : le décor propre à chaque format, construit autour du chemin
--------------------------------------------------------------------------------

-- Îlot flottant purement décoratif (sans collision : on ne peut pas s'y coincer).
function P.ilot(centre, rayon)
	K.cylindre(centre + Vector3.new(0, -1.2, 0), 2.4, rayon * 2, { Color = K.nuance(C.sol, 0.03), Material = MAT.sol, CanCollide = false, CanTouch = false, Name = "Ilot" })
	local y = -2.4
	for i, part in ipairs({ { 4, 1.6 }, { 5, 1 }, { 6, 0.45 } }) do
		K.cylindre(centre + Vector3.new(K.hasard(-0.6, 0.6), y - part[1] / 2, K.hasard(-0.6, 0.6)), part[1], rayon * part[2], {
			Color = K.nuance((i == 1) and C.structure or C.structureAlt, 0.04),
			Material = (i == 1) and MAT.structure or MAT.structureAlt,
			CanCollide = false,
			CanTouch = false,
			Name = "Roche",
		})
		y -= part[1] * 0.85
	end
	K.decorHasard(centre)
	if rayon > 8 then
		local a = K.hasard(0, 6.28)
		K.rocher(centre + Vector3.new(math.cos(a) * rayon * 0.6, 0, math.sin(a) * rayon * 0.6), 2.2)
	end
end

local SCENES = {}

--------------------------------------------------------------------------------
-- Tour : île de départ, tour centrale habillée, couronne lumineuse au sommet
--------------------------------------------------------------------------------

function SCENES.tour()
	local rayonTour = trace.rayonTour
	local sommet = P.fin.hauteur + 14
	local centre = Vector3.new(0, Y_DEPART, 0)

	-- Île de départ (on marche dessus) et sa roche en dessous
	K.cylindre(centre + Vector3.new(0, -4, 0), 8, 136, { Color = C.sol, Material = MAT.sol, Parent = D.Structure, Name = "Ile" })
	local y = -8
	for i, part in ipairs({ { 12, 116 }, { 14, 84 }, { 16, 50 }, { 14, 22 } }) do
		K.cylindre(centre + Vector3.new(0, y - part[1] / 2, 0), part[1], part[2], {
			Color = K.nuance((i % 2 == 1) and C.structure or C.structureAlt, 0.03),
			Material = (i % 2 == 1) and MAT.structure or MAT.structureAlt,
			CanCollide = false,
			CanTouch = false,
			Name = "Roche",
		})
		y -= part[1] * 0.9
	end

	-- Départ : rosace, arche, dalles qui mènent au premier obstacle
	local depart = P.repere(-14, 7, 0)
	local spawn = P.spawn(depart)
	P.arche(P.repere(1, 0, 0), 10, "▶")
	for i = 0, 3 do
		K.deco({
			Size = Vector3.new(5, 0.2, 2.4),
			CFrame = P.repere(-10 + i * 3.4, 6 - i * 1.6, 0.1),
			Color = C.solAlt,
			Material = MAT.solAlt,
			Name = "Pas",
		})
	end
	local enseigne = K.deco({ Size = Vector3.new(12, 3, 0.6), CFrame = depart * CFrame.new(0, 10.5, 9), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Enseigne" })
	K.texte(enseigne, Enum.NormalId.Front, FABRIQUE.titre, C.accent2)
	for _, cote in ipairs({ -5, 5 }) do
		K.deco({ Size = Vector3.new(0.6, 10, 0.6), CFrame = depart * CFrame.new(cote, 5, 9), Color = C.bois, Material = MAT.bois, Name = "Poteau" })
	end

	-- Corps de la tour : UN seul cylindre plein (aucun rebord ni palier caché où se
	-- tenir) ; les bandes de couleur sont des habillages sans collision.
	K.cylindre(Vector3.new(0, (sommet + Y_DEPART) / 2, 0), sommet - Y_DEPART, rayonTour * 2, { Color = C.structure, Material = MAT.structure, Name = "Tour" })
	local nbBandes = math.ceil((sommet - Y_DEPART) / 18)
	local hauteurBande = (sommet - Y_DEPART) / nbBandes
	for k = 1, nbBandes do
		local bas = Y_DEPART + (k - 1) * hauteurBande
		if k % 2 == 0 then
			K.cylindre(Vector3.new(0, bas + hauteurBande / 2, 0), hauteurBande, rayonTour * 2 + 0.3, {
				Color = K.melange(C.structure, C.structureAlt, 0.35),
				Material = MAT.structure,
				CanCollide = false,
				CanTouch = false,
				Name = "Bande",
			})
		end
		K.cylindre(Vector3.new(0, bas + 0.6, 0), 1.2, rayonTour * 2 + 1.6, { Color = C.structureAlt, Material = MAT.structureAlt, CanCollide = false, CanTouch = false, Name = "Ceinture" })
		K.cylindre(Vector3.new(0, bas + 1.4, 0), 0.3, rayonTour * 2 + 1, { Color = C.accent, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Filet" })
		for f = 1, 5 do
			local angle = k * 0.7 + f * (2 * math.pi / 5)
			local fenetre = K.deco({
				Size = Vector3.new(0.5, 3, 1.5),
				CFrame = CFrame.new(0, bas + hauteurBande * 0.55, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(rayonTour, 0, 0),
				Color = C.accent2,
				Material = Enum.Material.Neon,
				CastShadow = false,
				Name = "Fenetre",
			})
			K.deco({
				Size = Vector3.new(0.7, 0.4, 2.1),
				CFrame = fenetre.CFrame * CFrame.new(0, -1.7, 0),
				Color = C.structureAlt,
				Material = MAT.structureAlt,
				Name = "Appui",
			})
			if f == 1 then
				K.lumiere(fenetre, C.accent2, 18, 1)
			end
		end
	end
	for n = 1, 6 do -- contreforts sur toute la hauteur
		K.deco({
			Size = Vector3.new(1.4, sommet - Y_DEPART, 2),
			CFrame = CFrame.new(0, (sommet + Y_DEPART) / 2, 0) * CFrame.Angles(0, n * math.pi / 3, 0) * CFrame.new(rayonTour + 0.2, 0, 0),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Name = "Contrefort",
		})
	end

	-- Couronne : créneaux, anneau lumineux, grands cristaux visibles de partout
	K.cylindre(Vector3.new(0, sommet + 1, 0), 2, rayonTour * 2 + 5, { Color = C.structureAlt, Material = MAT.structureAlt, CanCollide = false, CanTouch = false, Name = "Couronne" })
	K.cylindre(Vector3.new(0, sommet + 2.2, 0), 0.4, rayonTour * 2 + 4, { Color = C.accent, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Anneau" })
	for n = 1, 10 do
		K.deco({
			Size = Vector3.new(3, 3.4, 4),
			CFrame = CFrame.new(0, sommet + 3.7, 0) * CFrame.Angles(0, n * math.pi / 5, 0) * CFrame.new(rayonTour + 0.8, 0, 0),
			Color = C.structure,
			Material = MAT.structure,
			Name = "Creneau",
		})
	end
	K.cristaux(Vector3.new(0, sommet + 2, 0), 22, C.accent)
	K.cristaux(Vector3.new(7, sommet + 2, 3), 12, C.accent2)
	K.cristaux(Vector3.new(-6, sommet + 2, -5), 10, C.accent2)

	-- Consoles qui relient chaque palier d'étape à la tour
	for _, etape in pairs(P.etapes) do
		K.deco({
			Size = Vector3.new(6.5, 1.2, 3.4),
			CFrame = etape.cf * CFrame.new(-8.4, -1.5, 0),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Name = "Console",
		})
		K.deco({
			Size = Vector3.new(1, 5, 2.4),
			CFrame = etape.cf * CFrame.new(-10.6, -3.6, 0) * CFrame.Angles(0, 0, math.rad(-32)),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Name = "Jambe",
		})
	end

	-- Décor de l'île : couronne d'arbres, lampes, rochers ; rien près du départ
	local semes = 0
	while semes < 30 do
		local angle, distance = K.hasard(0, 6.28), K.hasard(44, 62)
		local position = centre + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if (position - spawn.CFrame.Position).Magnitude > 16 then
			K.decorHasard(position)
			semes += 1
		end
	end
	for n = 1, 18 do
		local angle = n * (2 * math.pi / 18) + K.hasard(-0.1, 0.1)
		K.rocher(centre + Vector3.new(math.cos(angle) * 65, -0.6, math.sin(angle) * 65), K.hasard(2.4, 4.4))
	end

	-- Îlots flottants au loin, à différentes hauteurs
	for n = 1, 7 do
		local angle = n * 0.9 + K.hasard(-0.2, 0.2)
		local distance = K.hasard(96, 132)
		P.ilot(Vector3.new(math.cos(angle) * distance, Y_DEPART + K.hasard(-8, (sommet - Y_DEPART) * 0.8), math.sin(angle) * distance), K.hasard(7, 12))
	end

	local niveauVide = Y_DEPART - 62
	P.vide(Vector3.new(0, niveauVide, 0), Vector3.new(1800, 2, 1800))
	for n = 1, 4 do
		local angle = n * math.pi / 2
		P.brume(Vector3.new(math.cos(angle) * 90, niveauVide + 3, math.sin(angle) * 90), K.rvb(THEME.vide.couleur))
	end
end

--------------------------------------------------------------------------------
-- Évasion : cour de départ fortifiée, îlots et pitons le long du chemin, porte de sortie
--------------------------------------------------------------------------------

function SCENES.evasion(sFin)
	-- Cour de départ : sol jusqu'au premier obstacle, trois murs crénelés, grille au fond
	local cour = P.repere(-8, 0, 0)
	P.dalle(cour, 18, 28, { Color = C.solAlt, Material = MAT.solAlt, Name = "Cour" })
	P.spawn(P.repere(-13, 0, 0))
	local hauteurMur = 10
	local murs = {
		{ Vector3.new(18, hauteurMur, 1.4), CFrame.new(0, hauteurMur / 2, 13.3) }, -- fond
		{ Vector3.new(1.4, hauteurMur, 20), CFrame.new(-8.3, hauteurMur / 2, 4) },
		{ Vector3.new(1.4, hauteurMur, 20), CFrame.new(8.3, hauteurMur / 2, 4) },
		{ Vector3.new(4.5, hauteurMur, 1.4), CFrame.new(-6.75, hauteurMur / 2, -6) }, -- façade, de part et d'autre de la brèche
		{ Vector3.new(4.5, hauteurMur, 1.4), CFrame.new(6.75, hauteurMur / 2, -6) },
	}
	for _, mur in ipairs(murs) do
		K.piece({ Size = mur[1], CFrame = cour * mur[2], Color = K.nuance(C.structure, 0.03), Material = MAT.structure, Name = "Mur" })
		K.deco({
			Size = mur[1] * Vector3.new(1, 0, 1) + Vector3.new(0.5, 0.5, 0.5),
			CFrame = cour * mur[2] * CFrame.new(0, hauteurMur / 2 + 0.25, 0),
			Color = C.structureAlt,
			Material = MAT.structureAlt,
			Name = "Couronnement",
		})
		local longueur = math.max(mur[1].X, mur[1].Z)
		local selonX = mur[1].X >= mur[1].Z
		for n = 0, math.floor(longueur / 3.4) do
			local t = -longueur / 2 + 1 + n * 3.4
			if t <= longueur / 2 - 1 then
				K.deco({
					Size = Vector3.new(1.6, 1.4, 1.6),
					CFrame = cour * mur[2] * CFrame.new(selonX and t or 0, hauteurMur / 2 + 1.2, selonX and 0 or t),
					Color = C.structure,
					Material = MAT.structure,
					Name = "Creneau",
				})
			end
		end
	end
	-- Grille du fond et enseigne du jeu
	K.deco({ Size = Vector3.new(6, 5, 0.3), CFrame = cour * CFrame.new(0, 4.5, 12.5), Color = C.noir, Name = "Niche" })
	for n = -2, 2 do
		K.cylindre(nil, 5, 0.35, { CFrame = cour * CFrame.new(n * 1.2, 4.5, 12.2), Color = C.structureAlt, Material = Enum.Material.Metal, CanCollide = false, CanTouch = false, Name = "Barreau" })
	end
	local enseigne = K.deco({ Size = Vector3.new(13, 2.6, 0.5), CFrame = cour * CFrame.new(0, 8.4, 12.3), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Enseigne" })
	K.texte(enseigne, Enum.NormalId.Front, FABRIQUE.titre, C.accent2)
	K.lampe((cour * CFrame.new(-6.4, 0, 11)).Position)
	K.lampe((cour * CFrame.new(6.4, 0, 11)).Position)
	for n, caisse in ipairs({ { -6, 1.1, 2 }, { -6.2, 1, 4.4 }, { -5.8, 3, 2.6 }, { 6, 1.2, -2 } }) do
		K.deco({
			Size = Vector3.new(2.2, caisse[2] * 2, 2.2) * ((n == 3) and 0.8 or 1),
			CFrame = cour * CFrame.new(caisse[1], caisse[2], caisse[3]) * CFrame.Angles(0, K.hasard(-0.3, 0.3), 0),
			Color = K.nuance(C.bois, 0.04),
			Material = MAT.bois,
			Name = "Caisse",
		})
	end
	P.arche(P.repere(3.5, 0, 0), 10, "▶")

	-- Îlots de chaque côté du chemin, et grands pitons au loin
	local niveauVide = Y_DEPART - 30
	local s = 26
	while s < sFin do
		for _, cote in ipairs({ -1, 1 }) do
			local position = P.repere(s + K.hasard(-8, 8), cote * K.hasard(24, 38), K.hasard(-7, 9)).Position
			P.ilot(position, K.hasard(6, 10))
		end
		s += 44
	end
	s = 0
	local cote = 1
	while s < sFin + 60 do
		local pied = P.repere(s, cote * K.hasard(54, 84), 0).Position
		local hauteur = K.hasard(36, 72)
		local largeurPiton = K.hasard(10, 18)
		for n = 1, 3 do
			local h = hauteur * (1.1 - n * 0.25)
			K.deco({
				Size = Vector3.new(largeurPiton * (1.2 - n * 0.25), h, largeurPiton * (1.2 - n * 0.25)),
				CFrame = CFrame.new(pied.X + K.hasard(-3, 3), niveauVide + h / 2, pied.Z + K.hasard(-3, 3)) * CFrame.Angles(0, K.hasard(0, 1.5), 0),
				Color = K.nuance((n == 1) and C.structure or C.structureAlt, 0.04),
				Material = (n == 1) and MAT.structure or MAT.structureAlt,
				Name = "Piton",
			})
		end
		K.cristaux(Vector3.new(pied.X, niveauVide + hauteur * 0.85, pied.Z), K.hasard(5, 9), K.choisir({ C.accent, C.accent2 }))
		cote = -cote
		s += 58
	end

	-- Porte de sortie monumentale derrière la terrasse d'arrivée
	local sortie = P.fin.cf * CFrame.new(0, 0, -15)
	for _, x in ipairs({ -15, 15 }) do
		K.deco({ Size = Vector3.new(7, 34, 7), CFrame = sortie * CFrame.new(x, 6, 0), Color = C.structure, Material = MAT.structure, Name = "TourSortie" })
		K.deco({ Size = Vector3.new(8.4, 2, 8.4), CFrame = sortie * CFrame.new(x, 23.5, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Chemin" })
		local phare = K.boule((sortie * CFrame.new(x, 26.5, 0)).Position, 3.2, { Color = C.accent, Material = Enum.Material.Neon, CanCollide = false, CanTouch = false, CastShadow = false, Name = "Phare" })
		K.lumiere(phare, C.accent, 40, 2.2)
	end
	K.deco({ Size = Vector3.new(26, 4, 4), CFrame = sortie * CFrame.new(0, 18, 0), Color = C.structureAlt, Material = MAT.structureAlt, Name = "Passerelle" })
	K.deco({ Size = Vector3.new(22, 14, 0.6), CFrame = sortie * CFrame.new(0, 9, 0), Color = C.accent2, Material = Enum.Material.ForceField, CastShadow = false, Name = "Portail" })

	P.vide(Vector3.new(0, niveauVide, sFin / 2), Vector3.new(900, 2, sFin + 700))
	for z = 60, sFin, 220 do
		P.brume(Vector3.new(0, niveauVide + 3, z), K.rvb(THEME.vide.couleur))
	end
end

--------------------------------------------------------------------------------
-- Assemblage final
--------------------------------------------------------------------------------

K.ambiance()
local sFin = P.construireChemin()
SCENES[FABRIQUE.format](sFin)
map.Parent = workspace

local scriptJeu = Instance.new("Script")
scriptJeu.Name = "Parcours_Jeu"
scriptJeu.Source = SOURCE_JEU
scriptJeu.Parent = ServerScriptService

local nbPieces = 0
for _, objet in ipairs(map:GetDescendants()) do
	if objet:IsA("BasePart") then
		nbPieces += 1
	end
end
print("=====================================================")
print("✦ " .. FABRIQUE.titre .. " — construit par la Fabrique ✦")
print("• Format : " .. FABRIQUE.format .. " · thème : " .. THEME.nom .. " · graine : " .. FABRIQUE.graine)
print("• Étapes : " .. FABRIQUE.etapes .. " · plateformes : " .. P.nbPlateformes .. " · longueur : " .. math.floor(sFin) .. " studs")
print("• Pièces : " .. nbPieces .. " · gemmes : " .. #D.Collectibles:GetChildren())
print("• Script de jeu installé : ServerScriptService.Parcours_Jeu")
print("=====================================================")
