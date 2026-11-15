-- Raptors: the pack. Three raptors built from parts, each with its own
-- little brain: patrol its home clearing, chase the nearest player it
-- can see, catch them with a touch, and run from a lit torch. A raptor
-- never dies; the torch is the only thing that makes it back off.

local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Raptors = {}
Raptors.list = {}

-- The ground the raptors walk on is NOT flat: the island is a grass
-- slab (top y 0) with a hill ball in the north (top y 7, spans
-- x -23..23, z -105..-65), ruin bases (top y 1) and the camp platform
-- (top y 1). The old code pivoted every raptor to a FIXED y 5.0, so
-- raptor 3 — home (0, -55), patrol radius 26 — walked onto the hill
-- and sank up to 5 studs into it: torso (3.4..6.6) under a hill surface
-- at y ~6.3, only the head and the AlwaysOnTop "!" showing. The fix is
-- to raycast the real ground under the raptor every time it is posed.
local GROUND_NAMES = {
	Ground = true, Beach = true, Hill = true, RuinBase = true,
	CampPlatform = true, SpawnPad = true, NestBase = true,
	Lake = true, River = true,
}
local groundParams = nil

local function collectGroundParts(workspace)
	local parts = {}
	local island = workspace:FindFirstChild("Island")
	local root = island or workspace
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and GROUND_NAMES[d.Name] then
			table.insert(parts, d)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	groundParams = params
end

-- The y of the walkable ground under (x, z). Falls back to 0 (the grass
-- slab) if nothing is hit, so a raptor is never left floating or buried
-- by a missing part.
local function groundYAt(x, z)
	if groundParams then
		local result = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), groundParams)
		if result then return result.Position.Y end
	end
	return 0
end

