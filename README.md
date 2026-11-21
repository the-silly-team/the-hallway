# THE HALLWAY

**find the keycard. don't make a sound.**

a first-person, doors-inspired escape loop: one corridor, a row of doors, and a keycard that is never where you left it. the hallway remembers every run. clear a floor, get another one.

> **status:** early. the repo currently holds the playable v1 slice (the hallway floors + the old office as a classic mode), the godot base, and the SILLYSOFT asset formats + tooling. more floors are being built.

## download

**[the-silly-team.github.io/the-hallway](https://the-silly-team.github.io/the-hallway/)** ← the download page. click there to grab the windows build.

**[direct link to releases](https://github.com/the-silly-team/the-hallway/releases)** — zips land here, no steam, no $100 fee, no launcher. just unzip and run.

## the pitch

- walk the hallway, try the doors, find the keycard, reach the exit
- the old office is still in there as a classic mode if you want the original loop
- floors stack as you clear them — the hallway gets less friendly every time
- footsteps and door clicks tell you more than the lights do
- achievements for stupid stuff you'll accidentally earn, and one weird secret past the end hall

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

## controls

| input | action |
|---|---|
| `W A S D` | walk |
| mouse | look around |
| `E` | interact / hide |
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

**companion app:** [hallway-inspector](https://github.com/the-silly-team/hallway-inspector) — open any `.sl*` file, preview textures, play audio, follow references, read hex. standalone python, zero godot, zero plugins.

## credits

- **lux** — design, ideas, vibes
- **opencode** — most of the actual code (unpaid labor, still showing up)
- **the silly team** — the corporate umbrella, owner of SILLYSOFT™

built with :3 and concerning amounts of coffee.
