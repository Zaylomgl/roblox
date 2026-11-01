--[[
	Arène de l'Ogre — corrections de la Phase 3 (code exécuté dans Studio
	par Claude Desktop via le MCP, recopié par le propriétaire).

	ATTENTION : ce fichier ne reconstruit PAS l'arène entière. Il suppose que
	workspace.Givrecendre.ArenaOgre (palissade, piliers, braseros,
	CristauxGivre, flocon, SpawnLocation) existe déjà. Le code des Phases 1 à 3
	d'origine manque encore.

	Seule différence avec le code reçu : l'étape 3b, exécutée 3 fois à la main
	avec (Z1, Z2) = (-260, -104), (-100, 100), (104, 360), est ici une boucle.
	Pas encore testé hors Studio (non vérifié par ./pipeline/run.sh).
]]

-- ===== 1. Sol central : pavés + plaques de neige =====
local T = workspace.Terrain
T:FillCylinder(CFrame.new(0, -6, 0), 12, 47, Enum.Material.Cobblestone)
local rng = Random.new(77)
for _ = 1, 22 do
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(0, 40)
	local x, z = math.cos(a) * r, math.sin(a) * r
	if (Vector3.new(x, 0, z) - Vector3.new(0, 0, -30)).Magnitude > 14 then
		T:FillCylinder(CFrame.new(x, -0.6, z), 1.6, rng:NextNumber(3, 8), Enum.Material.Snow)
	end
end

-- ===== 2. Lumière du flocon (portée max d'une lumière = 60) =====
local root = workspace.Givrecendre.ArenaOgre.CristauxGivre
local oldLum = root:FindFirstChild("LumiereFlocon")
if oldLum then
	oldLum:Destroy()
end
local f = Instance.new("Folder")
f.Name = "LumiereFlocon"
f.Parent = root
local function lamp(name, pos, bright, range)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(1, 1, 1)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Position = pos
	p.Parent = f
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(190, 220, 255)
	l.Brightness = bright
	l.Range = range
	l.Shadows = false
	l.Parent = p
end
lamp("Centre", Vector3.new(0, 42, 0), 2.2, 60)
for i = 0, 2 do
	local a = math.rad(90 + i * 120)
	lamp("Relais" .. i, Vector3.new(math.cos(a) * 34, 34, math.sin(a) * 34), 1.4, 60)
end

-- ===== 3. Col v2 : relief =====
local M = Enum.Material
-- 3a : effacer l'ancien terrain extérieur
local function air(x1, x2, y1, y2, z1, z2)
	T:FillBlock(
		CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2),
		Vector3.new(x2 - x1, y2 - y1, z2 - z1),
		M.Air
	)
	task.wait()
end
air(-340, 340, -100, 220, -300, -104)
air(-340, 340, -100, 220, 104, 400)
air(-340, -104, -100, 220, -104, 104)
air(104, 340, -100, 220, -104, 104)

-- 3b : construction par colonnes de 4 studs
local function smooth(a, b, x)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
local function pcx(z)
	return 12 * math.sin((z - 150) / 60) * smooth(150, 230, z)
end
local function pathH(z)
	return -math.clamp(z - 108, 0, 230) * 30 / 210
end
local function H(x, z)
	local d = math.sqrt(x * x + z * z)
	local n = math.noise(x / 45, z / 45, 3) * 14 + math.noise(x / 17, z / 17, 9) * 4 + math.noise(x / 90, z / 90, 1) * 18
	local hm = math.clamp((d - 100) * 0.45, 0, 10) + math.clamp((d - 130) * 1.0, 0, 80) + n * math.clamp((d - 110) / 40, 0, 1)
	local side = math.max(0, math.abs(x - pcx(z)) - 24 - n * 0.5)
	local k = 0.2 + 1.3 * smooth(110, 210, z)
	local hc = pathH(z) + math.min(side * k, 85) + n * math.clamp(side / 20, 0, 1) * smooth(110, 190, z)
	local t = smooth(70, 140, z)
	local h = hm + (hc - hm) * t
	if z > 345 then
		h += (z - 345) * 1.5
	end
	return h
