--[[
	Réglages du validateur.

	Deux types de valeurs ici :
	- PHYSIQUE : valeurs par défaut de Roblox, vérifiées dans la base de réflexion
	  rbx-dom embarquée dans Lune (Roblox 0.741) — voir pipeline/README.md.
	  Elles ne servent que si la place ne les redéfinit pas (StarterPlayer, Workspace).
	- SEUILS : choix internes de ce pipeline, PAS des règles officielles Roblox.
	  Ils sont volontairement prudents et doivent être ajustés avec les mesures
	  réelles (Developer Console / MicroProfiler sur un vrai téléphone).
]]

return {
	PHYSIQUE = {
		GRAVITE = 196.2, -- Workspace.Gravity par défaut
		VITESSE_MARCHE = 16, -- StarterPlayer.CharacterWalkSpeed par défaut
		JUMP_POWER = 50, -- StarterPlayer.CharacterJumpPower par défaut
		JUMP_HEIGHT = 7.2, -- StarterPlayer.CharacterJumpHeight par défaut
		USE_JUMP_POWER = true, -- StarterPlayer.CharacterUseJumpPower par défaut
	},

	-- Approximations du personnage (avatar R15 standard), choix internes.
	PERSONNAGE = {
		DEMI_LARGEUR = 1.0, -- tolérance au bord d'une plateforme (studs)
		HAUTEUR = 5.0, -- hauteur approximative pour toucher un objet en l'air
		MARGE_SAUT = 0.9, -- on ne compte que 90 % de la portée théorique d'un saut
	},

	-- Une pièce inclinée de moins de cet angle est considérée comme une rampe
	-- praticable à pied (la limite moteur par défaut, MaxSlopeAngle, est 89°,
	-- mais au-delà de ~50° la marche devient pénible en pratique).
	PENTE_RAMPE_MAX_DEG = 50,

	-- Noms d'attributs reconnus pour les pads de saut (Vector3 = vitesse donnée).
	ATTRIBUTS_PROPULSION = { "Vitesse", "LaunchVelocity" },

	-- Un objet est considéré comme collectible s'il a l'attribut Collectible = true
	-- ou s'il se trouve dans un dossier portant l'un de ces noms.
	DOSSIERS_COLLECTIBLES = { "Collectibles" },

	-- Dossiers dont les pièces peuvent être non ancrées volontairement.
	DOSSIERS_PHYSIQUE_AUTORISEE = { "Physique", "Physics", "Dynamique" },

	SEUILS = {
		PIECES_AVERTISSEMENT = 4000, -- nombre de BasePart au-delà duquel on alerte (mobile)
		LUMIERES_OMBRES_AVERTISSEMENT = 16, -- PointLight/SpotLight/SurfaceLight avec Shadows
		PARTICULES_PAR_SECONDE_AVERTISSEMENT = 600, -- somme des Rate de tous les ParticleEmitter
		COLLECTIBLES_MIN = 10, -- en dessous, la boucle d'exploration est jugée trop courte
	},
}
