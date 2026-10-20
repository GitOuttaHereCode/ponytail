-- Shared game data. Odds here are the exact odds the server rolls and the UI shows.
local Config = {}

Config.DIG_SECONDS = 30 -- base time per dig at Speed 0
Config.OFFLINE_CAP_SECONDS = 8 * 60 * 60
Config.MAX_ANIMALS = 12
Config.BREED_COST = 50
Config.SHINY_CHANCE = 0.05
Config.SHINY_LUCK_BONUS = 3
Config.GOAT_PIG_STRENGTH = 7 -- a pig this strong is needed before goats unlock

-- rarity: "common" | "rare" | "ultra". Rare and ultra finds are announced server-wide.
Config.Layers = {
	{
		name = "Topsoil",
		animal = "Chicken",
		animalPrice = 0,
		drops = {
			{ name = "Pebble", pct = 50, price = 1, rarity = "common" },
			{ name = "River Rock", pct = 28, price = 2, rarity = "common" },
			{ name = "Quartz", pct = 15, price = 4, rarity = "common" },
			{ name = "Dud Geode", pct = 5.9, price = 8, rarity = "common" },
			{ name = "Golden Pebble", pct = 1, price = 100, rarity = "rare" },
			{ name = "Meteorite Fragment", pct = 0.1, price = 1000, rarity = "ultra" },
		},
	},
	{
		name = "Clay and Sandstone",
		animal = "Pig",
		animalPrice = 250,
		drops = {
			{ name = "Sandstone Chunk", pct = 45, price = 5, rarity = "common" },
			{ name = "Jasper", pct = 27, price = 8, rarity = "common" },
			{ name = "Agate", pct = 17, price = 12, rarity = "common" },
			{ name = "Ammonite Fossil", pct = 9.9, price = 20, rarity = "common" },
			{ name = "Dino Tooth", pct = 1, price = 400, rarity = "rare" },
			{ name = "Amber with a Bug Inside", pct = 0.1, price = 4000, rarity = "ultra" },
		},
	},
	{
		name = "Crystal Caves",
		animal = "Goat",
		animalPrice = 1500,
		drops = {
			{ name = "Calcite", pct = 42, price = 15, rarity = "common" },
			{ name = "Amethyst Geode", pct = 30, price = 25, rarity = "common" },
			{ name = "Glowing Fluorite", pct = 17, price = 40, rarity = "common" },
			{ name = "Crystal Cluster", pct = 9.9, price = 60, rarity = "common" },
			{ name = "Rainbow Geode", pct = 1, price = 1500, rarity = "rare" },
			{ name = "Raw Diamond", pct = 0.1, price = 15000, rarity = "ultra" },
		},
	},
}

Config.Rocks = {} -- name -> drop row with .layer
Config.AnimalLayer = {} -- animal kind -> layer index
for i, layer in Config.Layers do
	Config.AnimalLayer[layer.animal] = i
	local total = 0
	for _, drop in layer.drops do
		total += drop.pct
		drop.layer = i
		Config.Rocks[drop.name] = drop
	end
	-- Roblox requires disclosed odds, so a table that doesn't sum to 100 must not ship.
	assert(math.abs(total - 100) < 1e-6, `{layer.name} drops sum to {total}%, not 100%`)
end

-- r is a number in [0, 100). Returns the drop row for that roll.
function Config.pick(layerIndex: number, r: number)
	local drops = Config.Layers[layerIndex].drops
	for _, drop in drops do
		if r < drop.pct then
			return drop
		end
		r -= drop.pct
	end
	return drops[#drops] -- float rounding at the very top of the range
end

-- Seconds between digs for an animal. Speed 10 digs twice as fast as Speed 0.
function Config.digSeconds(animal): number
	return Config.DIG_SECONDS / (1 + animal.speed / 10)
end

-- Luck gives a chance of a second find per dig; it never changes the disclosed per-find odds.
function Config.bonusFindChance(animal): number
	return math.min(animal.luck, 20) / 40
end

return Config
