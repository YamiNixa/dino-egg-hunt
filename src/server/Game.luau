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
	handle.CanCollide = false
	handle.Parent = tool
	-- A dark wrapped band around the head of the handle, so the torch
	-- reads as a real wrapped torch, not a plain stick.
	local wrap = Instance.new("Part")
	wrap.Name = "Wrap"
	wrap.Size = Vector3.new(0.7, 0.5, 0.7)
	wrap.Position = Vector3.new(0, 0.9, 0)
	wrap.Color = Color3.fromRGB(60, 40, 20)
	wrap.Material = Enum.Material.Fabric
	wrap.CanCollide = false
	wrap.Parent = tool
	local wrapWeld = Instance.new("WeldConstraint")
	wrapWeld.Part0 = handle
	wrapWeld.Part1 = wrap
	wrapWeld.Parent = handle
	local flame = Instance.new("Part")
	flame.Name = "Flame"
	flame.Size = Vector3.new(1.0, 1.3, 1.0)
	flame.Position = Vector3.new(0, 1.8, 0)
	flame.Color = Config.PALETTE.campfire
	flame.Material = Enum.Material.Neon
	flame.Shape = Enum.PartType.Ball
	flame.CanCollide = false
	flame.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = flame
	weld.Parent = handle
	-- A yellow flame tip, so the flame has a shape, not just a ball.
	local tip = Instance.new("Part")
	tip.Name = "FlameTip"
	tip.Size = Vector3.new(0.7, 0.9, 0.7)
	tip.Position = Vector3.new(0, 2.6, 0)
	tip.Color = Color3.fromRGB(255, 220, 80)
	tip.Material = Enum.Material.Neon
	tip.Shape = Enum.PartType.Wedge
	tip.CanCollide = false
	tip.Parent = tool
	local tipWeld = Instance.new("WeldConstraint")
	tipWeld.Part0 = handle
	tipWeld.Part1 = tip
	tipWeld.Parent = handle
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = 14
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
		-- A DINOSAUR egg, not a chicken egg: big (4.6 wide, 5.4 tall,
		-- taller than a player's torso), elongated, PALE MINT-GREEN
		-- with big dark speckles, so it can never read as a white
		-- chicken egg, even from 30 studs away.
		local egg = Instance.new("Part")
		egg.Name = "Egg" .. i
		egg.Size = Vector3.new(4.6, 5.4, 4.6)
		egg.Position = spot + Vector3.new(0, 2.7, 0)
		egg.Color = Color3.fromRGB(200, 235, 180)
		egg.Material = Enum.Material.SmoothPlastic
		egg.Shape = Enum.PartType.Ball
		egg.Anchored = true
		egg.CanCollide = false
		egg:SetAttribute("EggIndex", i)
		egg.Parent = parent
		-- Speckles: BIG raised spots on the shell, at fixed angles so
		-- every egg looks the same in every server. They sit PROUD of
		-- the shell surface (1.0 of the radius) in near-black green
		-- and brown, so they still read at 30+ studs — the old 0.9-stud
		-- speckles tucked inside the shell were invisible past 10.
		local speckleCols = { Color3.fromRGB(30, 50, 25), Color3.fromRGB(60, 40, 20) }
		local speckleDirs = {
			{ 0, 30 }, { 90, 50 }, { 180, 40 }, { 270, 55 },
			{ 45, 80 }, { 135, 75 }, { 225, 85 }, { 315, 70 }, { 60, 15 },
		}
		for s, dir in ipairs(speckleDirs) do
			local theta = math.rad(dir[1])
			local phi = math.rad(dir[2])
			local ux = math.sin(phi) * math.cos(theta)
			local uy = math.cos(phi)
			local uz = math.sin(phi) * math.sin(theta)
			local sp = Instance.new("Part")
			sp.Name = "Speckle"
			sp.Size = Vector3.new(2.2, 1.8, 2.2)
			sp.Position = egg.Position + Vector3.new(ux * 2.3 * 1.0, uy * 2.7 * 1.0, uz * 2.3 * 1.0)
			sp.Color = speckleCols[(s % 2) + 1]
			sp.Material = Enum.Material.SmoothPlastic
			sp.Shape = Enum.PartType.Ball
			sp.Anchored = true
			sp.CanCollide = false
			sp.Parent = egg
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 240, 180)
		glow.Range = 20
		glow.Brightness = 2.5
		glow.Parent = egg
		eggs[i] = egg
		-- A soft glowing ring flat on the ground under the nest, so the
		-- spot reads as special even when the egg is behind a tree.
		-- (Cylinder axis is X: Size.x is the thickness, and the 90 deg
		-- Z rotation lays the disc flat.)
		local ring = Instance.new("Part")
		ring.Name = "EggRing" .. i
		ring.Size = Vector3.new(0.3, 8.5, 8.5)
		ring.Position = spot + Vector3.new(0, 0.35, 0)
		ring.Color = Color3.fromRGB(255, 210, 90)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.5
		ring.Shape = Enum.PartType.Cylinder
		ring.Orientation = Vector3.new(0, 0, 90)
		ring.Anchored = true
		ring.CanCollide = false
		ring.Parent = parent
		-- A floating egg icon over the egg, always on top, so an egg is
		-- unmissable from across the island. The tall yellow beacon
		-- pillars are gone: Adrian read them as something else, not eggs.
		local icon = Instance.new("BillboardGui")
		icon.Name = "EggIcon"
		icon.Adornee = egg
		icon.Size = UDim2.new(6, 0, 6, 0)
		icon.StudsOffset = Vector3.new(0, 7.5, 0)
		icon.AlwaysOnTop = true
		icon.Parent = egg
		local iconText = Instance.new("TextLabel")
		iconText.Name = "Icon"
		iconText.Size = UDim2.new(1, 0, 1, 0)
		-- Solid gold circle behind the egg, so the icon pops against
		-- the sky instead of washing out like the old transparent one.
		iconText.BackgroundTransparency = 0
		iconText.BackgroundColor3 = Color3.fromRGB(255, 210, 90)
		iconText.Text = "🥚"
		iconText.TextScaled = true
		iconText.Font = Enum.Font.GothamBold
		iconText.Parent = icon
		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(0.5, 0)
		iconCorner.Parent = iconText
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

