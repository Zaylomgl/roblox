--[[
	Configuration partagée serveur + client.

	Les identifiants des passes et produits valent 0 tant qu'ils n'ont pas été
	créés sur Roblox (Creator Hub ou API Open Cloud). Un objet à 0 n'est ni
	affiché dans la boutique ni vendable : rien ne casse s'il manque.
]]

return {
	-- Changer ce nom repart d'une sauvegarde vide : ne le modifier qu'en connaissance de cause.
	NOM_DATASTORE = "Joueurs_v1",
	PREFIXE_CLE = "joueur_",

	MONNAIE = {
		nom = "Cristaux",
		icone = "🔮",
	},

	-- Gains de la récompense quotidienne (jour 1 → 7, puis le cycle recommence).
	RECOMPENSES_QUOTIDIENNES = { 10, 20, 30, 50, 75, 100, 200 },

	SAUVEGARDE_AUTO_SECONDES = 120,

	-- Game Passes (achat unique, définitif).
	PASSES = {
		{
			cle = "DoubleMonnaie",
			id = 0,
			nom = "Cristaux x2",
			description = "Chaque cristal ramassé compte double, pour toujours.",
			multiplicateurMonnaie = 2,
		},
	},

	-- Developer Products (achats répétables).
	PRODUITS = {
		{ cle = "PackPetit", id = 0, nom = "Sac de cristaux", description = "+100 cristaux", monnaie = 100 },
		{ cle = "PackGrand", id = 0, nom = "Coffre de cristaux", description = "+600 cristaux", monnaie = 600 },
	},
}
