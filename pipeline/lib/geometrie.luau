--[[
	Géométrie : transforme les pièces d'une place en « surfaces marchables »
	(rectangles horizontaux à une certaine hauteur) et fournit une grille
	spatiale pour retrouver rapidement les surfaces proches.

	Approximations assumées (voir pipeline/README.md) :
	- chaque pièce est réduite à sa boîte englobante alignée sur les axes ;
	- les boules / cylindres couchés / pièces très inclinées ont une zone
	  marchable réduite autour du sommet ;
	- les murs ne bloquent pas les trajectoires (on peut surestimer l'accès,
	  jamais le sous-estimer à cause d'un mur).
]]

local M = {}

export type Surface = {
	id: number,
	objet: any,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	haut: number, -- hauteur du dessus (là où l'on se tient)
	bas: number, -- hauteur la plus basse où l'on peut monter dessus (rampes)
	rampe: boolean,
	propulsion: any?, -- Vector3 si c'est un pad de saut
	centreX: number,
	centreZ: number,
}

local function abs(x: number): number
	return if x < 0 then -x else x
end

-- Demi-dimensions de la boîte englobante alignée sur les axes du monde.
function M.demiEtendue(cf, taille)
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local sx, sy, sz = taille.X / 2, taille.Y / 2, taille.Z / 2
	local hx = abs(r.X) * sx + abs(u.X) * sy + abs(l.X) * sz
	local hy = abs(r.Y) * sx + abs(u.Y) * sy + abs(l.Y) * sz
	local hz = abs(r.Z) * sx + abs(u.Z) * sy + abs(l.Z) * sz
	return hx, hy, hz
end

-- Angle (degrés) entre la face la plus « horizontale » de la pièce et le sol.
function M.penteDeg(cf): number
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local c = math.max(abs(r.Y), abs(u.Y), abs(l.Y))
	return math.deg(math.acos(math.clamp(c, 0, 1)))
end

local function formeDe(objet): string
	if objet.ClassName == "WedgePart" or objet.ClassName == "CornerWedgePart" then
		return "Coin"
	end
	if objet.ClassName == "Part" then
		local ok, forme = pcall(function()
			return objet.Shape
		end)
		if ok and forme then
			return forme.Name -- Block, Ball, Cylinder, Wedge, CornerWedge
		end
	end
	return "Block"
end

--[[
	Construit la surface marchable d'une pièce. `penteRampeMax` en degrés.
	`propulsion` : Vector3 éventuel (pad de saut).
]]
function M.surfaceDe(objet, id: number, penteRampeMax: number, propulsion): Surface
	local cf, taille = objet.CFrame, objet.Size
	local hx, hy, hz = M.demiEtendue(cf, taille)
	local p = cf.Position
	local forme = formeDe(objet)
	local pente = M.penteDeg(cf)

	local reduction = 1.0
	local rampe = false
	local haut = p.Y + hy
	local bas = haut

	if forme == "Ball" then
		reduction = 0.5
	elseif forme == "Cylinder" then
		-- Cylindre Roblox : axe = RightVector. Debout => disque plat au sommet.
		if abs(cf.RightVector.Y) < 0.9 then
			reduction = 0.5
		end
	elseif forme == "Coin" or forme == "Wedge" or forme == "CornerWedge" then
		rampe = true
		bas = p.Y - hy
	end

	if forme ~= "Ball" and pente > 5 then
		if pente <= penteRampeMax then
			rampe = true
			bas = p.Y - hy
		else
			reduction = math.min(reduction, 0.3)
		end
	end

	return {
		id = id,
		objet = objet,
		minX = p.X - hx * reduction,
		maxX = p.X + hx * reduction,
		minZ = p.Z - hz * reduction,
		maxZ = p.Z + hz * reduction,
		haut = haut,
		bas = bas,
		rampe = rampe,
		propulsion = propulsion,
		centreX = p.X,
		centreZ = p.Z,
	}
end

-- Distance horizontale entre deux rectangles (0 s'ils se chevauchent).
function M.distanceRect(a: Surface, b: Surface): number
	local dx = math.max(0, a.minX - b.maxX, b.minX - a.maxX)
	local dz = math.max(0, a.minZ - b.maxZ, b.minZ - a.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

-- Distance horizontale entre un point (x, z) et un rectangle.
function M.distancePointRect(x: number, z: number, s: Surface): number
	local dx = math.max(0, s.minX - x, x - s.maxX)
	local dz = math.max(0, s.minZ - z, z - s.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

-- Distance horizontale entre un segment [(x1,z1),(x2,z2)] et un rectangle (approchée par échantillonnage).
function M.distanceSegmentRect(x1: number, z1: number, x2: number, z2: number, s: Surface): number
	local meilleur = math.huge
	local n = 16
	for i = 0, n do
		local t = i / n
		local d = M.distancePointRect(x1 + (x2 - x1) * t, z1 + (z2 - z1) * t, s)
		if d < meilleur then
			meilleur = d
		end
	end
	return meilleur
end

-- b est-il entièrement recouvert (en vue de dessus) par a ?
function M.estRecouvert(b: Surface, a: Surface, marge: number): boolean
	return b.minX >= a.minX - marge and b.maxX <= a.maxX + marge and b.minZ >= a.minZ - marge and b.maxZ <= a.maxZ + marge
end

-- Grille spatiale 2D (vue de dessus).
local Grille = {}
Grille.__index = Grille

function M.nouvelleGrille(tailleCellule: number)
	return setmetatable({ taille = tailleCellule, cellules = {} }, Grille)
end

function Grille:_cle(i: number, j: number): string
	return i .. "," .. j
end

function Grille:inserer(s: Surface)
	local t = self.taille
	for i = math.floor(s.minX / t), math.floor(s.maxX / t) do
		for j = math.floor(s.minZ / t), math.floor(s.maxZ / t) do
			local cle = self:_cle(i, j)
			local liste = self.cellules[cle]
			if not liste then
				liste = {}
				self.cellules[cle] = liste
			end
			table.insert(liste, s)
		end
	end
end

-- Surfaces dont le rectangle touche la zone [minX-r, maxX+r] x [minZ-r, maxZ+r].
function Grille:voisins(s: Surface, rayon: number): { Surface }
	local t = self.taille
	local vus = {}
	local resultat = {}
	for i = math.floor((s.minX - rayon) / t), math.floor((s.maxX + rayon) / t) do
		for j = math.floor((s.minZ - rayon) / t), math.floor((s.maxZ + rayon) / t) do
			local liste = self.cellules[self:_cle(i, j)]
			if liste then
				for _, autre in liste do
					if not vus[autre] then
						vus[autre] = true
						table.insert(resultat, autre)
					end
				end
			end
		end
	end
	return resultat
end

return M
