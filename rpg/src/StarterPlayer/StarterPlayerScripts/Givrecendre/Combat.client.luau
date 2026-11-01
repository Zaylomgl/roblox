--[[
	Combat de Givrecendre, côté client : commandes (PC, manette, mobile),
	animations du chevalier, roulade, barres de vie / endurance / boss, messages.

	Le serveur fait autorité ; ce script garde une copie locale des règles
	pour ne pas envoyer d'actions impossibles et réagir sans attendre.

	Commandes :
		Attaque légère : clic gauche · R1 · bouton « Coup »
		Attaque lourde : F · R2 · bouton « Lourd »
		Roulade        : Q · B · bouton « Roulade »
		Fiole de soin  : R · X · bouton « Fiole »
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Partage = ReplicatedStorage:WaitForChild("Givrecendre")
local Regles = require(Partage:WaitForChild("Regles"))
local Reseau = Partage:WaitForChild("Reseau")
local evAction = Reseau:WaitForChild("Action") :: RemoteEvent
local evEtat = Reseau:WaitForChild("Etat") :: RemoteEvent
local evMessage = Reseau:WaitForChild("Message") :: RemoteEvent

local joueur = Players.LocalPlayer
local local_ = Regles.nouvelEtatJoueur(os.clock())

--------------------------------------------------------------------------------
-- Interface : barres façon « métal patiné », traînée qui montre les dégâts subis
--------------------------------------------------------------------------------

local OR = Color3.fromRGB(176, 150, 98)
local POLICE = Font.fromEnum(Enum.Font.Merriweather)
POLICE.Weight = Enum.FontWeight.Bold

local gui = Instance.new("ScreenGui")
gui.Name = "GivrecendreCombat"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = joueur:WaitForChild("PlayerGui")

-- Taille adaptée à l'écran (téléphone → grand écran).
local echelle = Instance.new("UIScale")
echelle.Parent = gui
local function adapter()
	local camera = workspace.CurrentCamera
	local h = camera and camera.ViewportSize.Y or 720
	echelle.Scale = math.clamp(h / 900, 0.6, 1.4)
end
adapter()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(adapter)
end

local function coins(objet: GuiObject, rayon: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, rayon)
	c.Parent = objet
end

local function degrade(objet: GuiObject, haut: Color3, bas: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(haut, bas)
	g.Rotation = 90
	g.Parent = objet
end

-- Crée une barre ; renvoie une fonction de mise à jour (valeur, max).
local function creerBarre(parent: Instance, nom: string, taille: UDim2, position: UDim2, haut: Color3, bas: Color3)
	local cadre = Instance.new("Frame")
	cadre.Name = nom
	cadre.Size = taille
	cadre.Position = position
	cadre.BackgroundColor3 = Color3.fromRGB(12, 11, 13)
	cadre.BackgroundTransparency = 0.15
	cadre.BorderSizePixel = 0
	cadre.Parent = parent
	coins(cadre, 3)
	local contour = Instance.new("UIStroke")
	contour.Color = OR
	contour.Thickness = 1.5
	contour.Transparency = 0.25
	contour.Parent = cadre

	local trainee = Instance.new("Frame")
	trainee.Name = "Trainee"
	trainee.Size = UDim2.fromScale(1, 1)
	trainee.BackgroundColor3 = Color3.fromRGB(220, 190, 120)
	trainee.BorderSizePixel = 0
	trainee.Parent = cadre
	coins(trainee, 3)

	local plein = Instance.new("Frame")
	plein.Name = "Plein"
	plein.Size = UDim2.fromScale(1, 1)
	plein.BackgroundColor3 = Color3.new(1, 1, 1)
	plein.BorderSizePixel = 0
	plein.Parent = cadre
	coins(plein, 3)
	degrade(plein, haut, bas)

	-- Reflet en haut de la barre.
	local reflet = Instance.new("Frame")
	reflet.Size = UDim2.new(1, 0, 0.35, 0)
	reflet.BackgroundColor3 = Color3.new(1, 1, 1)
	reflet.BackgroundTransparency = 0.85
	reflet.BorderSizePixel = 0
	reflet.Parent = plein
	coins(reflet, 3)

	local texte = Instance.new("TextLabel")
	texte.Size = UDim2.fromScale(1, 1)
	texte.BackgroundTransparency = 1
	texte.FontFace = POLICE
	texte.TextScaled = true
	texte.TextColor3 = Color3.fromRGB(240, 232, 215)
	texte.TextStrokeTransparency = 0.3
	texte.ZIndex = 3
	texte.Parent = cadre
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = 14
	limite.Parent = texte

	local precedent = 1
	return function(valeur: number, max: number, afficherNombre: boolean?)
		local f = math.clamp(valeur / max, 0, 1)
		plein.Size = UDim2.fromScale(f, 1)
		if f < precedent then
			-- La traînée dorée rattrape la barre après un court instant.
			TweenService:Create(
				trainee,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.35),
				{ Size = UDim2.fromScale(f, 1) }
			):Play()
		else
			trainee.Size = UDim2.fromScale(f, 1)
		end
		precedent = f
		texte.Text = afficherNombre and ("%d / %d"):format(math.ceil(valeur), max) or ""
	end,
		cadre
end

-- Bloc du joueur, en haut à gauche.
local blocJoueur = Instance.new("Frame")
blocJoueur.Name = "Joueur"
blocJoueur.Position = UDim2.new(0, 28, 0, 28)
blocJoueur.Size = UDim2.new(0, 360, 0, 80)
blocJoueur.BackgroundTransparency = 1
blocJoueur.Parent = gui

local majVie = creerBarre(
	blocJoueur,
	"Vie",
	UDim2.new(0, 340, 0, 20),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(196, 44, 36),
	Color3.fromRGB(110, 16, 14)
)
local majEndurance = creerBarre(
	blocJoueur,
	"Endurance",
	UDim2.new(0, 260, 0, 12),
	UDim2.new(0, 0, 0, 27),
	Color3.fromRGB(120, 176, 92),
	Color3.fromRGB(52, 98, 40)
)

-- Fioles : petites pastilles.
local fioles = {}
for i = 1, Regles.JOUEUR.fiole.nombre do
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 14, 0, 20)
	f.Position = UDim2.new(0, (i - 1) * 20, 0, 48)
	f.BackgroundColor3 = Color3.fromRGB(214, 120, 44)
	f.BorderSizePixel = 0
	f.Parent = blocJoueur
	coins(f, 5)
	local c = Instance.new("UIStroke")
	c.Color = OR
	c.Parent = f
	fioles[i] = f
end

-- Barre du boss, en bas au centre.
local blocBoss = Instance.new("Frame")
blocBoss.Name = "Boss"
blocBoss.AnchorPoint = Vector2.new(0.5, 1)
blocBoss.Position = UDim2.new(0.5, 0, 1, -48)
blocBoss.Size = UDim2.new(0, 640, 0, 46)
blocBoss.BackgroundTransparency = 1
blocBoss.Visible = false
blocBoss.Parent = gui

local nomBoss = Instance.new("TextLabel")
nomBoss.Size = UDim2.new(1, 0, 0, 24)
nomBoss.BackgroundTransparency = 1
nomBoss.FontFace = POLICE
nomBoss.TextSize = 22
nomBoss.TextXAlignment = Enum.TextXAlignment.Left
nomBoss.TextColor3 = Color3.fromRGB(236, 226, 204)
nomBoss.TextStrokeTransparency = 0.25
nomBoss.Parent = blocBoss

local majBoss = creerBarre(
	blocBoss,
	"Vie",
	UDim2.new(1, 0, 0, 16),
	UDim2.new(0, 0, 0, 28),
	Color3.fromRGB(170, 30, 24),
	Color3.fromRGB(86, 10, 8)
)

local function texteCentral(taille: number, y: number)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(1, 0, 0, taille + 20)
	l.BackgroundTransparency = 1
	l.FontFace = POLICE
	l.TextSize = taille
	l.TextColor3 = Color3.fromRGB(230, 200, 120)
	l.TextTransparency = 1
	l.TextStrokeTransparency = 1
	l.Parent = gui
	return l
end
local grandTexte = texteCentral(56, 0.42)
local petitTexte = texteCentral(26, 0.5)

local function annoncer(grand: string, petit: string?, couleur: Color3?)
	grandTexte.Text = grand
	grandTexte.TextColor3 = couleur or Color3.fromRGB(230, 200, 120)
	petitTexte.Text = petit or ""
	for _, l in { grandTexte, petitTexte } do
		l.TextTransparency = 0
		l.TextStrokeTransparency = 0.2
		TweenService:Create(l, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 3.5), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
	end
end

evEtat.OnClientEvent:Connect(function(e)
	-- Le serveur fait foi : on recale la copie locale.
	local_.vie = e.vie
	local_.endurance = e.endurance
	local_.tEndurance = os.clock()
	local_.fioles = e.fioles
	majVie(e.vie, Regles.JOUEUR.vieMax, true)
	majEndurance(e.endurance, Regles.JOUEUR.enduranceMax)
	for i, f in fioles do
		f.BackgroundTransparency = i <= e.fioles and 0 or 0.8
	end
	if e.boss then
		blocBoss.Visible = true
		nomBoss.Text = e.boss.nom
		majBoss(e.boss.vie, e.boss.vieMax)
	else
		blocBoss.Visible = false
	end
end)

evMessage.OnClientEvent:Connect(function(type_: string, donnees: any)
	if type_ == "victoire" then
		annoncer("LE COL EST LIBÉRÉ", tostring(donnees) .. " est tombé")
	elseif type_ == "rage" then
		annoncer("", "Grimmulf entre dans une rage folle !", Color3.fromRGB(200, 60, 40))
	elseif type_ == "recompense" and type(donnees) == "table" then
		local texte = ("+%d XP"):format(donnees.xp)
		if donnees.premiereFois then
			texte ..= ("  ·  +%d points de compétence  ·  +10 %% de dégâts  ·  XP ×2 pendant 1 h"):format(
				donnees.points
			)
		end
		task.delay(2, annoncer, "", texte)
	end
end)

--------------------------------------------------------------------------------
-- Animations procédurales du chevalier (épaule droite et bassin)
--------------------------------------------------------------------------------

-- Courbe d'une attaque : armer (lever l'épée), frapper (vers le bas), revenir.
local COURBES = {
	legere = { arme = 2.3, fin = 0.2 },
	lourde = { arme = 3.0, fin = -0.3 },
}
local animation: { type: string, debut: number, impact: number, duree: number }? = nil

