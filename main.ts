// DINO EGG HUNT — the program that hands the game in. It gathers the
// place file, the play link, the sources and the screenshots from beside
// this file into /output, then writes the dossier the judge reads with
// the kit's vendored library. Node 22, standard library only; nothing
// is installed before it runs.
//
// Run it outside the grader's container with:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const repoRoot = fileURLToPath(new URL('.', import.meta.url));
const outDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

// Fail loudly instead of handing in a half-built game: a missing place
// file means Rojo was never run, and the gate would refuse it anyway.
if (!existsSync(join(repoRoot, 'game.rbxl'))) {
	throw new Error('game.rbxl is missing — run: rojo build default.project.json --output game.rbxl');
}

// The place itself, built by Rojo from the sources in src/.
copyFileSync(join(repoRoot, 'game.rbxl'), join(outDir, 'game.rbxl'));
// The published experience this entry plays at; Adrian fills it in
// after publishing (see PUBLISH.md) — the starter's zeros are a
// placeholder, never a real link.
copyFileSync(join(repoRoot, 'PLAY.json'), join(outDir, 'PLAY.json'));
// The Luau the place was built from, so the gate can match them.
cpSync(join(repoRoot, 'src'), join(outDir, 'src'), { recursive: true });
// The screenshots: first by name is the cover.
mkdirSync(join(outDir, 'screenshots'), { recursive: true });
if (existsSync(join(repoRoot, 'screenshots'))) {
	cpSync(join(repoRoot, 'screenshots'), join(outDir, 'screenshots'), { recursive: true });
}

// The caps are the scorer's own: only the text cap shapes the bytes;
// the rest refuse an entry the scorer would refuse (more than 4 shots
// or one over 256 KiB, a place past 500,000 instances, scripts past
// 8 MiB of source or 1,048,576 characters of paths).
writeFileSync(
	join(outDir, 'dossier.json'),
	buildDossier(outDir, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);
