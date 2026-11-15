-- DINO EGG HUNT, client: everything the player sees and touches. The
-- menu, the HUD, the shop, the win and lose screens, the torch and the
-- sprint. The client never owns a number: the server sends the state,
-- this script only draws it and asks for actions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gameEvent = ReplicatedStorage:WaitForChild("GameEvent")
local shopBuy = ReplicatedStorage:WaitForChild("ShopBuy")

local PING_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local gui = Instance.new("ScreenGui")
gui.Name = "EggHuntGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function makeLabel(parent, name, text, size, pos, anchor)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = Config.PALETTE.uiText
	l.BackgroundTransparency = 1
	l.AnchorPoint = anchor or Vector2.new(0, 0)
	l.Position = pos
	l.Parent = parent
	return l
end

local function makeButton(parent, name, text, size, pos, anchor)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 20
	b.TextColor3 = Color3.fromRGB(30, 25, 15)
	b.BackgroundColor3 = Config.PALETTE.uiAccent
	b.BorderSizePixel = 0
	b.Size = size
	b.Position = pos
	b.AnchorPoint = anchor or Vector2.new(0, 0)
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	return b
end

local function makePanel(parent, name, size, pos, anchor)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor or Vector2.new(0, 0)
	f.BackgroundColor3 = Config.PALETTE.uiPanel
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	return f
end

local function playPing(pitch)
	local ok, err = pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = PING_SOUND
		s.Volume = 0.6
		s.PlaybackSpeed = pitch or 1
		s.Parent = gui
		SoundService:PlayLocalSound(s)
		game:GetService("Debris"):AddItem(s, 2)
	end)
	if not ok then warn("[EggHunt] sound failed: " .. tostring(err)) end
end

-- The roar: two low, loud pings staggered, so the round opens with a
-- growl instead of silence. Built-in sound only, no external asset.
local function playRoar()
	for _, pitch in ipairs({ 0.3, 0.45 }) do
		task.spawn(function()
			if pitch > 0.3 then task.wait(0.28) end
			local ok, err = pcall(function()
				local s = Instance.new("Sound")
				s.SoundId = PING_SOUND
				s.Volume = 1
				s.PlaybackSpeed = pitch
				s.Parent = gui
				SoundService:PlayLocalSound(s)
				game:GetService("Debris"):AddItem(s, 3)
			end)
			if not ok then warn("[EggHunt] roar failed: " .. tostring(err)) end
		end)
	end
end

-- The torch animation, client-side: the flame flickers every frame, the
-- torch sways gently while the player walks, and pressing F raises it in
-- a wave while the flame flares. The F mechanic itself is untouched —
-- this is visuals only, driven through the tool's Grip so it never
-- fights the default walk animation.
local torchWaveUntil = 0
local torchFlareUntil = 0
local torchBaseGrip = nil
local torchFlame = nil
local torchLight = nil

local function findTorchParts()
	local char = player.Character
	if not char then return nil end
	local tool = char:FindFirstChild("Torch")
	if not tool then return nil end
	local flame = tool:FindFirstChild("Flame")
	if not flame then return nil end
	torchFlame = flame
	torchLight = flame:FindFirstChildOfClass("PointLight")
	if not torchBaseGrip then torchBaseGrip = tool.Grip end
	return tool
end

local function animateTorch(now, dt)
	local tool = findTorchParts()
	if not tool then return end
	local t = now * 1
	-- Flicker: flame size and light brightness wobble on two sines.
	local flick = 1 + 0.12 * math.sin(t * 13) + 0.06 * math.sin(t * 29)
	local flare = now < torchFlareUntil and 1.6 or 1
	torchFlame.Size = Vector3.new(1.0 * flick * flare, 1.3 * flick * flare, 1.0 * flick * flare)
	if torchLight then
		torchLight.Brightness = (1.5 + 0.5 * math.sin(t * 11)) * (now < torchFlareUntil and 2.3 or 1)
	end
	-- Sway: a gentle swing while walking, still while standing.
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local moving = hum and hum.MoveDirection.Magnitude > 0.1
	local swayAmp = moving and 0.12 or 0.04
	local sway = math.sin(t * (moving and 6 or 2)) * swayAmp
	-- Wave: on F the torch raises up and out, then settles back.
	local wave = 0
	if now < torchWaveUntil then
		local p = 1 - (torchWaveUntil - now) / 1
		wave = math.sin(p * math.pi) * 1.1
	end
	tool.Grip = (torchBaseGrip or CFrame.new()) * CFrame.Angles(-wave, 0, sway)
