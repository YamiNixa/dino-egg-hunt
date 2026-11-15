-- Shop: the amber shop. Coins buy three things, each once per round:
-- Swift Boots (+4 walk speed), an Extra Heart (+1 max heart), and Torch
-- Oil (the torch is ready at once). Prices live in Config.SHOP; this
-- module only takes coins and applies the effect.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Shop = {}

-- state is the per-player table Game keeps: { coins, hearts, maxHearts,
-- speedBonus, torchReadyAt, bought = { speed = bool, heart = bool, torch = bool } }
function Shop.buy(state, itemId, now)
	for _, item in ipairs(Config.SHOP) do
		if item.id == itemId then
			if state.bought[itemId] then
				return false, "Already bought this round"
			end
			if state.coins < item.price then
				return false, "Not enough amber"
			end
			state.coins -= item.price
			state.bought[itemId] = true
			if itemId == "speed" then
				state.speedBonus = 4
			elseif itemId == "heart" then
				state.maxHearts += 1
				state.hearts += 1
			elseif itemId == "torch" then
				state.torchReadyAt = 0
			end
			return true, item.name .. " bought!"
		end
	end
	return false, "No such item"
end

function Shop.resetRound(state)
	state.speedBonus = 0
	state.bought = { speed = false, heart = false, torch = false }
end

-- What the client shows in the shop panel: id, name, price, description,
-- and whether this player already bought it this round.
function Shop.catalog(state)
	local list = {}
	for _, item in ipairs(Config.SHOP) do
		table.insert(list, {
			id = item.id,
			name = item.name,
			price = item.price,
			desc = item.desc,
			owned = state.bought[item.id] == true,
			affordable = state.coins >= item.price,
		})
	end
	return list
end

return Shop