local function buildRaptorModel(home, index)
	-- Local space: the model's origin is on the ground, forward is -Z.
	-- Torso rides at y 2.0, legs reach the ground, head and snout lead.
	-- Raptor 1 is the SHOWCASE (home in front of camp): vivid orange,
	-- so it reads as a dino at a glance and can never blend into the
	-- green jungle. The other two keep the brown pack palette.
	local body = Config.PALETTE.raptor
	local bellyC = Config.PALETTE.raptorBelly
	local stripeC = Config.PALETTE.raptorStripe
	local legC = Config.PALETTE.raptorLeg
	if index == 1 then
		body = Config.PALETTE.raptorShow
		bellyC = Config.PALETTE.raptorShowBelly
		stripeC = Config.PALETTE.raptorShowStripe
		legC = Config.PALETTE.raptorShowLeg
	end
	local model = Instance.new("Model")
	model.Name = "Raptor" .. index

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.2, 1.6, 3.6)
	torso.Position = Vector3.new(0, 2.0, 0)
	torso.Color = body
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = true
	torso.CanCollide = true
	torso.Parent = model

	local belly = Instance.new("Part")
	belly.Name = "Belly"
	belly.Size = Vector3.new(1.8, 1.0, 3.0)
	belly.Position = Vector3.new(0, 1.6, -0.3)
	belly.Color = bellyC
	belly.Material = Enum.Material.SmoothPlastic
	belly.Anchored = true
	belly.CanCollide = false
	belly.Parent = model

	-- Dark back stripes, so the brown body reads as a dino, not a box.
	for i, zOff in ipairs({ -1.2, 0, 1.2 }) do
		local stripe = Instance.new("Part")
		stripe.Name = "Stripe"
		stripe.Size = Vector3.new(2.3, 0.25, 0.5)
		stripe.Position = Vector3.new(0, 2.78, zOff)
		stripe.Color = stripeC
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.Anchored = true
		stripe.CanCollide = false
		stripe.Parent = model
	end

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.6, 1.4, 2.2)
	head.Position = Vector3.new(0, 2.7, -2.4)
	head.Color = body
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = true
	head.Parent = model

	local snout = Instance.new("Part")
	snout.Name = "Snout"
	snout.Size = Vector3.new(1.0, 0.7, 1.4)
	snout.Position = Vector3.new(0, 2.4, -3.7)
	snout.Color = body
	snout.Material = Enum.Material.SmoothPlastic
	snout.Anchored = true
	snout.CanCollide = false
	snout.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.45, 0.45, 0.45)
		eye.Position = Vector3.new(0.5 * side, 3.0, -3.3)
		eye.Color = Color3.fromRGB(255, 40, 30)
		eye.Material = Enum.Material.Neon
		eye.Anchored = true
		eye.CanCollide = false
		eye.Parent = model
		eye:SetAttribute("EyeSide", side)
	end

	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.8, 0.8, 3.4)
	tail.Position = Vector3.new(0, 2.2, 3.2)
	tail.Color = body
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = true
	tail.CanCollide = false
	tail.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local leg = Instance.new("Part")
		leg.Name = "Leg"
		leg.Size = Vector3.new(0.7, 2.0, 0.9)
		leg.Position = Vector3.new(0.7 * side, 1.0, 0)
		leg.Color = legC
		leg.Material = Enum.Material.SmoothPlastic
		leg.Anchored = true
		leg.CanCollide = true
		leg.Parent = model
		leg:SetAttribute("LegSide", side)
	end

	-- Weld it all to the torso so the model moves as one body.
	for _, p in ipairs(model:GetChildren()) do
		if p ~= torso and p:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = p
			w.Parent = torso
		end
	end
	model.PrimaryPart = torso

	-- A red "!" that floats over the head only while this raptor is
	-- chasing a player, so the hunt is never a surprise.
	local marker = Instance.new("BillboardGui")
	marker.Name = "ChaseMarker"
	marker.Adornee = head
	marker.Size = UDim2.new(4, 0, 4, 0)
	marker.StudsOffset = Vector3.new(0, 3.4, 0)
	marker.AlwaysOnTop = true
	marker.Enabled = false
	marker.Parent = head
	local mark = Instance.new("TextLabel")
	mark.Name = "Mark"
	mark.Size = UDim2.new(1, 0, 1, 0)
	mark.BackgroundTransparency = 1
	mark.Text = "!"
	mark.TextColor3 = Color3.fromRGB(255, 60, 50)
	mark.TextScaled = true
	mark.Font = Enum.Font.GothamBlack
	mark.Parent = marker

	-- A BIG red "!" that floats over the head ALWAYS, so a raptor is
	-- visible from the spawn point the moment the round starts. It
	-- stays on while chasing too — the chase "!" above pulses bigger
	-- instead, so a raptor is never invisible mid-chase.
	local dot = Instance.new("BillboardGui")
	dot.Name = "DotMarker"
	dot.Adornee = head
	dot.Size = UDim2.new(3.5, 0, 3.5, 0)
	dot.StudsOffset = Vector3.new(0, 3.4, 0)
	dot.AlwaysOnTop = true
	dot.Parent = head
	local dotText = Instance.new("TextLabel")
	dotText.Name = "Dot"
	dotText.Size = UDim2.new(1, 0, 1, 0)
	dotText.BackgroundTransparency = 1
	dotText.Text = "!"
	dotText.TextColor3 = Color3.fromRGB(255, 60, 50)
	dotText.TextScaled = true
	dotText.Font = Enum.Font.GothamBlack
	dotText.Parent = dot

	-- The whole raptor reads BIG: 2x, so it is impossible to miss.
	model:ScaleTo(2.0)
	return model
end

local function poseRaptor(raptor, pos, facing, bob)
	local m = raptor.model
	-- The model's pivot IS the torso (PrimaryPart). After the 2x scale
	-- the legs reach 4.0 below the pivot (leg centre pivot - 2.0, half
	-- height 2.0), so the pivot must sit at ground + 4.0 for the feet
	-- to touch the ground. The ground height is RAYCAST, not fixed:
	-- the old fixed y 5.0 was right on the flat slab (ground y 0) but
	-- buried raptor 3 on the hill (ground up to y 7), and floated the
	-- pack 1 stud over the slab. Parts are anchored, so physics can
	-- never drag the model down; PivotTo is the only mover, and the bob
	-- rides in the CFrame so the whole welded body bobs together
	-- instead of the torso detaching.
	local groundY = groundYAt(pos.X, pos.Z)
	local cf = CFrame.new(pos.X, groundY + 4.0 + (bob or 0), pos.Z) * CFrame.Angles(0, facing, 0)
	m:PivotTo(cf)
