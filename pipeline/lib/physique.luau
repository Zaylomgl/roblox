--[[
	Physique du saut d'un personnage Roblox (modèle balistique simple).

	Hypothèses : vitesse verticale initiale constante, gravité constante, pas de
	frottement de l'air, vitesse horizontale = WalkSpeed pendant tout le saut
	(le contrôle en l'air de Roblox le permet). C'est une approximation : elle
	sert à repérer les zones impossibles à atteindre, pas à simuler au millimètre.
]]

local M = {}

export type Parametres = {
	gravite: number,
	vitesseMarche: number,
	vitesseSaut: number, -- vitesse verticale initiale (studs/s)
	hauteurSaut: number, -- hauteur max atteinte (studs)
}

--[[
	Construit les paramètres à partir des réglages du personnage.
	- UseJumpPower = true  : vitesse initiale = JumpPower
	- UseJumpPower = false : vitesse initiale = sqrt(2 * g * JumpHeight)
]]
function M.parametres(gravite: number, vitesseMarche: number, useJumpPower: boolean, jumpPower: number, jumpHeight: number): Parametres
	local v0 = if useJumpPower then jumpPower else math.sqrt(2 * gravite * jumpHeight)
	return {
		gravite = gravite,
		vitesseMarche = vitesseMarche,
		vitesseSaut = v0,
		hauteurSaut = (v0 * v0) / (2 * gravite),
	}
end

--[[
	Temps de vol pour atterrir à une hauteur `dh` au-dessus (dh > 0) ou en
	dessous (dh < 0) du point de départ, avec une vitesse verticale initiale v0.
	Renvoie nil si cette hauteur est inatteignable.
]]
function M.tempsDeVol(v0: number, gravite: number, dh: number): number?
	local discriminant = v0 * v0 - 2 * gravite * dh
	if discriminant < 0 then
		return nil
	end
	-- Racine « descendante » : on atterrit en redescendant.
	return (v0 + math.sqrt(discriminant)) / gravite
end

--[[
	Portée horizontale maximale d'un saut à pied pour atteindre une surface
	située `dh` studs plus haut (ou plus bas si négatif). nil = impossible.
]]
function M.porteeSaut(p: Parametres, dh: number): number?
	local t = M.tempsDeVol(p.vitesseSaut, p.gravite, dh)
	if not t then
		return nil
	end
	return p.vitesseMarche * t
end

return M
