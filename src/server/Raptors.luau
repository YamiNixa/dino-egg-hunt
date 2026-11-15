-- Raptors: the pack. Three raptors built from parts, each with its own
-- little brain: patrol its home clearing, chase the nearest player it
-- can see, catch them with a touch, and run from a lit torch. A raptor
-- never dies; the torch is the only thing that makes it back off.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Raptors = {}
Raptors.list = {}

local function buildRaptorModel(home, index)
	-- Local space: the model's origin is on the ground, forward is -Z.
	-- Torso rides at y 2.0, legs reach the ground, head and snout lead.
	local model = Instance.new("Model")
	model.Name = "Raptor" .. index

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.2, 1.6, 3.6)
	torso.Position = Vector3.new(0, 2.0, 0)
	torso.Color = Config.PALETTE.raptor
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = false
	torso.CanCollide = true
	torso.Parent = model

	local belly = Instance.new("Part")
	belly.Name = "Belly"
	belly.Size = Vector3.new(1.8, 1.0, 3.0)
	belly.Position = Vector3.new(0, 1.6, -0.3)
	belly.Color = Config.PALETTE.raptorBelly
	belly.Material = Enum.Material.SmoothPlastic
	belly.Anchored = false
	belly.CanCollide = false
	belly.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.6, 1.4, 2.2)
	head.Position = Vector3.new(0, 2.7, -2.4)
	head.Color = Config.PALETTE.raptor
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = false
	head.CanCollide = true
	head.Parent = model

	local snout = Instance.new("Part")
	snout.Name = "Snout"
	snout.Size = Vector3.new(1.0, 0.7, 1.4)
	snout.Position = Vector3.new(0, 2.4, -3.7)
	snout.Color = Config.PALETTE.raptor
	snout.Material = Enum.Material.SmoothPlastic
	snout.Anchored = false
	snout.CanCollide = false
	snout.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.3, 0.3, 0.3)
		eye.Position = Vector3.new(0.5 * side, 3.0, -3.3)
		eye.Color = Color3.fromRGB(255, 40, 30)
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.Parent = model
		eye:SetAttribute("EyeSide", side)
	end

	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.8, 0.8, 3.4)
	tail.Position = Vector3.new(0, 2.2, 3.2)
	tail.Color = Config.PALETTE.raptor
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = false
	tail.CanCollide = false
	tail.Parent = model

	for _, side in ipairs({ -1, 1 }) do
		local leg = Instance.new("Part")
		leg.Name = "Leg"
		leg.Size = Vector3.new(0.7, 2.0, 0.9)
		leg.Position = Vector3.new(0.7 * side, 1.0, 0)
		leg.Color = Color3.fromRGB(70, 95, 45)
		leg.Material = Enum.Material.SmoothPlastic
		leg.Anchored = false
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
	return model
end

local function poseRaptor(raptor, pos, facing)
	local m = raptor.model
	-- The model's origin sits on the ground; the parts ride above it.
	local cf = CFrame.new(pos) * CFrame.Angles(0, facing, 0)
	m:PivotTo(cf)
end

function Raptors.spawnAll(workspace)
	Raptors.list = {}
	for i = 1, Config.RAPTOR_COUNT do
		local home = Config.RAPTOR_HOMES[i]
		local model = buildRaptorModel(home, i)
		model.Parent = workspace
		local raptor = {
			model = model,
			home = home,
			state = "patrol",
			target = nil,
			waypoint = home,
			speed = Config.RAPTOR_PATROL_SPEED,
			scareUntil = 0,
			biteCooldown = 0,
			walkPhase = math.random() * 6,
		}
		poseRaptor(raptor, home, math.rad(45 * i))
		table.insert(Raptors.list, raptor)
	end
end

function Raptors.nearestPlayerPos(raptor, players)
	local best = nil
	local bestDist = Config.RAPTOR_SPOT_RANGE
	local rp = raptor.model.PrimaryPart.Position
	for _, player in ipairs(players) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
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

function Raptors.update(dt, now, players, onCatch)
	for _, raptor in ipairs(Raptors.list) do
		local root = raptor.model.PrimaryPart
		local pos = root.Position

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
				local r = math.random() * Config.RAPTOR_PATROL_RADIUS
				raptor.waypoint = raptor.home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			end
			moveTarget = raptor.waypoint
			local player, _ = Raptors.nearestPlayerPos(raptor, players)
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
				next = Vector3.new(
					math.clamp(next.X, -105, 105),
					0,
					math.clamp(next.Z, -105, 105)
				)
				local facing = math.atan2(-dir.X, -dir.Z)
				poseRaptor(raptor, next, facing)
				-- A little bob while it runs, so it reads as alive, not sliding.
				raptor.walkPhase += dt * (speed * 0.9)
				local bob = math.abs(math.sin(raptor.walkPhase)) * 0.25
				raptor.model.PrimaryPart.Position += Vector3.new(0, bob, 0)
			end
		end
	end
end

return Raptors
