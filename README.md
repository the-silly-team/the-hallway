# MOW MY LAWN

**a game about mowing a lawn that refuses to stay mowed.**

inspired by the "dig a hole, sell the dirt, upgrade the shovel" loop — except instead of a hole you have a lawn, instead of dirt you have clippings, and instead of finishing you have MOW MY LAWN 2 where the grass grows forever. trust us.

> **status:** early. the repo currently holds the reusable base (godot project, menu, settings, persistence, input, procedural textures/audio, SILLYSOFT asset formats + tooling). the mowing loop itself is still being designed. screenshots in `docs/` are from the base engine.

## download

**[the-silly-team.github.io/mow-my-lawn](https://the-silly-team.github.io/mow-my-lawn/)** ← the download page. click there to grab the windows build.

**[direct link to releases](https://github.com/the-silly-team/mow-my-lawn/releases)** — first playable build lands here when v1 is ready. no steam, no $100 fee, no launcher. just a zip.

## the pitch

- mow grass, collect clippings, sell them, buy a better mower, mow more grass
- day/night cycle: grass grows faster at night, you need lights to see what you're doing
- achievements for stupid stuff like perfect stripes, mowing at 3am, and hitting a sprinkler
- a weird secret under the lawn
- the lawn keeps growing. forever. that's the whole sequel

## run from source

portable godot 4.7.2, no installer, no winget:

```powershell
$Godot = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"

& $Godot --path .              # menu
& $Godot --path . main.tscn    # skip menu
```

headless smoke test:

```powershell
& $Godot --headless --path . main.tscn --quit-after 300
& $Godot --headless --path . menu.tscn --quit-after 300
```

## controls (base build)

| input | action |
|---|---|
| `W A S D` | walk |
| mouse | look around |
| `E` | interact |
| `Esc` | pause / release mouse |
| click | recapture mouse |

## SILLYSOFT

assets use SILLYSOFT, our own original binary format family (no copying anyone's formats, ever). every file is `magic(4) + vendor(6 "SILLY!") + version(u16) + payload + crc32(u32)`.

| ext | magic | what |
|---|---|---|
| `.sltx` | `SLTX` | texture + optional normal map |
| `.slau` | `SLAU` | 16-bit PCM audio |
| `.slcl` | `SLCL` | collision boxes |
| `.sllv` | `SLLV` | level source |
| `.slsc` | `SLSC` | compiled scene |
| `.slmf` | `SLMF` | package manifest |

full docs: [SILLYSOFT.md](SILLYSOFT.md)

**companion app:** [lawn-inspector](https://github.com/the-silly-team/lawn-inspector) — open any `.sl*` file, preview textures, play audio, follow references, read hex. standalone python, zero godot, zero plugins.

## credits

- **lux** — design, ideas, vibes
- **opencode** — most of the actual code (unpaid labor, still showing up)
- **the silly team** — the corporate umbrella, owner of SILLYSOFT™

built with :3 and concerning amounts of coffee.