end
local function col(cx, cz)
	local d = math.sqrt(cx * cx + cz * cz)
	if d <= 100 then
		return
	end
	if math.abs(cx) <= 104 and math.abs(cz) <= 104 then
		T:FillBlock(CFrame.new(cx, 15, cz), Vector3.new(4, 90, 4), M.Air)
	end
	local h = H(cx, cz)
	local gx = (H(cx + 4, cz) - H(cx - 4, cz)) / 8
	local gz = (H(cx, cz + 4) - H(cx, cz - 4)) / 8
	local slope = math.sqrt(gx * gx + gz * gz)
	local onPath = cz > 85 and math.abs(cx - pcx(cz)) <= 24
	local k = math.noise(cx / 30, cz / 30, 5)
	local mat
	if onPath or slope < 0.5 then
		mat = M.Snow
	elseif slope < 0.9 then
		mat = (k > 0.05) and M.Glacier or M.Rock
	else
		mat = (k > 0.2) and M.Slate or M.Rock
	end
	T:FillBlock(CFrame.new(cx, (h - 4 - 80) / 2, cz), Vector3.new(4, h - 4 + 80, 4), M.Rock)
	T:FillBlock(CFrame.new(cx, h - 2, cz), Vector3.new(4, 4, 4), mat)
end
for _, bande in ipairs({ { -260, -104 }, { -100, 100 }, { 104, 360 } }) do
	for z = bande[1], bande[2], 4 do
		for x = -260, 260, 4 do
			col(x, z)
		end
		task.wait()
	end
end

-- 3c : effacer les restes de colonnes hautes de la 1re version
for z = -104, 104, 4 do
	for x = -104, 104, 4 do
		if math.sqrt(x * x + z * z) > 100 then
			T:FillBlock(CFrame.new(x, 82, z), Vector3.new(4, 55, 4), M.Air)
		end
	end
	task.wait()
end

-- ===== 4. Spawn, échelle, pins morts, rochers, brume =====
local G = workspace.Givrecendre
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { T }
local function ground(x, z)
	return workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), rp)
end
local sp = G.ArenaOgre.SpawnLocation
local r = ground(0, 122)
sp.Position = Vector3.new(0, r.Position.Y + sp.Size.Y / 2, 122)
local ech = G:FindFirstChild("Echelle")
local r2 = ground(9, 118)
if ech then
	ech.Position = Vector3.new(9, r2.Position.Y + ech.Size.Y / 2, 118)
end
local oldAl = G:FindFirstChild("Alentours")
if oldAl then
	oldAl:Destroy()
end
local F = Instance.new("Folder")
F.Name = "Alentours"
F.Parent = G
rng = Random.new(2024)
local function part(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
local BARK = Color3.fromRGB(58, 46, 40)
local function pine(pos, h)
	local m = Instance.new("Model")
	m.Name = "PinMort"
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, math.rad(rng:NextNumber(-5, 5)))
	local cyl = Enum.PartType.Cylinder
	local wood = Enum.Material.Wood
	part(m, "Tronc1", Vector3.new(h * 0.55, 2.2, 2.2), base * CFrame.new(0, h * 0.275 - 1, 0) * CFrame.Angles(0, 0, math.rad(90)), BARK, wood, cyl)
	part(m, "Tronc2", Vector3.new(h * 0.5, 1.2, 1.2), base * CFrame.new(0, h * 0.55 + h * 0.25 - 1, 0) * CFrame.Angles(0, 0, math.rad(90)), BARK, wood, cyl)
	local n = rng:NextInteger(7, 10)
	for i = 1, n do
		local fr = i / n
		local y = h * (0.3 + 0.65 * fr) - 1
		local len = (1 - fr * 0.6) * rng:NextNumber(5, 9)
		local a = rng:NextNumber(0, math.pi * 2)
		local tilt = math.rad(rng:NextNumber(25, 55))
		local bcf = base * CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(-tilt, 0, 0)
		part(m, "Branche", Vector3.new(0.55, 0.55, len), bcf * CFrame.new(0, 0, -len / 2), BARK, wood)
	end
	part(m, "Neige", Vector3.new(1.4, 5, 5), base * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(230, 238, 248), Enum.Material.Snow, cyl)
	m.Parent = F
end
local function tryPine(x, z)
	local hit = ground(x, z)
	if hit and hit.Normal.Y > 0.82 and (hit.Material == M.Snow or hit.Material == M.Glacier) then
		pine(hit.Position + Vector3.new(0, 0.3, 0), rng:NextNumber(16, 26))
	end
