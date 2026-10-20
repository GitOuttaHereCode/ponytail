local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local store = DataStoreService:GetDataStore("CritterQuarry_v1")
local rng = Random.new()

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local Action = Instance.new("RemoteEvent")
Action.Name = "Action"
Action.Parent = remotes
local State = Instance.new("RemoteEvent")
State.Name = "State"
State.Parent = remotes
local Notify = Instance.new("RemoteEvent")
Notify.Name = "Notify"
Notify.Parent = remotes
remotes.Parent = ReplicatedStorage

local sessions = {} -- player -> { data, canSave, progress = { [animalIndex] = seconds } }

local function newAnimal(kind, speed, luck, strength, shiny)
	return { kind = kind, speed = speed, luck = luck, strength = strength, shiny = shiny }
end

local function newData()
	return { coins = 0, animals = { newAnimal("Chicken", 1, 1, 1, false) }, inventory = {}, museum = {}, lastSeen = os.time() }
end

local function museumComplete(data, layerIndex)
	for _, drop in Config.Layers[layerIndex].drops do
		if not data.museum[drop.name] then
			return false
		end
	end
	return true
end

local function layerUnlocked(data, layerIndex)
	if layerIndex == 1 then
		return true
	end
	if not museumComplete(data, layerIndex - 1) then
		return false
	end
	if Config.Layers[layerIndex].animal == "Goat" then
		for _, a in data.animals do
			if a.kind == "Pig" and a.strength >= Config.GOAT_PIG_STRENGTH then
				return true
			end
		end
		return false
	end
	return true
end

local function push(player)
	local s = sessions[player]
	local unlocked = {}
	for i in Config.Layers do
		unlocked[i] = layerUnlocked(s.data, i)
	end
	State:FireClient(player, s.data, unlocked)
end

local function dig(player, animal, live)
	local finds = rng:NextNumber() < Config.bonusFindChance(animal) and 2 or 1
	local data = sessions[player].data
	for _ = 1, finds do
		local drop = Config.pick(Config.AnimalLayer[animal.kind], rng:NextNumber(0, 100))
		data.inventory[drop.name] = (data.inventory[drop.name] or 0) + 1
		if live and drop.rarity ~= "common" then
			Notify:FireAllClients(`{player.DisplayName}'s {animal.kind} found a {drop.name}!`)
		end
	end
end

-- Runs an animal's digs for `seconds` of time, carrying leftover time to the next tick.
local function advance(player, i, seconds, live)
	local s = sessions[player]
	local animal = s.data.animals[i]
	local interval = Config.digSeconds(animal)
	local t = (s.progress[i] or 0) + seconds
	while t >= interval do
		t -= interval
		dig(player, animal, live)
	end
	s.progress[i] = t
end

local function save(player)
	local s = sessions[player]
	if not s or not s.canSave then
		return
	end
	s.data.lastSeen = os.time()
	local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), s.data)
	if not ok then
		warn(`Save failed for {player.UserId}: {err}`)
	end
end

Players.PlayerAdded:Connect(function(player)
	local ok, saved = pcall(store.GetAsync, store, tostring(player.UserId))
	if not ok and not RunService:IsStudio() then
		-- Never start a blank save over a real one we failed to read.
		player:Kick("Couldn't load your quarry. Please rejoin in a minute.")
		return
	end
	local data = (ok and saved) or newData()
	sessions[player] = { data = data, canSave = ok, progress = {} }

	local away = math.clamp(os.time() - (data.lastSeen or os.time()), 0, Config.OFFLINE_CAP_SECONDS)
	local before = 0
	for _, n in data.inventory do
		before += n
	end
	for i in data.animals do
		advance(player, i, away, false)
	end
	local after = 0
	for _, n in data.inventory do
		after += n
	end
	push(player)
	if after > before then
		Notify:FireClient(player, `Welcome back! Your critters dug up {after - before} rocks while you were away.`)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	sessions[player] = nil
end)

