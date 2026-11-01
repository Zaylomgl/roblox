--[[
	Environnement Roblox simulé pour Lune.

	Permet d'exécuter un script de construction de map (prévu pour la barre de
	commande de Roblox Studio) en dehors de Studio, sous Linux, afin de produire
	un vrai fichier .rbxl que le validateur peut analyser.

	Limites connues (documentées dans pipeline/README.md) :
	- `Random` est remplacé par un générateur déterministe maison : les détails
	  aléatoires (position exacte d'un arbre, d'une fleur…) diffèrent de ceux que
	  Roblox produirait avec la même graine. La structure de la map est identique.
	- `task.*` ne fait rien : le temps ne s'écoule pas pendant la construction.
	- Le Terrain voxel (FillBlock, WriteVoxels…) n'est pas simulé.
]]

local roblox = require("@lune/roblox")

local M = {}

-- Générateur pseudo-aléatoire déterministe (Park–Miller, « minimal standard »).
local RandomShim = {}
RandomShim.__index = RandomShim

function RandomShim.new(seed: number?)
	local s = math.floor(seed or os.time()) % 2147483646
	if s < 0 then
		s += 2147483646
	end
	return setmetatable({ _etat = s + 1 }, RandomShim)
end

function RandomShim:_suivant(): number
	self._etat = (self._etat * 48271) % 2147483647
	return (self._etat - 1) / 2147483646
end

function RandomShim:NextNumber(a: number?, b: number?): number
	local mini = a or 0
	local maxi = b or 1
	return mini + (maxi - mini) * self:_suivant()
end

function RandomShim:NextInteger(a: number, b: number): number
	return math.floor(a + (b - a + 1) * self:_suivant())
end

function RandomShim:NextUnitVector()
	local z = self:NextNumber(-1, 1)
	local angle = self:NextNumber(0, 2 * math.pi)
	local r = math.sqrt(1 - z * z)
	return roblox.Vector3.new(r * math.cos(angle), r * math.sin(angle), z)
end

M.Random = RandomShim

-- `task` neutralisé : pendant la construction, rien ne doit s'exécuter en différé.
local taskShim = {
	delay = function() end,
	defer = function() end,
	spawn = function() end,
	wait = function()
		return 0
	end,
	cancel = function() end,
}

--[[
	Crée un DataModel vierge (équivalent d'une place « Baseplate » vidée) et la
	table d'environnement globale à passer au script de construction.
]]
function M.creer(options: { silencieux: boolean? }?)
	local opts = options or {}
	local game = roblox.Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	-- Services qu'un script de map touche couramment.
	for _, nom in { "Lighting", "ServerScriptService", "ReplicatedStorage", "StarterPlayer", "SoundService" } do
		game:GetService(nom)
	end

	local journal = {}
	local function printCapture(...)
		local morceaux = table.pack(...)
		local texte = {}
		for i = 1, morceaux.n do
			texte[i] = tostring(morceaux[i])
		end
		local ligne = table.concat(texte, "\t")
		table.insert(journal, ligne)
		if not opts.silencieux then
			print("  [map] " .. ligne)
		end
	end

	-- selene: allow(global_usage)
	local globalesLune = _G
	local env = setmetatable({
		game = game,
		workspace = workspace,
		Workspace = workspace,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		Vector3int16 = roblox.Vector3int16,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		BrickColor = roblox.BrickColor,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Rect = roblox.Rect,
		Ray = roblox.Ray,
		Region3 = roblox.Region3,
		PhysicalProperties = roblox.PhysicalProperties,
		Font = roblox.Font,
		Faces = roblox.Faces,
		Axes = roblox.Axes,
		Enum = roblox.Enum,
		Random = RandomShim,
		task = taskShim,
		wait = taskShim.wait,
		tick = os.clock,
		time = os.clock,
		print = printCapture,
		warn = function(...)
			printCapture("[warn]", ...)
		end,
	}, { __index = globalesLune }) -- le reste (math, string, table…) vient de Lune

	return env, game, journal
end

--[[
	Corrections à appliquer avant l'enregistrement en .rbxl, pour contourner des
	limites de Lune (pas des erreurs de la map) :
	- Lune ne sait pas convertir toutes les valeurs de `Enum.Font` (ex. FredokaOne)
	  vers la propriété moderne `FontFace` ; on fait la conversion explicitement.
]]
function M.preparerPourEnregistrement(game)
	for _, objet in game:GetDescendants() do
		if objet:IsA("TextLabel") or objet:IsA("TextButton") or objet:IsA("TextBox") then
			local ok, police = pcall(function()
				return roblox.Font.fromEnum(objet.Font)
			end)
			if ok and police then
				objet.FontFace = police
			end
		end
	end
end

return M