end
for z = 120, 330, 8 do
	local side = (rng:NextNumber() < 0.5) and -1 or 1
	tryPine(pcx(z) + side * rng:NextNumber(27, 42), z + rng:NextNumber(-4, 4))
	if rng:NextNumber() < 0.5 then
		tryPine(pcx(z) - side * rng:NextNumber(27, 42), z + rng:NextNumber(-4, 4))
	end
end
for a = 0, 359, 7 do
	local ang = math.rad(a)
	local rr = rng:NextNumber(104, 126)
	local x, z = math.cos(ang) * rr, math.sin(ang) * rr
	if not (z > 40 and math.abs(x) < 50) then
		tryPine(x, z)
	end
end
for _ = 1, 90 do
	local z = rng:NextNumber(-130, 320)
	local x
	if z > 125 then
		x = pcx(z) + rng:NextNumber(-34, 34)
	else
		x = rng:NextNumber(-135, 135)
	end
	local d = math.sqrt(x * x + z * z)
	if d > 98 and not (z > 85 and math.abs(x - pcx(z)) < 10) then
		local hit = ground(x, z)
		if hit and hit.Normal.Y > 0.75 then
			for _ = 1, rng:NextInteger(1, 3) do
				local rr = rng:NextNumber(2.5, 6)
				local p = hit.Position + Vector3.new(rng:NextNumber(-5, 5), rr * 0.35, rng:NextNumber(-5, 5))
				T:FillBall(p, rr, (rng:NextNumber() < 0.5) and M.Rock or M.Slate)
			end
		end
	end
end
local B = Instance.new("Folder")
B.Name = "BrumeCol"
B.Parent = F
local function mist(name, x, z, sx, sz, rate)
	local hit = ground(x, z)
	if not hit then
		return
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(sx, 1, sz)
	p.Position = Vector3.new(x, hit.Position.Y + 3, z)
	p.Parent = B
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(215, 228, 245))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.86),
		NumberSequenceKeypoint.new(0.7, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 16), NumberSequenceKeypoint.new(1, 30) })
	e.Lifetime = NumberRange.new(9, 14)
	e.Rate = rate
	e.Speed = NumberRange.new(0.4, 1.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.RotSpeed = NumberRange.new(-6, 6)
	e.LightEmission = 0.15
	e.LightInfluence = 0.5
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = p
end
for z = 130, 330, 50 do
	mist("Chemin" .. z, pcx(z), z, 40, 60, 3)
end
for a = 0, 330, 40 do
	local ang = math.rad(a)
	local x, z = math.cos(ang) * 112, math.sin(ang) * 112
	if not (z > 40 and math.abs(x) < 60) then
		mist("Fort" .. a, x, z, 50, 50, 3)
	end
end
game:GetService("Selection"):Set({})

-- ===== 5. Braseros devant le portail =====
for _, l in ipairs(workspace.Givrecendre.ArenaOgre.Braseros:GetDescendants()) do
	if l:IsA("PointLight") and l.Parent.Position.Z > 90 then
		l.Brightness = 1.0
		l.Range = 22
	end
end

-- ===== 6. CristauxGivre.Animation (Script, RunContext = Client) =====
local s = workspace.Givrecendre.ArenaOgre.CristauxGivre.Animation
s.Source = [==[
local RunService = game:GetService("RunService")
local root = script.Parent
local cristaux = root:WaitForChild("Cristaux")
local flake = root:WaitForChild("FloconCentral")
flake:WaitForChild("Coeur")

local list = {}
for _, m in ipairs(cristaux:GetChildren()) do
	table.insert(list, {m = m, base = m:GetPivot(), phase = m:GetAttribute("Phase") or 0})
end

local CENTRE = CFrame.new(0, 105, 0)
local parts = {}
for _, d in ipairs(flake:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(parts, {p = d, rel = CENTRE:Inverse() * d.CFrame})
	end
end

local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	for _, c in ipairs(list) do
		local bob = CFrame.new(0, math.sin(t * 1.3 + c.phase) * 0.8, 0)
		c.m:PivotTo(c.base * bob * CFrame.Angles(0, t * 0.9 + c.phase, 0))
	end
	local rot = CENTRE * CFrame.Angles(t * 0.18, t * 0.4, t * 0.11)
	for _, e in ipairs(parts) do
		e.p.CFrame = rot * e.rel
	end
end)
]==]
