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

local function tree(parent, pos, height, rng, giant)
	-- Trees are big now: trunks 12-20 studs, crowns 12-16 across, so
	-- the jungle reads as a jungle, not a lawn with twigs. A giant
	-- tree gets a 4-stud trunk and a 20-stud crown.
	local trunkH = height or (12 + rng:NextNumber() * 8)
	local trunkW = giant and 4 or 2.4
	local crownS = giant and 20 or (11 + rng:NextNumber() * 5)
	local trunk = part(parent, "Trunk", "Part", Vector3.new(trunkW, trunkH, trunkW),
		pos + Vector3.new(0, trunkH / 2, 0), Config.PALETTE.trunk, Enum.Material.Wood)
	trunk.TopSurface = Enum.SurfaceType.Smooth
	local crownY = trunkH + crownS * 0.35
	local crown = part(parent, "Crown", "Part", Vector3.new(crownS, crownS * 0.65, crownS),
		pos + Vector3.new(0, crownY, 0), Config.PALETTE.leaf, Enum.Material.Grass)
	crown.Shape = Enum.PartType.Ball
	local crown2 = part(parent, "CrownTop", "Part", Vector3.new(crownS * 0.6, crownS * 0.45, crownS * 0.6),
		pos + Vector3.new(1, crownY + crownS * 0.3, -0.5), Config.PALETTE.leafLight, Enum.Material.Grass)
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
		part(nest, "NestLeaf", "Part", Vector3.new(2.4, 0.6, 1.0),
			pos + Vector3.new(math.cos(a) * 2.4, 0.3, math.sin(a) * 2.4),
			Config.PALETTE.leaf, Enum.Material.Grass).Orientation = Vector3.new(0, (i - 1) * 60, 0)
	end
	part(nest, "NestBase", "Part", Vector3.new(4.2, 0.4, 4.2),
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

	-- Trees: seventy of them, kept clear of the camp, the river and the nests.
	local keepClear = { Config.CAMP_SPAWN }
	for _, s in ipairs(Config.EGG_SPOTS) do table.insert(keepClear, s) end
	local placed = 0
	local guard = 0
	while placed < 70 and guard < 1000 do
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

	-- Four hero trees, giants at the island's corners, so the skyline
	-- has landmarks instead of one flat canopy line.
	tree(island, Vector3.new(-90, 0, -80), 26 + rng:NextNumber() * 4, rng, true)
	tree(island, Vector3.new(80, 0, 78), 28 + rng:NextNumber() * 4, rng, true)
	tree(island, Vector3.new(-10, 0, 88), 26 + rng:NextNumber() * 4, rng, true)
	tree(island, Vector3.new(8, 0, -95), 30 + rng:NextNumber() * 4, rng, true)

	-- Ferns and rocks: the undergrowth that makes it a jungle, not a lawn.
	for _ = 1, 60 do
		fern(island, Vector3.new(rng:NextNumber(-100, 100), 0, rng:NextNumber(-100, 100)), rng)
	end
	for _ = 1, 28 do
		rock(island, Vector3.new(rng:NextNumber(-100, 100), 0, rng:NextNumber(-100, 100)), rng)
	end

	-- Grass tufts and wildflowers, so the ground is a jungle floor,
	-- not one flat slab of green.
	local tuftColors = { Config.PALETTE.leafLight, Config.PALETTE.amber, Config.PALETTE.flower }
	for _ = 1, 70 do
		local s = 0.8 + rng:NextNumber() * 0.8
		local tuft = part(island, "Tuft", "Part", Vector3.new(s, s * 1.2, s),
			Vector3.new(rng:NextNumber(-105, 105), s * 0.5, rng:NextNumber(-105, 105)),
			tuftColors[1 + math.floor(rng:NextNumber() * 3)], Enum.Material.Grass)
		tuft.Shape = Enum.PartType.Ball
		tuft.CanCollide = false
	end

	-- The horizon is not empty anymore: mesas ring the island far out,
	-- so the world feels like a valley, not a void.
	for i = 1, 8 do
		local a = math.rad((i - 1) * 45 + 20)
		local r = 180 + rng:NextNumber() * 35
		local w = 40 + rng:NextNumber() * 20
		local h = 40 + rng:NextNumber() * 40
		local mesa = part(island, "Mesa", "Part", Vector3.new(w, h, w * 0.7),
			Vector3.new(math.cos(a) * r, h / 2 - 4, math.sin(a) * r),
			Config.PALETTE.mountain, Enum.Material.Slate)
		mesa.CanCollide = false
		local cap = part(island, "MesaCap", "Part", Vector3.new(w * 0.7, h * 0.25, w * 0.5),
			Vector3.new(math.cos(a) * r, h - 4 + h * 0.1, math.sin(a) * r),
			Config.PALETTE.leaf, Enum.Material.Grass)
		cap.CanCollide = false
	end

	-- Clouds drift high over the island so the sky is not a flat dome.
	for _ = 1, 6 do
		local a = math.rad(rng:NextNumber(0, 360))
		local r = rng:NextNumber(40, 150)
		local cy = 65 + rng:NextNumber() * 25
		local cx, cz = math.cos(a) * r, math.sin(a) * r
		for _, off in ipairs({ Vector3.new(0, 0, 0), Vector3.new(-9, -1.5, 2), Vector3.new(9, -1, -2) }) do
			local puff = part(island, "Cloud", "Part", Vector3.new(16, 6, 12),
				Vector3.new(cx, cy, cz) + off, Config.PALETTE.cloud, Enum.Material.SmoothPlastic)
			puff.Shape = Enum.PartType.Ball
			puff.CanCollide = false
		end
	end

	-- Low hills just past the beach, outside the play area, so the
	-- island sits in rolling land instead of on a flat slab.
	for _, hp in ipairs({ Vector3.new(-142, 0, -40), Vector3.new(142, 0, 60), Vector3.new(20, 0, 148) }) do
		local outer = part(island, "OuterHill", "Part", Vector3.new(60, 14, 50),
			Vector3.new(hp.X, 1, hp.Z), Config.PALETTE.grass, Enum.Material.Grass)
		outer.Shape = Enum.PartType.Ball
		outer.CanCollide = false
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