end

function Raptors.spawnAll(workspace)
	Raptors.list = {}
	collectGroundParts(workspace)
	for i = 1, Config.RAPTOR_COUNT do
		local home = Config.RAPTOR_HOMES[i]
		local model = buildRaptorModel(home, i)
		model.Parent = workspace
		local head = model:FindFirstChild("Head")
		local marker = head and head:FindFirstChild("ChaseMarker") or nil
		local dot = head and head:FindFirstChild("DotMarker") or nil
		local raptor = {
			model = model,
			marker = marker,
			dot = dot,
			home = home,
			state = "patrol",
			target = nil,
			waypoint = home,
			speed = Config.RAPTOR_PATROL_SPEED,
			scareUntil = 0,
			biteCooldown = 0,
			walkPhase = math.random() * 6,
			-- Raptor 1 patrols a tight circle (5 studs) around its
			-- showcase home in front of camp; the others use the
			-- config radius (10) around their own clearings.
			patrolRadius = (i == 1) and 5 or Config.RAPTOR_PATROL_RADIUS,
			-- Raptor 1 holds at its showcase spot facing camp for the
			-- first seconds of the round, so the opening view is a
			-- dino, not an empty lawn.
			holdUntil = (i == 1) and (os.clock() + Config.RAPTOR_SHOWCASE_HOLD_SECONDS) or 0,
		}
		-- Raptors start FACING the camp, so the player sees a head, a
		-- snout and glowing eyes from the spawn point — not a brown
		-- box from the side. Patrol takes over the facing right away.
		local dir = Config.CAMP_SPAWN - home
		poseRaptor(raptor, home, math.atan2(-dir.X, -dir.Z))
		table.insert(Raptors.list, raptor)
	end
end

function Raptors.nearestPlayerPos(raptor, players, grace)
	local best = nil
	local bestDist = Config.RAPTOR_SPOT_RANGE
	local rp = raptor.model.PrimaryPart.Position
	for _, player in ipairs(players) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and not (grace and grace[player]) then
			local d = (root.Position - rp).Magnitude
			if d < bestDist then
				bestDist = d
				best = player
			end
		end
	end
	return best, bestDist
end

function Raptors.scareNearest(player, now)
	-- The torch: the nearest raptor inside torch range flees for a while.
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local best = nil
	local bestDist = Config.TORCH_RANGE
	for _, raptor in ipairs(Raptors.list) do
		local d = (raptor.model.PrimaryPart.Position - root.Position).Magnitude
		if d < bestDist then
			bestDist = d
			best = raptor
		end
	end
	if best then
		best.state = "scared"
		best.scareUntil = now + Config.TORCH_SCARE_SECONDS
		return true
	end
	return false
end

