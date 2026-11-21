# LAWN INSPECTOR 🌱🔍

**a standalone native GUI for the SILLYSOFT `.sl*` asset family.**

companion tool for [MOW MY LAWN](https://github.com/the-silly-team/mow-my-lawn), by the silly team. not a godot scene. not a plugin. not electron. just python's stdlib `tkinter` in a real win32 window — launches instantly, no packages to install, no node_modules the size of a small moon.

<p align="center">
  <img src="https://raw.githubusercontent.com/the-silly-team/mow-my-lawn/main/docs/final_play_small.png" alt="the game these assets come from" width="640">
</p>

## launch

double-click `LAWN_INSPECTOR.cmd`, or from a terminal:

```powershell
python lawn_inspector.py
python lawn_inspector.py samples/manifest.slmf
```

drop `.sl*` files onto the `.cmd` launcher to open them directly. `Ctrl+O` opens the file picker.

## what it actually does

- **STRUCTURE** — every decoded field with byte offset, type and value. the 12-byte SILLYSOFT envelope and trailing CRC32 are first-class fields, not hidden implementation detail.
- **PREVIEW** — depends on the magic:
  - `SLTX` — albedo + embedded normal map, decoded from raw RGBA8 with a pure-python PNG encoder
  - `SLAU` — waveform drawn from 16-bit PCM, play/stop with moving playhead, loop markers, export to WAV
  - `SLCL` — top-down X/Z view of collision boxes, colour-coded by type, plus numeric list
  - `SLLV` / `SLSC` / `SLMF` — clean structured dumps of levels, compiled scenes and manifests
- **REFERENCES** — shows what each file points to and resolves it against the file's directory. `FOUND` / `MISSING` / `IN-FILE` status. double-click a found reference to open it in the same window; "resolve references" loads found files into the workspace automatically.
- **HEX** — offset / hex / ASCII, with header and CRC colour-coded.

integrity is checked on open: stored CRC32 is recomputed and shown as OK or BAD. a parse error doesn't stop you inspecting the raw bytes.

## formats

| ext | magic | payload |
|---|---|---|
| `.sltx` | `SLTX` | RGBA8 albedo + optional RGBA8 normal |
| `.slau` | `SLAU` | 16-bit PCM, mono/stereo, optional loop points |
| `.slcl` | `SLCL` | collision boxes (center / half extents / type) |
| `.sllv` | `SLLV` | editable level source |
| `.slsc` | `SLSC` | compiled scene instances + asset refs |
| `.slmf` | `SLMF` | package manifest with sizes, CRCs, deps |

binary envelope and authoring rules: [SILLYSOFT.md](SILLYSOFT.md)

## samples

`samples/` has one real file of every format. open `manifest.slmf` first if you want to see the reference resolver light up.

## smoke test

```powershell
python tests/smoke_test.py
```

opens every sample in a real Tk window, cycles every tab, exits. prints `GUI SMOKE OK` when all parser and preview paths work.

## companion

this repo: https://github.com/the-silly-team/lawn-inspector

assets come from [mow-my-lawn](https://github.com/the-silly-team/mow-my-lawn). built with :3 and concerning amounts of coffee.
