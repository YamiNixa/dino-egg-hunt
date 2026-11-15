-- Game: the hunt itself, and the only place that keeps state. One round
-- is one hunt: ten eggs, three hearts, a clock that only stops when the
-- last egg is in. Eggs and coins are per player (everyone hunts their
-- own ten), the raptors are shared, and the leaderboard is the fastest
-- wins this server has seen. The client never owns a number: it asks,
-- the server answers, and every change goes out on GameEvent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Map = require(script.Parent:WaitForChild("Map"))
local Raptors = require(script.Parent:WaitForChild("Raptors"))
local Shop = require(script.Parent:WaitForChild("Shop"))

local Game = {}

local event = nil -- RemoteEvent "GameEvent"
local shopBuy = nil -- RemoteFunction "ShopBuy"

local states = {} -- [player] = { coins, hearts, maxHearts, speedBonus, torchReadyAt, bought, eggs = {}, coinsGot = {}, startedAt, finished, won }
local eggs = {} -- [index] = part
local coins = {} -- [index] = part
local leaderboard = {} -- { { name = string, time = number } }, fastest first
local roundActive = false

local function newState(player)
	return {
		player = player,
		coins = 0,
		hearts = Config.MAX_HEARTS,
		maxHearts = Config.MAX_HEARTS,
		speedBonus = 0,
		torchReadyAt = 0,
		bought = { speed = false, heart = false, torch = false },
		eggs = {},
		coinsGot = {},
		eggsFound = 0,
		startedAt = os.clock(),
		finished = false,
		won = false,
		invulnerableUntil = 0,
	}
end

local function send(player, action, data)
	event:FireClient(player, action, data or {})
end

local function sendAll(action, data)
	event:FireAllClients(action, data or {})
end

-- The leaderboard, fastest wins first, for the client to draw on demand.
function Game.getLeaderboard()
	return leaderboard
end

function Game.broadcastLeaderboard()
	sendAll("leaderboard", leaderboard)
end

local function giveTorchTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	if backpack:FindFirstChild("Torch") then return end
	local tool = Instance.new("Tool")
	tool.Name = "Torch"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Click to scare the nearest raptor away"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 2.2, 0.5)
	handle.Color = Color3.fromRGB(120, 84, 48)
	handle.Material = Enum.Material.Wood
	handle.Parent = tool
	local flame = Instance.new("Part")
	flame.Name = "Flame"
	flame.Size = Vector3.new(0.8, 1.0, 0.8)
	flame.Position = Vector3.new(0, 1.5, 0)
	flame.Color = Config.PALETTE.campfire
	flame.Material = Enum.Material.Neon
	flame.Shape = Enum.PartType.Ball
	flame.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = flame
	weld.Parent = handle
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = flame
	tool.Parent = backpack
end

local function applySpeed(player)
	local state = states[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if state and hum then
		hum.WalkSpeed = Config.WALK_SPEED + state.speedBonus
	end
end

local function respawnAtCamp(player)
	local state = states[player]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(Config.CAMP_SPAWN)
	local ff = Instance.new("ForceField")
	ff.Parent = char
	game:GetService("Debris"):AddItem(ff, Config.INVULNERABLE_SECONDS)
	state.invulnerableUntil = os.clock() + Config.INVULNERABLE_SECONDS
end

local function endRoundFor(player, won)
	local state = states[player]
	if not state or state.finished then return end
	state.finished = true
	state.won = won
	local elapsed = os.clock() - state.startedAt
	if won then
		table.insert(leaderboard, { name = player.Name, time = elapsed })
		table.sort(leaderboard, function(a, b) return a.time < b.time end)
		while #leaderboard > 5 do table.remove(leaderboard) end
		sendAll("leaderboard", leaderboard)
	end
	send(player, "roundEnd", {
		won = won,
		time = math.floor(elapsed),
		eggs = state.eggsFound,
		coins = state.coins,
		leaderboard = leaderboard,
	})
end

local function onCatch(player)
	local state = states[player]
	if not state or state.finished then return end
	if os.clock() < state.invulnerableUntil then return end
	state.hearts -= 1
	send(player, "hearts", { hearts = state.hearts, maxHearts = state.maxHearts })
	if state.hearts <= 0 then
		endRoundFor(player, false)
	else
		respawnAtCamp(player)
		send(player, "caught", { hearts = state.hearts })
	end
end

local function spawnEggs(parent)
	for i, spot in ipairs(Config.EGG_SPOTS) do
		Map.buildNest(parent, spot)
		local egg = Instance.new("Part")
		egg.Name = "Egg" .. i
		egg.Size = Vector3.new(2.2, 2.8, 2.2)
		egg.Position = spot + Vector3.new(0, 1.7, 0)
		egg.Color = Config.PALETTE.egg
		egg.Material = Enum.Material.SmoothPlastic
		egg.Shape = Enum.PartType.Ball
		egg.Anchored = true
		egg.CanCollide = false
		egg:SetAttribute("EggIndex", i)
		egg.Parent = parent
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 240, 180)
		glow.Range = 14
		glow.Brightness = 1.6
		glow.Parent = egg
		eggs[i] = egg
		-- A pillar of light over every nest, so each egg is findable
		-- from across the island.
		local beacon = Instance.new("Part")
		beacon.Name = "EggBeacon" .. i
		beacon.Size = Vector3.new(1.4, 30, 1.4)
		beacon.Position = spot + Vector3.new(0, 15, 0)
		beacon.Color = Color3.fromRGB(255, 210, 90)
		beacon.Material = Enum.Material.Neon
		beacon.Transparency = 0.7
		beacon.Anchored = true
		beacon.CanCollide = false
		beacon.Parent = parent
	end
