--[[
	Configuration partagée serveur + client.

	Les identifiants des passes et produits valent 0 tant qu'ils n'ont pas été
	créés sur Roblox (Creator Hub ou API Open Cloud). Un objet à 0 n'est ni
	affiché dans la boutique ni vendable : rien ne casse s'il manque.

	`python3 pipeline/opencloud.py boutique` crée sur Roblox les objets à 0
	(nom, description, `prix` en Robux, mis en vente) et écrit leur ID ici.
	`prix` ne sert qu'à la création : le jeu affiche toujours le prix réel lu
	sur Roblox (il peut avoir été changé depuis sur le Creator Hub).
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
			id = 2062597704,
			nom = "Cristaux x2",
			description = "Chaque cristal ramassé compte double, pour toujours.",
			prix = 99,
			multiplicateurMonnaie = 2,
		},
	},

	-- Developer Products (achats répétables).
	PRODUITS = {
		{
			cle = "PackPetit",
			id = 3725192416,
			nom = "Sac de cristaux",
			description = "+100 cristaux",
			prix = 25,
			monnaie = 100,
		},
		{
			cle = "PackGrand",
			id = 3725192420,
			nom = "Coffre de cristaux",
			description = "+600 cristaux",
			prix = 99,
			monnaie = 600,
		},
	},
}