local function lisse(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Angle d'épaule (radians, vers l'avant) à l'instant t de l'animation.
local function angleEpaule(a, t: number): number
	local c = COURBES[a.type]
	local u = t - a.debut
	local armer = a.impact * 0.7
	if u < armer then
		return c.arme * lisse(u / armer)
	elseif u < a.impact + 0.08 then
		return c.arme + (c.fin - c.arme) * lisse((u - armer) / (a.impact + 0.08 - armer))
	end
	return c.fin * (1 - lisse((u - a.impact - 0.08) / (a.duree - a.impact - 0.08)))
end

-- Les avatars R15 récents utilisent des AnimationConstraint (vérifié dans le moteur
-- le 01/11/2026), les anciens des Motor6D : les deux ont une propriété Transform.
local function articulable(j: Instance?): boolean
	return j ~= nil and (j:IsA("Motor6D") or j:IsA("AnimationConstraint"))
end

local function articulations()
	local perso = joueur.Character
	if not perso then
		return nil, nil, false
	end
	local brasR15 = perso:FindFirstChild("RightUpperArm")
	if brasR15 then
		local bassin = perso:FindFirstChild("LowerTorso")
		return brasR15:FindFirstChild("RightShoulder"), bassin and bassin:FindFirstChild("Root"), false
	end
	local torse = perso:FindFirstChild("Torso")
	local racine = perso:FindFirstChild("HumanoidRootPart")
	return torse and torse:FindFirstChild("Right Shoulder"), racine and racine:FindFirstChild("RootJoint"), true
