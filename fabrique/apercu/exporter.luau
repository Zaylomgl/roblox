--[[
	Exporte la géométrie d'une place (.rbxl) en JSON pour l'aperçu en images.

	Usage : lune run fabrique/apercu/exporter build/<nom>.rbxl build/<nom>/scene.json
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local entree, sortie = process.args[1], process.args[2]
if not entree or not sortie then
	print("Usage : lune run fabrique/apercu/exporter <place.rbxl> <scene.json>")
	process.exit(2)
end

local game = roblox.deserializePlace(fs.readFile(entree))
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")

local function arrondi(x: number): number
	return math.floor(x * 1000 + 0.5) / 1000
end

local function rvb(c)
	return { arrondi(c.R), arrondi(c.G), arrondi(c.B) }
end

local pieces = {}
local reperes = { etapes = {} }
for _, objet in workspace:GetDescendants() do
	if objet:IsA("BasePart") and not objet:IsA("Terrain") then
		local position = objet.CFrame.Position
		if objet:IsA("SpawnLocation") then
			reperes.depart = { position.X, position.Y, position.Z }
		elseif objet.Name == "Arrivee" then
			reperes.arrivee = { position.X, position.Y, position.Z }
		elseif objet:GetAttribute("Numero") and objet.Parent and objet.Parent.Name == "Etapes" then
			reperes.etapes[objet:GetAttribute("Numero")] = { position.X, position.Y, position.Z }
		elseif objet:GetAttribute("Secret") == 1 then
			reperes.relique = { position.X, position.Y, position.Z }
		elseif objet:GetAttribute("Valeur") == 25 then
			reperes.coupe = { position.X, position.Y, position.Z }
		elseif objet:GetAttribute("Valeur") == 5 and not reperes.gemme then
			reperes.gemme = { position.X, position.Y, position.Z }
		end
		if objet.Transparency < 0.99 then
			local composantes = { objet.CFrame:GetComponents() }
			for i, v in composantes do
				composantes[i] = arrondi(v)
			end
			local forme = "Block"
			if objet.ClassName == "Part" then
				forme = objet.Shape.Name
			elseif objet.ClassName == "WedgePart" then
				forme = "Wedge"
			elseif objet.ClassName == "CornerWedgePart" then
				forme = "CornerWedge"
			end
			table.insert(pieces, {
				f = forme,
				s = { arrondi(objet.Size.X), arrondi(objet.Size.Y), arrondi(objet.Size.Z) },
				c = composantes,
				k = rvb(objet.Color),
				t = arrondi(objet.Transparency),
				m = objet.Material.Name,
				o = objet.CastShadow,
			})
		end
	end
end

local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
local carte = workspace:FindFirstChild("Parcours")
local scene = {
	titre = carte and carte:GetAttribute("Titre") or "",
	format = carte and carte:GetAttribute("Format") or "",
	pieces = pieces,
	reperes = reperes,
	lumiere = {
		heure = lighting.ClockTime,
		luminosite = lighting.Brightness,
		ambiance = rvb(lighting.Ambient),
		exterieur = rvb(lighting.OutdoorAmbient),
		brume = atmosphere and rvb(atmosphere.Color) or { 0.7, 0.8, 0.9 },
		declin = atmosphere and rvb(atmosphere.Decay) or { 0.5, 0.6, 0.7 },
		densite = atmosphere and atmosphere.Density or 0.3,
	},
}

local dossier = string.match(sortie, "^(.*)[/\\][^/\\]+$")
if dossier and not fs.isDir(dossier) then
	fs.writeDir(dossier)
end
fs.writeFile(sortie, serde.encode("json", scene))
print(`✔ {sortie} : {#pieces} pièces visibles`)
