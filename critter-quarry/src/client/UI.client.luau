local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Action = remotes:WaitForChild("Action")

local gui = Instance.new("ScreenGui")
gui.Name = "CritterQuarry"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function label(text, parent, height)
	return make("TextLabel", {
		Text = text,
		Size = UDim2.new(1, 0, 0, height or 24),
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextWrapped = true,
	}, parent)
end

local function button(text, parent, onClick)
	local b = make("TextButton", {
		Text = text,
		Size = UDim2.new(0, 0, 0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(70, 130, 90),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, parent)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	b.Activated:Connect(onClick)
	return b
end

local function panel(position, size)
	local f = make("ScrollingFrame", {
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(45, 35, 30),
		BackgroundTransparency = 0.15,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, f)
	make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, f)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	return f
end

local function row(parent)
	local r = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, parent)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, r)
	return r
end

local barn = panel(UDim2.new(0, 10, 0, 60), UDim2.new(0.3, 0, 0.75, 0))
local quarry = panel(UDim2.new(0.3, 20, 0, 60), UDim2.new(0.4, 0, 0.75, 0))
local odds = panel(UDim2.new(0.7, 30, 0, 60), UDim2.new(0.3, -40, 0.75, 0))
odds.Visible = false

local top = make("Frame", { Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(1, -20, 0, 40), BackgroundTransparency = 1 }, gui)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center }, top)
local coinsLabel = label("Coins: 0", top, 40)
coinsLabel.Size = UDim2.new(0, 200, 0, 40)
coinsLabel.TextSize = 22
button("Show odds", top, function()
	odds.Visible = not odds.Visible
end)

local toast = make("TextLabel", {
	Position = UDim2.new(0.5, 0, 1, -20),
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.new(0.6, 0, 0, 40),
	BackgroundColor3 = Color3.fromRGB(240, 200, 80),
	TextColor3 = Color3.new(0, 0, 0),
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextWrapped = true,
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, toast)
local toastId = 0
remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.Visible = true
	task.delay(4, function()
		if toastId == id then
			toast.Visible = false
		end
	end)
end)

-- Odds never change at runtime, so build that panel once.
label("Drop odds per find", odds).Font = Enum.Font.GothamBold
for _, layer in Config.Layers do
	label(`{layer.name} ({layer.animal})`, odds).TextColor3 = Color3.fromRGB(240, 200, 80)
	for _, drop in layer.drops do
		label(`  {drop.name}: {drop.pct}% (1 in {math.floor(100 / drop.pct + 0.5)})`, odds)
	end
end
label("Luck gives a chance at a second find per dig. It never changes these odds.", odds, 40)

local function clear(frame)
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

remotes:WaitForChild("State").OnClientEvent:Connect(function(data, unlocked)
	coinsLabel.Text = `Coins: {data.coins}`

	clear(barn)
	label(`Barn ({#data.animals}/{Config.MAX_ANIMALS})`, barn).Font = Enum.Font.GothamBold
	for _, a in data.animals do
		label(`{a.shiny and "★ " or ""}{a.kind}  Spd {a.speed}  Luck {a.luck}  Str {a.strength}`, barn)
	end
	for i, layer in Config.Layers do
		if unlocked[i] then
			local r = row(barn)
			button(`Buy {layer.animal} ({layer.animalPrice})`, r, function()
				Action:FireServer("Buy", layer.animal)
			end)
			button(`Breed ({Config.BREED_COST})`, r, function()
				Action:FireServer("Breed", layer.animal)
			end)
		end
	end
	local nextLocked = table.find(unlocked, false)
	if nextLocked then
		local need = `Fill the {Config.Layers[nextLocked - 1].name} museum shelf`
		if Config.Layers[nextLocked].animal == "Goat" then
			need ..= ` and breed a Pig with Str {Config.GOAT_PIG_STRENGTH}+`
		end
		label(`Next: {Config.Layers[nextLocked].name}. {need}.`, barn, 48).TextColor3 = Color3.fromRGB(200, 200, 200)
	end

	clear(quarry)
	for _, layer in Config.Layers do
		local have = 0
		for _, drop in layer.drops do
			have += data.museum[drop.name] and 1 or 0
		end
		label(`{layer.name} museum: {have}/{#layer.drops}`, quarry).Font = Enum.Font.GothamBold
		for _, drop in layer.drops do
			local count = data.inventory[drop.name] or 0
			if count > 0 or data.museum[drop.name] then
				local r = row(quarry)
				local l = label(`{data.museum[drop.name] and "✔ " or ""}{drop.name} x{count}`, r)
				l.Size = UDim2.new(0.5, 0, 1, 0)
				if count > 0 then
					button(`Sell ({drop.price * count})`, r, function()
						Action:FireServer("Sell", drop.name)
					end)
					if not data.museum[drop.name] then
						button("Museum", r, function()
							Action:FireServer("Donate", drop.name)
						end)
					end
				end
			end
		end
	end
end)
