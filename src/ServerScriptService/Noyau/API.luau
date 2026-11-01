--[[
	Point d'entrée du noyau pour les scripts de map / de jeu (côté serveur).

	Exemple, dans un script de map :
		local noyau = game:GetService("ServerScriptService"):FindFirstChild("Noyau")
		local API = noyau and require(noyau.API)
		if API then API.ajouterMonnaie(joueur, 5, "cristal") end

	Le script Principal branche les implémentations au démarrage. Tant qu'il
	ne l'a pas fait (ou si le profil du joueur n'est pas encore chargé), les
	fonctions renvoient false sans erreur.
]]

local API = {}

local implementation = nil

function API._brancher(impl)
	implementation = impl
end

-- Ajoute de la monnaie (multiplicateurs des passes appliqués). Renvoie le montant réellement gagné, ou false.
function API.ajouterMonnaie(joueur: Player, montant: number, raison: string?): number | false
	if not implementation then
		return false
	end
	return implementation.ajouterMonnaie(joueur, montant, raison)
end

-- Dépense de la monnaie. Renvoie true si le joueur avait assez.
function API.depenserMonnaie(joueur: Player, montant: number, raison: string?): boolean
	if not implementation then
		return false
	end
	return implementation.depenserMonnaie(joueur, montant, raison)
end

-- Table `jeu` du profil (progression propre au jeu, sauvegardée automatiquement), ou nil.
function API.donneesJeu(joueur: Player): { [any]: any }?
	if not implementation then
		return nil
	end
	return implementation.donneesJeu(joueur)
end

-- Le joueur possède-t-il ce pass ? (clé définie dans Configuration.PASSES)
function API.possedePass(joueur: Player, cle: string): boolean
	if not implementation then
		return false
	end
	return implementation.possedePass(joueur, cle)
end

return API
