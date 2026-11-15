-- Config: every number the game balances on, in one place so the server
-- and the client always agree. Egg spots, raptor stats, shop prices and
-- the island layout live here; no other script hard-codes them.

local Config = {}

-- The hunt: ten eggs, one win.
Config.EGG_TOTAL = 10
Config.EGG_SPOTS = {
	Vector3.new(60, 1, -70),
	Vector3.new(-55, 1, -60),
	Vector3.new(75, 1, 10),
	Vector3.new(-70, 1, 25),
	Vector3.new(20, 1, -75),
	Vector3.new(-20, 1, 70),
	Vector3.new(45, 1, 60),
	Vector3.new(-45, 1, -25),
	Vector3.new(0, 1, -35),
	Vector3.new(85, 1, -35),
}

-- Amber coins: 24 of them, 10 coins each, for the shop.
Config.COIN_TOTAL = 24
Config.COIN_VALUE = 10
Config.COIN_SPOTS = {
	Vector3.new(30, 1, -50), Vector3.new(-30, 1, -45), Vector3.new(55, 1, 35),
	Vector3.new(-60, 1, 50), Vector3.new(10, 1, -60), Vector3.new(-10, 1, 55),
	Vector3.new(70, 1, -10), Vector3.new(-75, 1, -5), Vector3.new(0, 1, 15),
	Vector3.new(40, 1, -20), Vector3.new(-40, 1, 10), Vector3.new(25, 1, 75),
	Vector3.new(-25, 1, -70), Vector3.new(65, 1, 65), Vector3.new(-65, 1, -35),
	Vector3.new(15, 1, 40), Vector3.new(-15, 1, -15), Vector3.new(50, 1, -55),
	Vector3.new(-50, 1, 65), Vector3.new(80, 1, 25), Vector3.new(-80, 1, 0),
	Vector3.new(5, 1, -25), Vector3.new(-5, 1, 25), Vector3.new(35, 1, 5),
}

-- The camp: where players spawn and respawn after a catch.
Config.CAMP_SPAWN = Vector3.new(-80, 3, 80)

-- The pack: three raptors, each with a home clearing to patrol from.
Config.RAPTOR_COUNT = 3
Config.RAPTOR_HOMES = {
	Vector3.new(-65, 1, 65),
	Vector3.new(-35, 1, 30),
	Vector3.new(0, 1, -55),
}
Config.RAPTOR_PATROL_SPEED = 8
Config.RAPTOR_CHASE_SPEED = 16
Config.RAPTOR_SPOT_RANGE = 42
Config.RAPTOR_CATCH_RANGE = 4
Config.RAPTOR_PATROL_RADIUS = 26
-- Grace: raptors do not engage a player in their first 10 seconds of a
-- round, so the player sees them patrolling with their red markers
-- before anything can catch them from behind.
Config.RAPTOR_GRACE_SECONDS = 10

-- The player: three hearts, walk 16, sprint 24.
Config.MAX_HEARTS = 3
Config.WALK_SPEED = 16
Config.SPRINT_SPEED = 24
Config.INVULNERABLE_SECONDS = 3

-- The torch: scares the nearest raptor inside 14 studs, 8 second cooldown.
Config.TORCH_RANGE = 14
Config.TORCH_COOLDOWN = 8
Config.TORCH_SCARE_SECONDS = 4

-- The shop: one speed boost, one extra heart, one torch refill per round.
Config.SHOP = {
	{ id = "speed", name = "Swift Boots", price = 60, desc = "+4 walk speed this round" },
	{ id = "heart", name = "Extra Heart", price = 100, desc = "+1 max heart this round" },
	{ id = "torch", name = "Torch Oil", price = 30, desc = "Torch ready at once" },
}

-- Rounds: first to all ten eggs wins; the clock decides the leaderboard.
Config.ROUND_TIME_LIMIT = 600

-- The palette: one jungle-dusk set, used by the map, the raptors and the UI.
Config.PALETTE = {
	grass = Color3.fromRGB(104, 158, 74),
	leaf = Color3.fromRGB(64, 138, 60),
	leafLight = Color3.fromRGB(116, 178, 84),
	trunk = Color3.fromRGB(116, 84, 50),
	rock = Color3.fromRGB(128, 128, 126),
	ruin = Color3.fromRGB(150, 142, 124),
	sand = Color3.fromRGB(196, 178, 132),
	water = Color3.fromRGB(48, 120, 170),
	egg = Color3.fromRGB(240, 232, 210),
	eggSpot = Color3.fromRGB(190, 150, 90),
	amber = Color3.fromRGB(255, 176, 32),
	raptor = Color3.fromRGB(120, 70, 45),
	raptorBelly = Color3.fromRGB(214, 202, 150),
	raptorStripe = Color3.fromRGB(60, 35, 20),
	raptorLeg = Color3.fromRGB(70, 40, 25),
	campfire = Color3.fromRGB(255, 140, 40),
	flower = Color3.fromRGB(255, 150, 190),
	mountain = Color3.fromRGB(112, 98, 88),
	cloud = Color3.fromRGB(245, 240, 228),
	uiPanel = Color3.fromRGB(24, 30, 20),
	uiAccent = Color3.fromRGB(255, 176, 32),
	uiText = Color3.fromRGB(240, 238, 220),
}

-- Egg nests: each spot gets a ring of leaves so the nest reads at a glance.
function Config.nestSpots()
	return Config.EGG_SPOTS
end

return Config
