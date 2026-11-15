-- DINO EGG HUNT, server entrypoint: build the island, wake the pack,
-- and open the hunt. Everything the game is lives in the modules this
-- file requires; this file only starts them, in order.
--
-- If a service the game needs is missing, fail loudly here instead of
-- letting the hunt start half-built: a server with no island is worse
-- than a server that says so in its log.

local Game = require(script.Parent:WaitForChild("Game"))

assert(game:GetService("ReplicatedStorage"):FindFirstChild("GameEvent") == nil,
	"[Dino Egg Hunt] GameEvent already exists — two hunts cannot share a server.")
print("[Dino Egg Hunt] Server starting — building the island.")
Game.start()
print("[Dino Egg Hunt] The hunt is open. Ten eggs, three raptors, one island.")