game:BindToClose(function()
	for player in sessions do
		task.spawn(save, player)
	end
	task.wait(3)
end)

local actions = {}

function actions.Sell(player, data, rock)
	local count = data.inventory[rock]
	if not count or count < 1 then
		return
	end
	data.coins += count * Config.Rocks[rock].price
	data.inventory[rock] = nil
end

function actions.Donate(player, data, rock)
	if data.museum[rock] or (data.inventory[rock] or 0) < 1 then
		return
	end
	data.inventory[rock] -= 1
	if data.inventory[rock] == 0 then
		data.inventory[rock] = nil
	end
	data.museum[rock] = true
	if museumComplete(data, Config.Rocks[rock].layer) then
		Notify:FireClient(player, `{Config.Layers[Config.Rocks[rock].layer].name} collection complete!`)
	end
end

function actions.Buy(player, data, kind)
	local layer = Config.Layers[Config.AnimalLayer[kind]]
	if #data.animals >= Config.MAX_ANIMALS then
		return Notify:FireClient(player, "Your barn is full.")
	end
	if not layerUnlocked(data, Config.AnimalLayer[kind]) then
		return Notify:FireClient(player, `Unlock {layer.name} first.`)
	end
	if data.coins < layer.animalPrice then
		return Notify:FireClient(player, "Not enough coins.")
	end
	data.coins -= layer.animalPrice
	table.insert(data.animals, newAnimal(kind, 1, 1, 1, false))
end

-- Breeds the two strongest animals of a kind. The baby averages the parents, then shifts each stat by -1..+2.
function actions.Breed(player, data, kind)
	if #data.animals >= Config.MAX_ANIMALS then
		return Notify:FireClient(player, "Your barn is full.")
	end
	if data.coins < Config.BREED_COST then
		return Notify:FireClient(player, "Not enough coins.")
	end
	local parents = {}
	for _, a in data.animals do
		if a.kind == kind then
			table.insert(parents, a)
		end
	end
	if #parents < 2 then
		return Notify:FireClient(player, `You need two {kind}s to breed.`)
	end
	table.sort(parents, function(x, y)
		return x.speed + x.luck + x.strength > y.speed + y.luck + y.strength
	end)
	local a, b = parents[1], parents[2]
	local function mix(x, y)
		return math.clamp(math.floor((x + y) / 2) + rng:NextInteger(-1, 2), 1, 10)
	end
	local shiny = rng:NextNumber() < Config.SHINY_CHANCE
	local baby = newAnimal(kind, mix(a.speed, b.speed), mix(a.luck, b.luck), mix(a.strength, b.strength), shiny)
	if shiny then
		baby.luck += Config.SHINY_LUCK_BONUS
	end
	data.coins -= Config.BREED_COST
	table.insert(data.animals, baby)
	Notify:FireClient(player, `A {shiny and "SHINY " or ""}{kind} was born! Spd {baby.speed} Luck {baby.luck} Str {baby.strength}`)
end

Action.OnServerEvent:Connect(function(player, name, arg)
	local s = sessions[player]
	-- Client input is untrusted: only known actions, and only real rock or animal names.
	if not s or type(name) ~= "string" or not actions[name] or type(arg) ~= "string" then
		return
	end
	local isRockAction = name == "Sell" or name == "Donate"
	if (isRockAction and not Config.Rocks[arg]) or (not isRockAction and not Config.AnimalLayer[arg]) then
		return
	end
	actions[name](player, s.data, arg)
	push(player)
end)

-- Digging and autosave clocks.
local sinceSave = 0
while true do
	task.wait(1)
	sinceSave += 1
	for player, s in sessions do
		local changed = false
		for i in s.data.animals do
			local t = s.progress[i] or 0
			advance(player, i, 1, true)
			changed = changed or s.progress[i] < t + 1 -- leftover shrank, so a dig happened
		end
		if changed then
			push(player)
		end
	end
	if sinceSave >= 60 then
		sinceSave = 0
		for player in sessions do
			task.spawn(save, player)
		end
	end
end