end

-- The HUD: eggs and the clock top-centre, hearts and amber top-right.
-- Nothing sits in the top-left corner: Roblox's own menu lives there.
local hud = makePanel(gui, "HUD", UDim2.new(0, 460, 0, 64), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))
hud.Visible = false
local eggLabel = makeLabel(hud, "Eggs", "🥚 0/10", 26, UDim2.new(0, 16, 0, 6))
eggLabel.Size = UDim2.new(0, 150, 0, 26)
local timerLabel = makeLabel(hud, "Timer", "0:00", 26, UDim2.new(0, 16, 0, 34))
timerLabel.Size = UDim2.new(0, 150, 0, 26)
local heartLabel = makeLabel(hud, "Hearts", "❤❤❤", 26, UDim2.new(1, -170, 0, 6), Vector2.new(1, 0))
heartLabel.Size = UDim2.new(0, 160, 0, 26)
local coinLabel = makeLabel(hud, "Coins", "⬢ 0 amber", 22, UDim2.new(1, -170, 0, 34), Vector2.new(1, 0))
coinLabel.Size = UDim2.new(0, 160, 0, 26)
coinLabel.TextColor3 = Config.PALETTE.amber

local shopButton = makeButton(gui, "ShopButton", "🛒 SHOP", UDim2.fromOffset(120, 44), UDim2.new(1, -140, 0, 88), Vector2.new(1, 0))
shopButton.Visible = false

local hintLabel = makeLabel(gui, "Hint", "Find 10 eggs. Raptors hunt you — torch (F) scares them off.", 18,
	UDim2.new(0.5, 0, 1, -48), Vector2.new(0.5, 1))
hintLabel.Size = UDim2.new(0, 700, 0, 28)
hintLabel.Visible = false

local torchLabel = makeLabel(gui, "Torch", "🔥 Torch ready [F]", 18,
	UDim2.new(0.5, 0, 1, -80), Vector2.new(0.5, 1))
torchLabel.Size = UDim2.new(0, 300, 0, 26)
torchLabel.Visible = false

-- The raptor radar: nearest raptor's distance + direction, live from the
-- server, so a raptor is never a surprise from behind.
local radarLabel = makeLabel(gui, "Radar", "", 20,
	UDim2.new(0.5, 0, 0, 84), Vector2.new(0.5, 0))
radarLabel.Size = UDim2.new(0, 460, 0, 26)
radarLabel.Visible = false

-- The egg flash: a big gold "EGG FOUND!" across the centre of the
-- screen, so a pickup reads even while the player is running.
local eggFlash = makeLabel(gui, "EggFlash", "", 40,
	UDim2.new(0.5, 0, 0.42, 0), Vector2.new(0.5, 0.5))
eggFlash.Size = UDim2.new(0, 620, 0, 56)
eggFlash.TextColor3 = Color3.fromRGB(255, 210, 90)
eggFlash.Visible = false

