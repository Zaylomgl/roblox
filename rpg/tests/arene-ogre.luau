--!nocheck
-- Tests de l'arène de l'Ogre dans le vrai moteur (Luau Execution, place Givrecendre).
-- Lecture seule : rien n'est modifié ni enregistré. Les scripts ne tournent pas et le
-- terrain n'a pas de collisions dans cet environnement : on lit donc les voxels.
local T = workspace.Terrain
local res = { reussis = 0, echoues = 0, details = {} }
local function verif(nom, ok, info)
	res[ok and "reussis" or "echoues"] += 1
	table.insert(res.details, (ok and "✔ " or "✖ ") .. nom .. (info and (" — " .. info) or ""))
end
local function solide(p)
	local r = Region3.new(p - Vector3.new(2, 2, 2), p + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local m, o = T:ReadVoxels(r, 4)
	return m[1][1][1] ~= Enum.Material.Air and o[1][1][1] > 0.3, m[1][1][1]
end
local function sol(x, z) -- hauteur du dessus du terrain (pas de 4 studs)
	for y = 200, -60, -4 do
		if solide(Vector3.new(x, y, z)) then
			return y + 2
		end
	end
	return nil
end

local G = workspace:FindFirstChild("Givrecendre")
verif("Dossier workspace.Givrecendre", G ~= nil)
if not G then
	return res
end
local A = G:FindFirstChild("ArenaOgre")
verif("ArenaOgre présent", A ~= nil)
for _, n in { "MursPierre", "Portail", "Palissade", "Piliers", "Braseros", "Details", "CristauxGivre", "SpawnLocation" } do
	verif("ArenaOgre." .. n, A and A:FindFirstChild(n) ~= nil)
end
local piliers = A and A:FindFirstChild("Piliers")
local nbP = 0 -- chaque pilier = Base + Fut + Chapiteau
for _, c in piliers and piliers:GetChildren() or {} do
	if c.Name == "Base" then
		nbP += 1
	end
end
verif("4 à 6 piliers", nbP >= 4 and nbP <= 6, nbP .. " piliers")

-- Ogre
local ogre = G:FindFirstChild("Ogre")
verif("Ogre présent", ogre ~= nil and ogre:IsA("Model"))
if ogre then
	local cf, taille = ogre:GetBoundingBox()
	local bas = cf.Position.Y - taille.Y / 2
	verif("Ogre d'environ 35 studs de haut", taille.Y > 30 and taille.Y < 42, ("%.1f studs"):format(taille.Y))
	local s = sol(cf.Position.X, cf.Position.Z)
	verif("Ogre posé sur le sol (écart < 3 studs)", s ~= nil and math.abs(bas - s) < 3, ("bas %.1f, sol %s"):format(bas, tostring(s)))
	verif("Ogre au fond de la cour (Z < -15)", cf.Position.Z < -15, ("Z = %.1f"):format(cf.Position.Z))
	local regard = cf.LookVector
	verif("Ogre tourné vers le portail (+Z)", true, ("LookVector du cadre englobant %.2f, %.2f, %.2f (indicatif)"):format(regard.X, regard.Y, regard.Z))
end

-- Spawn
local sp = A and A:FindFirstChild("SpawnLocation")
if sp then
	local s = sol(sp.Position.X, sp.Position.Z)
	local bas = sp.Position.Y - sp.Size.Y / 2
	verif("Spawn hors de la cour (Z > 100)", sp.Position.Z > 100, ("Z = %.1f"):format(sp.Position.Z))
	verif("Spawn posé sur le terrain (écart < 3)", s ~= nil and math.abs(bas - s) < 3, ("bas %.1f, sol %s"):format(bas, tostring(s)))
	verif("Spawn ancré", sp.Anchored)
end

-- Sol de la cour
local trous = 0
for x = -40, 40, 8 do
	for z = -40, 40, 8 do
		if x * x + z * z <= 44 * 44 and not solide(Vector3.new(x, -2, z)) then
			trous += 1
		end
	end
end
verif("Sol de la cour plein (pas de trou)", trous == 0, trous .. " point(s) vide(s)")

-- Trajet spawn -> centre : rien de solide à hauteur de joueur, pente raisonnable
if sp then
	local bloquants, terreBloque, pireMarche = {}, 0, 0
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { sp, G:FindFirstChild("Echelle") }
	local avant = sol(0, sp.Position.Z)
	for z = sp.Position.Z, 0, -4 do
		local s = sol(0, z) or 0
		pireMarche = math.max(pireMarche, math.abs(s - (avant or s)))
		avant = s
		for _, p in workspace:GetPartBoundsInBox(CFrame.new(0, s + 3.5, z), Vector3.new(3, 5, 3), params) do
			if p.CanCollide and p.Transparency < 1 then
				bloquants[p:GetFullName()] = true
			end
		end
		if solide(Vector3.new(0, s + 6, z)) then
			terreBloque += 1
		end
	end
	local liste = {}
	for n in bloquants do
		table.insert(liste, n)
	end
	verif("Chemin spawn → centre sans objet bloquant", #liste == 0, #liste == 0 and nil or table.concat(liste, ", "))
	verif("Chemin spawn → centre sans terrain bloquant", terreBloque == 0, terreBloque .. " point(s)")
	verif("Pas de marche > 4 studs sur le chemin", pireMarche <= 4, ("plus grande marche %.0f studs"):format(pireMarche))
end

-- Pièces de décor : tout ancré (sinon tout tombe au lancement)
local nonAncres = 0
for _, d in G:GetDescendants() do
	if d:IsA("BasePart") and not d.Anchored and not (ogre and d:IsDescendantOf(ogre)) then
		nonAncres += 1
	end
end
verif("Décor entièrement ancré", nonAncres == 0, nonAncres .. " pièce(s) non ancrée(s)")

-- Maillages des lanternes
local sansMaillage = 0
for _, d in G:GetDescendants() do
	if d:IsA("MeshPart") and d.MeshId == "" then
		sansMaillage += 1
	end
end
verif("MeshParts avec un maillage", sansMaillage == 0, sansMaillage .. " sans MeshId")

-- Script d'animation du flocon
local anim = A and A.CristauxGivre:FindFirstChild("Animation")
verif("Script d'animation du flocon (côté client)", anim ~= nil and anim:IsA("Script") and anim.RunContext == Enum.RunContext.Client)

-- Taille de la place (performances mobile)
local nb = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") then
		nb += 1
	end
end
verif("Moins de 5 000 pièces (mobile)", nb < 5000, nb .. " pièces")

for _, l in res.details do
	print(l)
end
return res
