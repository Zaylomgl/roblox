--[[
	Combat de Givrecendre, côté client : commandes (PC, manette, mobile),
	roulade, barres de vie / endurance / boss, messages.

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
-- Interface
--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "GivrecendreCombat"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = joueur:WaitForChild("PlayerGui")

local POLICE = Enum.Font.Garamond

local function barre(nom: string, position: UDim2, taille: UDim2, couleur: Color3)
	local fond = Instance.new("Frame")
	fond.Name = nom
	fond.Position = position
	fond.Size = taille
	fond.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	fond.BackgroundTransparency = 0.25
	fond.BorderSizePixel = 0
	fond.Parent = gui
	local bord = Instance.new("UIStroke")
	bord.Color = Color3.fromRGB(120, 110, 95)
	bord.Thickness = 1
	bord.Parent = fond
	local plein = Instance.new("Frame")
	plein.Name = "Plein"
	plein.Size = UDim2.fromScale(1, 1)
	plein.BackgroundColor3 = couleur
	plein.BorderSizePixel = 0
	plein.Parent = fond
	return fond, plein
end

local _, barreVie = barre("Vie", UDim2.new(0, 24, 0, 24), UDim2.new(0, 300, 0, 14), Color3.fromRGB(150, 28, 24))
local _, barreEndurance =
	barre("Endurance", UDim2.new(0, 24, 0, 44), UDim2.new(0, 240, 0, 10), Color3.fromRGB(70, 130, 60))

local texteFioles = Instance.new("TextLabel")
texteFioles.Position = UDim2.new(0, 24, 0, 60)
texteFioles.Size = UDim2.new(0, 200, 0, 22)
texteFioles.BackgroundTransparency = 1
texteFioles.Font = POLICE
texteFioles.TextSize = 20
texteFioles.TextXAlignment = Enum.TextXAlignment.Left
texteFioles.TextColor3 = Color3.fromRGB(225, 205, 160)
texteFioles.TextStrokeTransparency = 0.4
texteFioles.Parent = gui

local cadreBoss, barreBoss = barre(
	"Boss",
	UDim2.new(0.5, -260, 1, -70),
	UDim2.new(0, 520, 0, 12),
	Color3.fromRGB(140, 24, 20)
)
local nomBoss = Instance.new("TextLabel")
nomBoss.Position = UDim2.new(0, 0, 0, -26)
nomBoss.Size = UDim2.new(1, 0, 0, 24)
nomBoss.BackgroundTransparency = 1
nomBoss.Font = POLICE
nomBoss.TextSize = 22
nomBoss.TextXAlignment = Enum.TextXAlignment.Left
nomBoss.TextColor3 = Color3.fromRGB(235, 225, 205)
nomBoss.TextStrokeTransparency = 0.3
nomBoss.Parent = cadreBoss
cadreBoss.Visible = false

local grandTexte = Instance.new("TextLabel")
grandTexte.AnchorPoint = Vector2.new(0.5, 0.5)
grandTexte.Position = UDim2.fromScale(0.5, 0.42)
grandTexte.Size = UDim2.new(1, 0, 0, 80)
grandTexte.BackgroundTransparency = 1
grandTexte.Font = POLICE
grandTexte.TextSize = 56
grandTexte.TextColor3 = Color3.fromRGB(230, 200, 120)
grandTexte.TextStrokeTransparency = 0.2
grandTexte.TextTransparency = 1
grandTexte.TextStrokeColor3 = Color3.new(0, 0, 0)
grandTexte.Parent = gui

local petitTexte = grandTexte:Clone()
petitTexte.Position = UDim2.fromScale(0.5, 0.5)
petitTexte.TextSize = 26
petitTexte.TextColor3 = Color3.fromRGB(225, 225, 225)
petitTexte.Parent = gui

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
	local t = os.clock()
	-- Le serveur fait foi : on recale la copie locale.
	local_.vie = e.vie
	local_.endurance = e.endurance
	local_.tEndurance = t
	local_.fioles = e.fioles
	barreVie.Size = UDim2.fromScale(math.clamp(e.vie / Regles.JOUEUR.vieMax, 0, 1), 1)
	barreEndurance.Size = UDim2.fromScale(math.clamp(e.endurance / Regles.JOUEUR.enduranceMax, 0, 1), 1)
	texteFioles.Text = ("Fioles : %d"):format(e.fioles)
	if e.boss then
		cadreBoss.Visible = true
		nomBoss.Text = e.boss.nom
		barreBoss.Size = UDim2.fromScale(math.clamp(e.boss.vie / e.boss.vieMax, 0, 1), 1)
	else
		cadreBoss.Visible = false
	end
end)

evMessage.OnClientEvent:Connect(function(type_: string, donnees: any)
	if type_ == "victoire" then
		annoncer("LE COL EST LIBÉRÉ", donnees .. " est tombé")
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

local function trace(fiche)
	-- Arc lumineux bref devant le joueur (en attendant les animations d'arme).
	local r = racine()
	if not r then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(235, 240, 255)
	p.Transparency = 0.4
	p.Size = Vector3.new(fiche.portee * 0.9, 0.2, 1.2)
	p.CFrame = r.CFrame * CFrame.new(0, 0.5, -fiche.portee * 0.45) * CFrame.Angles(0, 0, math.rad(-20))
	p.Parent = workspace
	task.delay(fiche.impact, function()
		TweenService:Create(p, TweenInfo.new(0.15), { Transparency = 1 }):Play()
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
		rouler(fiche)
	elseif action ~= "fiole" then
		trace(fiche)
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
end)