-- The roar banner: a big warning across the top of the screen when a
-- round starts, so the player looks for the red markers at once.
local banner = makePanel(gui, "RoarBanner", UDim2.new(0, 560, 0, 52), UDim2.new(0.5, 0, 0, 92), Vector2.new(0.5, 0))
banner.BackgroundColor3 = Color3.fromRGB(120, 20, 15)
banner.BackgroundTransparency = 0.1
banner.Visible = false
local bannerLabel = makeLabel(banner, "Text", "🦖 RAPTORS ARE HUNTING — watch the red markers!", 22,
	UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
bannerLabel.Size = UDim2.new(1, -16, 1, 0)
bannerLabel.TextColor3 = Color3.fromRGB(255, 230, 200)

-- The damage flash: a red wash that fades after a catch.
local flash = Instance.new("Frame")
flash.Name = "DamageFlash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(200, 30, 20)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

-- The menu: title, how to play, the leaderboard, and Play.
local menu = makePanel(gui, "Menu", UDim2.new(0, 520, 0, 460), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
makeLabel(menu, "Title", "🦖 DINO EGG HUNT", 40, UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0)).Size = UDim2.new(1, 0, 0, 48)
makeLabel(menu, "Sub", "A Jurassic jungle survival hunt", 18, UDim2.new(0.5, 0, 0, 74), Vector2.new(0.5, 0)).Size = UDim2.new(1, 0, 0, 24)
local howto = makeLabel(menu, "HowTo",
	"🥚 Collect 10 dino eggs hidden across the island.\n" ..
	"🦖 Raptors patrol the jungle. If one catches you, you lose a heart\n" ..
	"and wake up back at camp. Three hearts, then the hunt is over.\n" ..
	"🔥 Torch (F or click the torch tool) scares the nearest raptor away.\n" ..
	"⬢ Amber coins buy Swift Boots, an Extra Heart and Torch Oil.\n" ..
	"🏃 Hold SHIFT to sprint. Fastest win tops the leaderboard.",
	16, UDim2.new(0.5, 0, 0, 108), Vector2.new(0.5, 0))
howto.Size = UDim2.new(1, -48, 0, 130)
howto.TextXAlignment = Enum.TextXAlignment.Left
howto.TextYAlignment = Enum.TextYAlignment.Top
local boardLabel = makeLabel(menu, "Board", "🏆 Fastest wins —", 18, UDim2.new(0.5, 0, 0, 248), Vector2.new(0.5, 0))
boardLabel.Size = UDim2.new(1, -48, 0, 24)
local boardList = makeLabel(menu, "BoardList", "No wins yet. Be the first!", 16, UDim2.new(0.5, 0, 0, 274), Vector2.new(0.5, 0))
boardList.Size = UDim2.new(1, -48, 0, 90)
boardList.TextYAlignment = Enum.TextYAlignment.Top
local playButton = makeButton(menu, "Play", "▶  PLAY", UDim2.new(0, 220, 0, 52), UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1))

-- The shop panel: three items, each with a price and a Buy button.
local shopPanel = makePanel(gui, "Shop", UDim2.new(0, 440, 0, 300), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
shopPanel.Visible = false
makeLabel(shopPanel, "ShopTitle", "🛒 AMBER SHOP", 26, UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0)).Size = UDim2.new(1, 0, 0, 32)
local shopRows = {}
for i = 1, 3 do
	local y = 60 + (i - 1) * 64
	local row = makePanel(shopPanel, "Row" .. i, UDim2.new(1, -32, 0, 54), UDim2.new(0, 16, 0, y))
	local name = makeLabel(row, "Name", "", 18, UDim2.new(0, 12, 0, 6))
	name.Size = UDim2.new(1, -140, 0, 22)
	local desc = makeLabel(row, "Desc", "", 14, UDim2.new(0, 12, 0, 30))
	desc.Size = UDim2.new(1, -140, 0, 20)
	desc.TextColor3 = Color3.fromRGB(200, 200, 180)
	local buy = makeButton(row, "Buy", "Buy", UDim2.fromOffset(100, 36), UDim2.new(1, -12, 0, 9), Vector2.new(1, 0))
	shopRows[i] = { name = name, desc = desc, buy = buy }