-- The radar: nearest raptor to a player, with its direction relative to
-- where the player is facing (the camera looks the same way in third
-- person), so the HUD can warn "RAPTOR 14 studs — BEHIND YOU".
function Raptors.nearestRadar(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local best = nil
	local bestDist = math.huge
	for _, raptor in ipairs(Raptors.list) do
		local d = (raptor.model.PrimaryPart.Position - root.Position).Magnitude
		if d < bestDist then
			bestDist = d
			best = raptor
		end
	end
	if not best then return nil end
	local to = best.model.PrimaryPart.Position - root.Position
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local f = Vector3.new(to.X, 0, to.Z):Dot(Vector3.new(look.X, 0, look.Z))
	local s = Vector3.new(to.X, 0, to.Z):Dot(Vector3.new(right.X, 0, right.Z))
	local dir = "AHEAD"
	if math.abs(f) >= math.abs(s) then
		dir = f >= 0 and "AHEAD" or "BEHIND YOU"
	else
		dir = s > 0 and "RIGHT" or "LEFT"
	end
	return { dist = math.floor(bestDist), dir = dir, chasing = best.state == "chase" }
end

function Raptors.update(dt, now, players, onCatch, grace)
	for _, raptor in ipairs(Raptors.list) do
		local root = raptor.model.PrimaryPart
		local pos = root.Position

		if raptor.holdUntil and now < raptor.holdUntil then
			-- Opening showcase: raptor 1 stands at its home in front
			-- of camp, facing the player, for the first seconds of the
			-- round — inside the 10s grace, so it cannot attack yet.
			-- It does not patrol away before the player has seen it.
			local dir = Config.CAMP_SPAWN - raptor.home
			local bob = math.abs(math.sin(now * 2)) * 0.15
			poseRaptor(raptor, raptor.home, math.atan2(-dir.X, -dir.Z), bob)
		else
		if raptor.state == "scared" and now >= raptor.scareUntil then
			raptor.state = "patrol"
		end

		local moveTarget = nil
		local speed = Config.RAPTOR_PATROL_SPEED

		if raptor.state == "scared" then
			-- Flee: run away from the home clearing's centre, then calm down.
			moveTarget = raptor.home + (pos - raptor.home).Unit * 30
			speed = Config.RAPTOR_CHASE_SPEED
		elseif raptor.state == "chase" then
			local target = raptor.target
			local tRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if not tRoot then
				raptor.state = "patrol"
				raptor.target = nil
			else
				local d = (tRoot.Position - pos).Magnitude
				if d > Config.RAPTOR_SPOT_RANGE + 12 then
					raptor.state = "patrol"
					raptor.target = nil
				else
					moveTarget = tRoot.Position
					speed = Config.RAPTOR_CHASE_SPEED
					if d <= Config.RAPTOR_CATCH_RANGE and now >= raptor.biteCooldown then
						raptor.biteCooldown = now + 2
						onCatch(target)
					end
				end
			end
		else
			-- Patrol: walk to the waypoint, then pick a new one near home.
			local d = (raptor.waypoint - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			if d < 3 then
				local a = math.random() * math.pi * 2
				local r = math.random() * raptor.patrolRadius
				raptor.waypoint = raptor.home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			end
			moveTarget = raptor.waypoint
			local player, _ = Raptors.nearestPlayerPos(raptor, players, grace)
			if player then
				raptor.state = "chase"
				raptor.target = player
			end
		end

		if moveTarget then
			local dir = moveTarget - Vector3.new(pos.X, 0, pos.Z)
			dir = Vector3.new(dir.X, 0, dir.Z)
			if dir.Magnitude > 0.1 then
				local step = dir.Unit * speed * dt
				local next = Vector3.new(pos.X, 0, pos.Z) + step
				-- The y here is ignored: poseRaptor raycasts the real
				-- ground under (x, z) and stands the raptor on it.
				next = Vector3.new(
					math.clamp(next.X, -105, 105),
					0,
					math.clamp(next.Z, -105, 105)
				)
				local facing = math.atan2(-dir.X, -dir.Z)
				-- A little bob while it runs, so it reads as alive, not sliding.
				raptor.walkPhase += dt * (speed * 0.9)
				local bob = math.abs(math.sin(raptor.walkPhase)) * 0.25
				poseRaptor(raptor, next, facing, bob)
			end
		end
		end
		if raptor.marker then
			raptor.marker.Enabled = (raptor.state == "chase")
			-- Pulse bigger while chasing, instead of the always-on
			-- marker hiding: a raptor is never invisible mid-chase.
			if raptor.state == "chase" then
				local s = 4 + 0.8 * math.abs(math.sin(now * 6))
				raptor.marker.Size = UDim2.new(s, 0, s, 0)
			end
		end
		if raptor.dot then
			raptor.dot.Enabled = true
		end
	end
end

return Raptors
