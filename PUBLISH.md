# Publishing DINO EGG HUNT on Roblox

The entry is not complete until the game is a **Public** experience on
Roblox and `PLAY.json` names it. Only the Roblox account's owner can do
this part. It takes about 10 minutes once Studio is open.

## 1. Open the place

1. Install Roblox Studio (Windows or macOS) from
   https://create.roblox.com and sign in with your Roblox account.
2. Open `game.rbxl` from this repository in Studio (File → Open).
3. Press **Play** (F5) once: walk around, collect an egg, check the
   menu, the HUD and the shop all show. Press **Stop** when done.

## 2. Publish it

1. File → **Publish to Roblox As…** → **Create New Experience**.
2. Name: `Dino Egg Hunt`. Description: a sentence about the hunt
   (Roblox refuses a name or description that reads as a web address,
   so do not put make.fun or any URL in it).
3. Pick a genre (e.g. Adventure). Answer Roblox's content questions:
   for this game the first question (age-restricted content) is **No**,
   which ends the questionnaire there.
4. Creator Dashboard → the experience → **Audience** → set it to
   **Public**. (Roblox asks for the account's age check once, and the
   account must be in good standing and at least 2 days old.)

## 3. Fill in PLAY.json

1. Open the experience on roblox.com and copy the play link:
   `https://www.roblox.com/games/<placeId>/...` — `<placeId>` is the
   number in that link, and that place must be the experience's start
   place.
2. The universe id is the number after `experiences/` in the
   experience's address on the Creator Dashboard (or `game.GameId`
   in Studio — `game.PlaceId` is the place id, not the universe).
3. Edit `PLAY.json` in this repository to:

```json
{"url": "https://www.roblox.com/games/<placeId>", "place_id": <placeId>, "universe_id": <universeId>}
```

4. Rebuild the dossier (`mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts`)
   and re-check it before submitting — the gate looks the play link up
   on Roblox's public API as soon as the entry is submitted.

## 4. (Optional) Thumbnail

On the Creator Dashboard, under the experience's start place, upload
a thumbnail or an icon: make.fun shows it beside the entry on the
Feed. A fault reading it never refuses the entry.

## If the gate refuses the play link

- **Private / Playtest:** the experience is not Public yet — set it
  to Public on the Creator Dashboard and submit again.
- **Mismatched ids:** `place_id` must be the number in the play link,
  `universe_id` the experience's own id (Creator Dashboard URL), and
  the place must be the experience's start place.
- **Too new an account:** Roblox only lets an account publish once it
  is 2 days old and past its age check — use an account that can
  already publish.
