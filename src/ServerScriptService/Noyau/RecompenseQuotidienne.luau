--[[
	Récompense quotidienne avec série de jours consécutifs.

	Module PUR : le temps est passé en paramètre (os.time() côté serveur),
	ce qui permet de tester « demain », « dans 3 jours », etc.

	Les jours sont comptés en UTC (minuit UTC = nouveau jour), pour que tous
	les serveurs soient d'accord quelle que soit leur région.
]]

local RecompenseQuotidienne = {}

local SECONDES_PAR_JOUR = 86400

function RecompenseQuotidienne.jour(horodatage: number): number
	return math.floor(horodatage / SECONDES_PAR_JOUR)
end

--[[
	État pour l'affichage. `etat` = profil.recompense, `recompenses` = liste
	cyclique des gains (jour 1, jour 2, …).
	Renvoie { disponible, serieSiReclamee, gainSiReclamee, secondesAvantProchaine }.
]]
function RecompenseQuotidienne.etat(etat, maintenant: number, recompenses: { number })
	local aujourdhui = RecompenseQuotidienne.jour(maintenant)
	local disponible = aujourdhui > etat.dernierJour
	local serie
	if not disponible then
		serie = etat.serie
	elseif aujourdhui == etat.dernierJour + 1 then
		serie = etat.serie + 1 -- série continue
	else
		serie = 1 -- première fois, ou série cassée
	end
	local indice = ((serie - 1) % #recompenses) + 1
	return {
		disponible = disponible,
		serieSiReclamee = serie,
		gainSiReclamee = recompenses[indice],
		secondesAvantProchaine = if disponible then 0 else (aujourdhui + 1) * SECONDES_PAR_JOUR - maintenant,
	}
end

--[[
	Réclame la récompense du jour : modifie `etat` et renvoie le gain,
	ou nil si elle a déjà été réclamée aujourd'hui.
]]
function RecompenseQuotidienne.reclamer(etat, maintenant: number, recompenses: { number }): number?
	local e = RecompenseQuotidienne.etat(etat, maintenant, recompenses)
	if not e.disponible then
		return nil
	end
	etat.dernierJour = RecompenseQuotidienne.jour(maintenant)
	etat.serie = e.serieSiReclamee
	return e.gainSiReclamee
end

return RecompenseQuotidienne
