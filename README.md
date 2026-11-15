# Dino Egg Hunt

[![make.fun · roblox-game-01](https://make.fun/badge/roblox-game-01.svg)](https://make.fun/bounty/roblox-game-01?utm_source=github&utm_medium=badge&utm_campaign=roblox-game-01)
[![make.fun · entry rank](https://make.fun/badge/roblox-game-01/rank.svg)](https://make.fun/bounty/roblox-game-01)
[![make.fun · reward](https://make.fun/badge/roblox-game-01/reward.svg)](https://make.fun/bounty/roblox-game-01)

A Jurassic jungle survival hunt for Roblox: explore a dusk-lit island,
collect 10 hidden dino eggs, dodge three patrolling raptors, and spend
amber coins on Swift Boots, an Extra Heart and Torch Oil. Fastest win
tops the in-server leaderboard.

## How to play

- **Goal:** find all 10 dino eggs. First to all ten wins.
- **Move:** WASD + mouse. **Sprint:** hold SHIFT. **Jump:** Space.
- **Torch:** press F (or click the torch tool) to scare the nearest
  raptor away — 8 second cooldown.
- **Caught:** a raptor touch costs one heart and sends you back to camp.
  Three hearts, then the hunt is over.
- **Shop:** amber coins buy Swift Boots (+4 speed), an Extra Heart,
  and Torch Oil (torch ready at once).

## Play it

The published experience is linked in `PLAY.json`. To publish it
yourself, follow `PUBLISH.md` (open `game.rbxl` in Roblox Studio,
publish as Public, paste the place and universe ids into `PLAY.json`).

## Screenshots

`screenshots/` holds three captures of the game as built: the menu
(`1-start.jpg`), the hunt in progress (`2-play.jpg`), and the win
screen (`3-end.jpg`). The first by name is the cover.

## Build it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

`main.ts` copies the place, the sources, the screenshots and the play
link into `/output` and writes `dossier.json`, the summary the judge
reads. The game is a Rojo project: the Luau under `src/` is the whole
game — `src/server` builds the island and runs the hunt, `src/client`
draws the menu, HUD, shop and end screens, `src/shared` holds the
numbers both sides agree on.

## Layout

- `src/server/init.server.luau` — server entrypoint
- `src/server/Game.luau` — the hunt: state, eggs, coins, hearts, rounds
- `src/server/Map.luau` — the island: trees, ruins, river, camp, nests
- `src/server/Raptors.luau` — the pack: patrol, chase, catch, scared
- `src/server/Shop.luau` — the amber shop
- `src/shared/Config.luau` — every number the game balances on
- `src/client/Game.client.luau` — menu, HUD, shop, torch, sprint

Built for [make.fun](https://make.fun/bounty/roblox-game-01)'s
roblox-game-01 bounty by the agent of [@lexia4](https://make.fun).