end

RunService.PreSimulation:Connect(function()
	local a = animation
	if not a then
		return
	end
	local t = os.clock()
	if t >= a.debut + a.duree then
		animation = nil
		return
	end
	local epaule, bassin, r6 = articulations()
	if a.type == "roulade" then
		if articulable(bassin) then
			local tour = -2 * math.pi * lisse((t - a.debut) / a.duree)
			bassin.Transform = bassin.Transform * CFrame.new(0, -1, 0) * CFrame.Angles(tour, 0, 0)
		end
	elseif articulable(epaule) then
		local angle = angleEpaule(a, t)
		-- R15 : lever le bras vers l'avant = rotation autour de X ; R6 : autour de Z.
		epaule.Transform = epaule.Transform * (r6 and CFrame.Angles(0, 0, angle) or CFrame.Angles(angle, 0, 0))
	end
end)

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function racine(): BasePart?
	local perso = joueur.Character
	return perso and perso:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function rouler(fiche)
	local r = racine()
	local perso = joueur.Character
	local h = perso and perso:FindFirstChildOfClass("Humanoid")
	if not (r and h) then
		return
	end
	local dir = h.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = r.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local fin = os.clock() + fiche.duree
	local connexion
	connexion = RunService.Heartbeat:Connect(function()
		if os.clock() >= fin or not r.Parent then
			connexion:Disconnect()
			return
		end
		r.AssemblyLinearVelocity = dir * fiche.vitesse + Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
	end)