-- One place that collects an egg, so the touch hook and the proximity
-- check below can never drift apart. Returns true if it collected.
local function collectEgg(player, index)
	local state = states[player]
	if not state or state.finished or not roundActive then return false end
	if state.eggs[index] then return false end
	state.eggs[index] = true
	state.eggsFound += 1
	send(player, "egg", { found = state.eggsFound, total = Config.EGG_TOTAL })
	if state.eggsFound >= Config.EGG_TOTAL then
		endRoundFor(player, true)
	end
	return true
end

local function hookTouch(part, kind, index)
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		local state = states[player]
		if not state or state.finished or not roundActive then return end
		if kind == "egg" then
			collectEgg(player, index)
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
		-- The torch starts IN the hand, not in the backpack: equip it
		-- the moment the character loads, so the flame is always visible.
		local hum = char:FindFirstChildOfClass("Humanoid")
		local backpack = player:FindFirstChildOfClass("Backpack")
		local torch = backpack and backpack:FindFirstChild("Torch")
		if hum and torch then
			hum:EquipTool(torch)
		end
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

	local tickAccum = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local players = Players:GetPlayers()
		-- Grace: no raptor engages a player in their first 10 seconds,
		-- so the player sees the pack patrolling with its red markers
		-- before anything can catch them from behind.
		local grace = {}
		for _, p in ipairs(players) do
			local st = states[p]
			if st and now - st.startedAt < Config.RAPTOR_GRACE_SECONDS then
				grace[p] = true
			end
		end
		Raptors.update(dt, now, players, onCatch, grace)
		-- Proximity egg pickup + raptor radar, every ~0.2s. Touch alone
		-- was not enough: players walk NEAR eggs (2-3 studs) and the
		-- egg never fires, so the hunt could not be completed.
		tickAccum += dt
		if tickAccum >= 0.2 then
			tickAccum = 0
			for _, player in ipairs(players) do
				local state = states[player]
				if state and not state.finished and roundActive then
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root then
						for i, egg in ipairs(eggs) do
							if not state.eggs[i] and (root.Position - egg.Position).Magnitude <= 7 then
								collectEgg(player, i)
							end
						end
						local radar = Raptors.nearestRadar(player)
						if radar then send(player, "radar", radar) end
					end
				end
			end
		end
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