end

local function spawnCoins(parent)
	for i, spot in ipairs(Config.COIN_SPOTS) do
		local coin = Instance.new("Part")
		coin.Name = "Amber" .. i
		coin.Size = Vector3.new(1.2, 1.2, 0.4)
		coin.Position = spot + Vector3.new(0, 1.6, 0)
		coin.Color = Config.PALETTE.amber
		coin.Material = Enum.Material.Neon
		coin.Shape = Enum.PartType.Cylinder
		coin.Orientation = Vector3.new(0, 0, 90)
		coin.Anchored = true
		coin.CanCollide = false
		coin:SetAttribute("CoinIndex", i)
		coin.Parent = parent
		coins[i] = coin
	end
end

local function hookTouch(part, kind, index)
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		local state = states[player]
		if not state or state.finished or not roundActive then return end
		if kind == "egg" then
			if state.eggs[index] then return end
			state.eggs[index] = true
			state.eggsFound += 1
			send(player, "egg", { found = state.eggsFound, total = Config.EGG_TOTAL })
			if state.eggsFound >= Config.EGG_TOTAL then
				endRoundFor(player, true)
			end
		else
			if state.coinsGot[index] then return end
			state.coinsGot[index] = true
			state.coins += Config.COIN_VALUE
			send(player, "coin", { coins = state.coins })
		end
	end)
end

local function resetRoundFor(player)
	local state = states[player]
	if not state then return end
	state.coins = 0
	state.hearts = Config.MAX_HEARTS
	state.maxHearts = Config.MAX_HEARTS
	state.eggs = {}
	state.coinsGot = {}
	state.eggsFound = 0
	state.startedAt = os.clock()
	state.finished = false
	state.won = false
	state.invulnerableUntil = 0
	Shop.resetRound(state)
	applySpeed(player)
	send(player, "roundStart", {
		eggs = 0, total = Config.EGG_TOTAL,
		hearts = state.hearts, maxHearts = state.maxHearts,
		coins = 0, shop = Shop.catalog(state),
	})
end

local function onPlayerAdded(player)
	states[player] = newState(player)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.2)
		giveTorchTool(player)
		applySpeed(player)
		if roundActive then
			local state = states[player]
			send(player, "roundStart", {
				eggs = state.eggsFound, total = Config.EGG_TOTAL,
				hearts = state.hearts, maxHearts = state.maxHearts,
				coins = state.coins, shop = Shop.catalog(state),
			})
		end
	end)
end

local function onPlayerRemoving(player)
	states[player] = nil
end

function Game.start()
	local island = Map.build(Workspace)
	spawnEggs(island)
	spawnCoins(island)
	Raptors.spawnAll(Workspace)

	event = Instance.new("RemoteEvent")
	event.Name = "GameEvent"
	event.Parent = ReplicatedStorage

	shopBuy = Instance.new("RemoteFunction")
	shopBuy.Name = "ShopBuy"
	shopBuy.Parent = ReplicatedStorage
	shopBuy.OnServerInvoke = function(player, itemId)
		local state = states[player]
		if not state or state.finished then return false, "Round is over" end
		local ok, msg = Shop.buy(state, itemId, os.clock())
		if ok then
			applySpeed(player)
			send(player, "shop", { coins = state.coins, shop = Shop.catalog(state),
				hearts = state.hearts, maxHearts = state.maxHearts })
		end
		return ok, msg
	end

	event.OnServerEvent:Connect(function(player, action, _data)
		local state = states[player]
		if not state then return end
		if action == "torch" then
			if os.clock() < state.torchReadyAt then return end
			if Raptors.scareNearest(player, os.clock()) then
				state.torchReadyAt = os.clock() + Config.TORCH_COOLDOWN
				send(player, "torch", { readyIn = Config.TORCH_COOLDOWN, scared = true })
			else
				send(player, "torch", { readyIn = 0, scared = false })
			end
		elseif action == "playAgain" then
			resetRoundFor(player)
		end
	end)

	for i, egg in ipairs(eggs) do hookTouch(egg, "egg", i) end
	for i, coin in ipairs(coins) do hookTouch(coin, "coin", i) end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end

	roundActive = true

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local players = Players:GetPlayers()
		Raptors.update(dt, now, players, onCatch)
		for _, player in ipairs(players) do
			local state = states[player]
			if state and not state.finished and roundActive then
				if now - state.startedAt >= Config.ROUND_TIME_LIMIT then
					endRoundFor(player, false)
				end
			end
		end
	end)
end

return Game