end

local function sillage(fiche)
	-- Sillage bref au moment de l'impact (lisibilité du coup).
	local r = racine()
	if not r then
		return
	end
	task.delay(fiche.impact * 0.85, function()
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(225, 232, 245)
		p.Transparency = 0.55
		p.Size = Vector3.new(0.15, fiche.portee * 0.7, 2.2)
		p.CFrame = r.CFrame * CFrame.new(0.8, 0.6, -fiche.portee * 0.35) * CFrame.Angles(math.rad(-70), 0, 0)
		p.Parent = workspace
		TweenService:Create(p, TweenInfo.new(0.18), { Transparency = 1 }):Play()
		task.delay(0.2, function()
			p:Destroy()
		end)
	end)
end

local function agir(action: string)
	local t = os.clock()
	if not Regles.peutAgir(local_, action, t) then
		return
	end
	local fiche = Regles.agir(local_, action, t)
	evAction:FireServer(action)
	if action == "roulade" then
		animation = { type = "roulade", debut = t, impact = 0, duree = fiche.duree }
		rouler(fiche)
	elseif action ~= "fiole" then
		animation = { type = action, debut = t, impact = fiche.impact, duree = fiche.recuperation }
		sillage(fiche)
	end
end

local function lier(action: string, titre: string, position: UDim2, ...)
	ContextActionService:BindAction("Givrecendre_" .. action, function(_, etat)
		if etat == Enum.UserInputState.Begin then
			agir(action)
		end
		return Enum.ContextActionResult.Pass
	end, true, ...)
	ContextActionService:SetTitle("Givrecendre_" .. action, titre)
	ContextActionService:SetPosition("Givrecendre_" .. action, position)
end

lier("legere", "Coup", UDim2.new(1, -95, 1, -170), Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR1)
lier("lourde", "Lourd", UDim2.new(1, -170, 1, -120), Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
lier("roulade", "Roulade", UDim2.new(1, -170, 1, -200), Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
lier("fiole", "Fiole", UDim2.new(1, -95, 1, -250), Enum.KeyCode.R, Enum.KeyCode.ButtonX)

joueur.CharacterAdded:Connect(function()
	local_ = Regles.nouvelEtatJoueur(os.clock())
	animation = nil
end)
