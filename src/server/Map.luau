-- Map: builds the whole jungle island from parts, the same way every
-- time. One fixed seed, so the island a player explores is the island
-- the screenshots show and the code describes. Nothing here is random
-- at run time: the seed is set once, then every tree, fern and rock
-- lands on the same stud.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Map = {}

local SEED = 20261115
local ISLAND_SIZE = 220

local function part(parent, name, className, size, pos, color, material, anchored, collide)
	local p = Instance.new(className or "Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = anchored ~= false
	p.CanCollide = collide ~= false
	p.Parent = parent
	return p
end

local function tree(parent, pos, height, rng)
	local trunkH = height or (7 + rng:NextNumber() * 5)
	local trunk = part(parent, "Trunk", "Part", Vector3.new(1.4, trunkH, 1.4),
		pos + Vector3.new(0, trunkH / 2, 0), Config.PALETTE.trunk, Enum.Material.Wood)
	trunk.TopSurface = Enum.SurfaceType.Smooth
	local crownY = trunkH + 2
	local crown = part(parent, "Crown", "Part", Vector3.new(7, 5, 7),
		pos + Vector3.new(0, crownY, 0), Config.PALETTE.leaf, Enum.Material.Grass)
	crown.Shape = Enum.PartType.Ball
	local crown2 = part(parent, "CrownTop", "Part", Vector3.new(4.5, 3.5, 4.5),
		pos + Vector3.new(1, crownY + 2.5, -0.5), Config.PALETTE.leafLight, Enum.Material.Grass)
	crown2.Shape = Enum.PartType.Ball
	return trunk
end

local function fern(parent, pos, rng)
	local s = 1.6 + rng:NextNumber() * 1.4
	local f = part(parent, "Fern", "Part", Vector3.new(s, s * 1.6, s),
		pos + Vector3.new(0, s * 0.7, 0), Config.PALETTE.leafLight, Enum.Material.Grass)
	f.Shape = Enum.PartType.Ball
	return f
end

local function rock(parent, pos, rng)
	local s = 2 + rng:NextNumber() * 3
	local r = part(parent, "Rock", "Part", Vector3.new(s, s * 0.7, s),
		pos + Vector3.new(0, s * 0.3, 0), Config.PALETTE.rock, Enum.Material.Slate)
	r.Shape = Enum.PartType.Ball
	return r
end

local function ruin(parent, cx, cz)
	-- A broken stone circle: four pillars, two fallen, one lintel left.
	local base = part(parent, "RuinBase", "Part", Vector3.new(16, 1, 16),
		Vector3.new(cx, 0.5, cz), Config.PALETTE.ruin, Enum.Material.Concrete)
	for i, angle in ipairs({ 0, 90, 180, 270 }) do
		local rad = math.rad(angle)
		local px = cx + math.cos(rad) * 6
		local pz = cz + math.sin(rad) * 6
		local h = (i <= 2) and 7 or 3.5
		part(parent, "Pillar", "Part", Vector3.new(1.6, h, 1.6),
			Vector3.new(px, h / 2 + 1, pz), Config.PALETTE.ruin, Enum.Material.Concrete)
	end
	local lintel = part(parent, "Lintel", "Part", Vector3.new(13, 1.2, 1.6),
		Vector3.new(cx, 8.6, cz - 6), Config.PALETTE.ruin, Enum.Material.Concrete)
	lintel.Orientation = Vector3.new(0, 0, 4)
	return base
end

local function camp(parent)
	-- The camp: a wooden platform, a fire pit with a real light, a torch
	-- stand, and the spawn pad. Players start here and come back here
	-- after a raptor catches them.
	local cx, cz = Config.CAMP_SPAWN.X, Config.CAMP_SPAWN.Z
	part(parent, "CampPlatform", "Part", Vector3.new(14, 1, 14),
		Vector3.new(cx, 0.5, cz), Config.PALETTE.trunk, Enum.Material.WoodPlanks)
	for i = 1, 4 do
		local a = math.rad((i - 1) * 90 + 45)
		part(parent, "CampPost", "Part", Vector3.new(0.7, 4, 0.7),
			Vector3.new(cx + math.cos(a) * 6, 3, cz + math.sin(a) * 6),
			Config.PALETTE.trunk, Enum.Material.Wood)
	end
	local fire = part(parent, "FirePit", "Part", Vector3.new(3, 0.6, 3),
		Vector3.new(cx, 1.3, cz), Config.PALETTE.rock, Enum.Material.Slate)
	fire.Shape = Enum.PartType.Cylinder
	fire.Orientation = Vector3.new(0, 0, 90)
	local flame = part(parent, "Flame", "Part", Vector3.new(1.4, 2.2, 1.4),
		Vector3.new(cx, 2.6, cz), Config.PALETTE.campfire, Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = 22
	light.Brightness = 2
	light.Parent = flame
	local pad = part(parent, "SpawnPad", "Part", Vector3.new(6, 0.4, 6),
		Vector3.new(cx, 1.2, cz), Config.PALETTE.sand, Enum.Material.Sand)
	pad.CanCollide = false
	return pad
end

-- A nest: a ring of leaves and twigs that marks an egg spot from afar.
function Map.buildNest(parent, pos)
	local nest = Instance.new("Folder")
	nest.Name = "Nest"
	nest.Parent = parent
	for i = 1, 6 do
		local a = math.rad((i - 1) * 60)
		part(nest, "NestLeaf", "Part", Vector3.new(1.6, 0.5, 0.7),
			pos + Vector3.new(math.cos(a) * 1.6, 0.3, math.sin(a) * 1.6),
			Config.PALETTE.leaf, Enum.Material.Grass).Orientation = Vector3.new(0, (i - 1) * 60, 0)
	end
	part(nest, "NestBase", "Part", Vector3.new(3, 0.4, 3),
		pos + Vector3.new(0, 0.2, 0), Config.PALETTE.eggSpot, Enum.Material.Sand).Shape =
		Enum.PartType.Cylinder
	return nest
end

function Map.build(workspace)
	local rng = Random.new(SEED)
	local island = Instance.new("Folder")
	island.Name = "Island"
	island.Parent = workspace

	-- Ground: one grass slab for the island, sand at the water's edge.
	part(island, "Ground", "Part", Vector3.new(ISLAND_SIZE, 4, ISLAND_SIZE),
		Vector3.new(0, -2, 0), Config.PALETTE.grass, Enum.Material.Grass)
	part(island, "Beach", "Part", Vector3.new(ISLAND_SIZE + 24, 1, ISLAND_SIZE + 24),
		Vector3.new(0, -3.4, 0), Config.PALETTE.sand, Enum.Material.Sand)

	-- The river: a blue strip across the east side, shallow and walkable.
	local river = part(island, "River", "Part", Vector3.new(14, 0.4, ISLAND_SIZE),
		Vector3.new(95, 0.3, 0), Config.PALETTE.water, Enum.Material.Water)
	river.CanCollide = false
	local lake = part(island, "Lake", "Part", Vector3.new(34, 0.4, 30),
		Vector3.new(-60, 0.3, -60), Config.PALETTE.water, Enum.Material.Water)
	lake.Shape = Enum.PartType.Cylinder
	lake.Orientation = Vector3.new(0, 0, 90)
	lake.CanCollide = false

	-- A low hill in the north, for a vantage point over the island.
	local hill = part(island, "Hill", "Part", Vector3.new(46, 10, 40),
		Vector3.new(0, 2, -85), Config.PALETTE.grass, Enum.Material.Grass)
	hill.Shape = Enum.PartType.Ball

	-- Trees: forty of them, kept clear of the camp, the river and the nests.
	local keepClear = { Config.CAMP_SPAWN }
	for _, s in ipairs(Config.EGG_SPOTS) do table.insert(keepClear, s) end
	local placed = 0
	local guard = 0
	while placed < 40 and guard < 600 do
		guard += 1
		local x = rng:NextNumber(-100, 100)
		local z = rng:NextNumber(-100, 100)
		local ok = math.abs(x - 95) > 12
		for _, c in ipairs(keepClear) do
			if (Vector3.new(x, 0, z) - Vector3.new(c.X, 0, c.Z)).Magnitude < 9 then ok = false end
		end
		if ok then
			tree(island, Vector3.new(x, 0, z), nil, rng)
			placed += 1
		end
	end

	-- Ferns and rocks: the undergrowth that makes it a jungle, not a lawn.
	for _ = 1, 34 do
		fern(island, Vector3.new(rng:NextNumber(-100, 100), 0, rng:NextNumber(-100, 100)), rng)
	end
	for _ = 1, 16 do
		rock(island, Vector3.new(rng:NextNumber(-100, 100), 0, rng:NextNumber(-100, 100)), rng)
	end

	-- Four ruins, one per quarter of the island, each guarding an egg.
	ruin(island, 55, -55)
	ruin(island, -55, 45)
	ruin(island, 60, 55)
	ruin(island, -60, -20)

	camp(island)

	-- The spawn pad: players appear on it, facing the island.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CampSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(Config.CAMP_SPAWN.X, 1.5, Config.CAMP_SPAWN.Z)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = island

	return island
end

return Map