end
local shopClose = makeButton(shopPanel, "Close", "Close", UDim2.new(0, 120, 0, 40), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
local shopMsg = makeLabel(shopPanel, "Msg", "", 15, UDim2.new(0.5, 0, 1, -64), Vector2.new(0.5, 1))
shopMsg.Size = UDim2.new(1, -32, 0, 22)

-- The end screen: win or lose, with the run's numbers and Play Again.
local endScreen = makePanel(gui, "End", UDim2.new(0, 480, 0, 340), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
endScreen.Visible = false
local endTitle = makeLabel(endScreen, "Title", "", 38, UDim2.new(0.5, 0, 0, 24), Vector2.new(0.5, 0))
endTitle.Size = UDim2.new(1, 0, 0, 48)
local endStats = makeLabel(endScreen, "Stats", "", 18, UDim2.new(0.5, 0, 0, 84), Vector2.new(0.5, 0))
endStats.Size = UDim2.new(1, -48, 0, 120)
endStats.TextYAlignment = Enum.TextYAlignment.Top
local endBoard = makeLabel(endScreen, "Board", "", 16, UDim2.new(0.5, 0, 0, 210), Vector2.new(0.5, 0))
endBoard.Size = UDim2.new(1, -48, 0, 60)
endBoard.TextYAlignment = Enum.TextYAlignment.Top
local againButton = makeButton(endScreen, "Again", "↻  PLAY AGAIN", UDim2.new(0, 220, 0, 52), UDim2.new(0.5, 0, 1, -24), Vector2.new(0.5, 1))

-- Client state: what the server last told us, and the local clock.
local eggsFound = 0
local eggTotal = Config.EGG_TOTAL
local hearts = Config.MAX_HEARTS
local maxHearts = Config.MAX_HEARTS
local coins = 0
local roundStart = nil
local torchReadyAt = 0
local sprinting = false

local function fmtTime(sec)
	local m = math.floor(sec / 60)
	local s = math.floor(sec % 60)
	return string.format("%d:%02d", m, s)
end

local function drawHearts()
	local full = string.rep("❤", hearts)
	local empty = string.rep("🤍", math.max(0, maxHearts - hearts))
	heartLabel.Text = full .. empty
	-- One heart left: the counter turns red so the danger reads at once.
	heartLabel.TextColor3 = hearts <= 1 and Color3.fromRGB(255, 70, 60) or Config.PALETTE.uiText
end

-- The egg counter pulses when an egg lands, so the pickup reads even
-- while the player is running from a raptor.
local function pulseEggs()
	eggLabel.TextSize = 32
	task.spawn(function()
		task.wait(0.18)
		eggLabel.TextSize = 26
	end)
end

local function drawBoard(list, label)
	if #list == 0 then
		label.Text = "No wins yet. Be the first!"
		return
	end
	local lines = {}
	for i, row in ipairs(list) do
		table.insert(lines, string.format("%d. %s — %s", i, row.name, fmtTime(row.time)))
	end
	label.Text = table.concat(lines, "\n")
end

local function showHUD(show)
	hud.Visible = show
	shopButton.Visible = show
	hintLabel.Visible = show
	torchLabel.Visible = show
	radarLabel.Visible = show
end

local function startPlaying()
	menu.Visible = false
	endScreen.Visible = false
	showHUD(true)
	gameEvent:FireServer("playAgain")
	playPing(1.2)
end

playButton.MouseButton1Click:Connect(startPlaying)
againButton.MouseButton1Click:Connect(startPlaying)

shopButton.MouseButton1Click:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
	playPing(1)
end)
shopClose.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)

for _, row in ipairs(shopRows) do
	row.buy.MouseButton1Click:Connect(function()
		local id = row.buy:GetAttribute("ItemId")
		if not id then return end
		local ok, msg = shopBuy:InvokeServer(id)
		shopMsg.Text = msg or ""
		playPing(ok and 1.4 or 0.7)
	end)
end

local function fillShop(catalog)
	for i, item in ipairs(catalog) do
		local row = shopRows[i]
		if row then
			row.name.Text = string.format("%s — ⬢ %d", item.name, item.price)
			row.desc.Text = item.desc
			row.buy.Text = item.owned and "Owned" or "Buy"
			row.buy:SetAttribute("ItemId", item.id)
			row.buy.BackgroundColor3 = item.owned and Color3.fromRGB(120, 120, 110)
				or Config.PALETTE.uiAccent
		end
	end
end

local function flashDamage()
	flash.BackgroundTransparency = 0.35
	task.spawn(function()
		for i = 1, 10 do
			flash.BackgroundTransparency = 0.35 + (i / 10) * 0.65
			task.wait(0.05)
		end
		flash.BackgroundTransparency = 1
	end)
end

local function useTorch()
	local now = os.clock()
	if now < torchReadyAt then return end
	-- The wave starts at once on the client, even if no raptor is in
	-- range: the player sees the torch raise the moment they press F.
	torchWaveUntil = now + 1
	torchFlareUntil = now + 1
	gameEvent:FireServer("torch")
end

-- Torch: F key, or clicking the torch tool itself.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F then
		useTorch()
	end
end)

local function bindTorchTool()
	local backpack = player:WaitForChild("Backpack")
	local tool = backpack:WaitForChild("Torch", 10)
	if tool then
		tool.Activated:Connect(useTorch)
	end
end
task.spawn(bindTorchTool)

