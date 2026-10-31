--[[
	Affiche la configuration partagée du jeu (src/ReplicatedStorage/Partage/Configuration.luau)
	en JSON. Utilisé par pipeline/opencloud.py, qui ne sait pas lire le Luau.

	Usage : lune run pipeline/configuration
]]

local serde = require("@lune/serde")

local Configuration = require("../src/ReplicatedStorage/Partage/Configuration")

print(serde.encode("json", Configuration))
