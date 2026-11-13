--[[
	Catalogue des formats de jeu que la Fabrique connaît.

	`mots` : mots (anglais, minuscules) des noms de jeux « En pleine ascension »
	qui signalent ce format. Le score d'un format est la somme du nombre de jeux
	en ascension dont le nom contient chacun de ses mots (colonne « Nb de jeux »
	du tableau « Formats qui montent » de recherche/rapport-niche.md).

	`gabarit` : nil = format repéré dans les tendances mais PAS ENCORE construit
	par la Fabrique. Il reste dans le catalogue pour que `fabrique/creer
	--tendances` montre honnêtement ce qui monte et qu'on ne sait pas produire.
]]

return {
	{
		cle = "tour",
		nom = "Tour à grimper",
		mots = { "tower", "climb", "obby" },
		gabarit = "parcours",
		genreRoblox = "Obby & Platformer",
		modelesTitre = { "Climb The %s Tower", "%s Tower Obby", "Tower Of %s" },
		resume = "Une tour à gravir en spirale, étape par étape, jusqu'au sommet.",
	},
	{
		cle = "evasion",
		nom = "Évasion (parcours)",
		mots = { "escape", "prison", "run", "obby" },
		gabarit = "parcours",
		genreRoblox = "Obby & Platformer",
		modelesTitre = { "Escape The %s Run", "%s Escape Obby", "%s Prison Run" },
		resume = "Un parcours d'obstacles pour s'échapper, de la cellule jusqu'à la sortie.",
	},
	{
		cle = "vol",
		nom = "Voler / bases de joueurs",
		mots = { "steal" },
		genreRoblox = "Simulation",
		resume = "Chaque joueur a une base ; on vole les objets des autres. Demande du multijoueur compétitif.",
	},
	{
		cle = "ragdoll",
		nom = "Bac à sable ragdoll",
		mots = { "ragdoll", "playground", "realistic" },
		genreRoblox = "Simulation",
		resume = "Bac à sable de physique des personnages. Demande la physique réelle, non testable hors Roblox.",
	},
	{
		cle = "oeufs",
		nom = "Œufs / collection",
		mots = { "egg", "eggs", "ride" },
		genreRoblox = "Simulation",
		resume = "Collectionner, faire éclore, chevaucher des créatures.",
	},
	{
		cle = "evolution",
		nom = "+1 / évolution",
		mots = { "evolution", "simulator" },
		genreRoblox = "Simulation",
		resume = "On gagne +1 à chaque action, on grandit, on renaît (rebirth).",
	},
	{
		cle = "construction",
		nom = "Construire / fabriquer",
		mots = { "build", "make" },
		genreRoblox = "Simulation",
		resume = "Assembler un objet ou un personnage pièce par pièce.",
	},
}