-- Sprint: hold SHIFT. The server still owns the base speed; sprint is
-- a client-side boost on top of whatever the server set.
RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local wantSprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	if wantSprint ~= sprinting then
		sprinting = wantSprint
		if sprinting then
			hum.WalkSpeed = Config.WALK_SPEED + 8
		else
			hum.WalkSpeed = Config.WALK_SPEED
		end
	end
	if roundStart then
		timerLabel.Text = fmtTime(os.clock() - roundStart)
	end
	animateTorch(os.clock(), 0)
	if torchReadyAt > 0 and os.clock() >= torchReadyAt then
		torchReadyAt = 0
		torchLabel.Text = "🔥 Torch ready [F]"
	end
end)

gameEvent.OnClientEvent:Connect(function(action, data)
	if action == "roundStart" then
		eggsFound = data.eggs or 0
		eggTotal = data.total or Config.EGG_TOTAL
		hearts = data.hearts or Config.MAX_HEARTS
		maxHearts = data.maxHearts or Config.MAX_HEARTS
		coins = data.coins or 0
		roundStart = os.clock()
		eggLabel.Text = string.format("🥚 %d/%d", eggsFound, eggTotal)
		coinLabel.Text = string.format("⬢ %d amber", coins)
		drawHearts()
		if data.shop then fillShop(data.shop) end
		-- Round opens with a roar and a warning banner: look for the
		-- red markers, the raptors are already out there.
		banner.Visible = true
		playRoar()
		task.spawn(function()
			task.wait(4)
			banner.Visible = false
		end)
	elseif action == "egg" then
		eggsFound = data.found
		eggLabel.Text = string.format("🥚 %d/%d", eggsFound, eggTotal)
		pulseEggs()
		playPing(1.5)
		-- Big centre flash + chime, so the pickup is unmistakable.
		eggFlash.Text = string.format("🥚 EGG FOUND! %d/%d", eggsFound, eggTotal)
		eggFlash.Visible = true
		task.spawn(function()
			task.wait(1.5)
			eggFlash.Visible = false
		end)
		task.spawn(function()
			task.wait(0.12)
			playPing(2.0)
		end)
	elseif action == "radar" then
		radarLabel.Text = string.format("⚠ RAPTOR %d studs — %s", data.dist, data.dir)
		radarLabel.TextColor3 = data.chasing and Color3.fromRGB(255, 70, 60)
			or Color3.fromRGB(255, 200, 90)
		radarLabel.Visible = true
	elseif action == "coin" then
		coins = data.coins
		coinLabel.Text = string.format("⬢ %d amber", coins)
		playPing(1.2)
	elseif action == "hearts" then
		hearts = data.hearts
		maxHearts = data.maxHearts
		drawHearts()
	elseif action == "caught" then
		hearts = data.hearts
		drawHearts()
		flashDamage()
		hintLabel.Text = "A raptor caught you! Back to camp — watch your hearts."
	elseif action == "torch" then
		if data.scared then
			torchReadyAt = os.clock() + (data.readyIn or Config.TORCH_COOLDOWN)
			torchLabel.Text = "🔥 Torch cooling down…"
			hintLabel.Text = "The raptor fled! Keep hunting."
			playPing(0.8)
		else
			hintLabel.Text = "No raptor close enough — save the torch."
		end
	elseif action == "shop" then
		coins = data.coins
		coinLabel.Text = string.format("⬢ %d amber", coins)
		if data.hearts then
			hearts = data.hearts
			maxHearts = data.maxHearts
			drawHearts()
		end
		if data.shop then fillShop(data.shop) end
	elseif action == "leaderboard" then
		drawBoard(data, boardList)
		drawBoard(data, endBoard)
	elseif action == "roundEnd" then
		roundStart = nil
		showHUD(false)
		shopPanel.Visible = false
		endTitle.Text = data.won and "🏆 YOU FOUND THEM ALL!" or "🦖 THE PACK GOT YOU"
		endTitle.TextColor3 = data.won and Config.PALETTE.amber or Color3.fromRGB(255, 90, 70)
		endStats.Text = string.format(
			"Eggs: %d/%d\nTime: %s\nAmber collected: %d",
			data.eggs, eggTotal, fmtTime(data.time), data.coins)
		drawBoard(data.leaderboard or {}, endBoard)
		endScreen.Visible = true
		playPing(data.won and 1.8 or 0.6)
	end
end)

drawHearts()
