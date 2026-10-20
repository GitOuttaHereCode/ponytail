-- Run with the Luau CLI: luau critter-quarry/tests/config.test.luau
local Config = require("../src/shared/Config")

-- Loading Config already asserts each layer sums to 100%. Check the roll edges land right.
assert(Config.pick(1, 0).name == "Pebble")
assert(Config.pick(1, 49.999).name == "Pebble")
assert(Config.pick(1, 50).name == "River Rock")
assert(Config.pick(1, 99.89).name == "Golden Pebble")
assert(Config.pick(1, 99.95).name == "Meteorite Fragment")
assert(Config.pick(3, 100).name == "Raw Diamond")

-- Over many rolls, observed rates match the disclosed odds.
local counts, n = {}, 200000
math.randomseed(1)
for _ = 1, n do
	local name = Config.pick(2, math.random() * 100).name
	counts[name] = (counts[name] or 0) + 1
end
for _, drop in Config.Layers[2].drops do
	local got = (counts[drop.name] or 0) / n * 100
	assert(math.abs(got - drop.pct) < 0.2 + drop.pct * 0.1, `{drop.name}: {got}% vs {drop.pct}%`)
end

assert(Config.digSeconds({ speed = 10 }) == 15)
assert(Config.bonusFindChance({ luck = 40 }) == 0.5)
print("config ok")
