# SILLYSOFT formats

SILLYSOFT is this project's own proprietary asset-layer format family. It is original to this game; it does not copy any other game's file formats.

Every `.sl*` file shares one envelope:

```
magic(4) + vendor(6 "SILLY!") + version(u16) + payload + crc32(u32)
```

All integers are little-endian. Strings are length-prefixed UTF-8 (`u8` length + bytes). Floats are 32-bit, so JSON round-trips can show tiny precision tails like `1.70000004768372`.

## formats

| ext | magic | purpose |
|---|---|---|
| `.sltx` | `SLTX` | RGBA8 texture, optional RGBA8 normal map |
| `.slau` | `SLAU` | 16-bit PCM audio, mono/stereo, optional loop points |
| `.slcl` | `SLCL` | collision boxes (center, half-extents, type) |
| `.sllv` | `SLLV` | editable level definition |
| `.slsc` | `SLSC` | compiled scene instances with asset references |
| `.slmf` | `SLMF` | package manifest with file sizes, CRCs, dependencies |

`.sllv`, `.slsc`, and `.slmf` use JSON-friendly dictionaries: vectors are `[x,y,z]`, colors are `[r,g,b]`. That makes them easy to author by hand and easy for an agent to generate.

## cli

Run from the project root with a godot 4.7.2 console build:

```powershell
$godot = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path . --script res://tools/dr_tool.gd -- roundtrip
& $godot --headless --path . --script res://tools/dr_tool.gd -- info tools/fixtures/menu.sltx
```

Commands:

```text
info <file>
tex-pack <in.png> <out.sltx> [name]
tex-unpack <in.sltx> <out.png>
aud-pack <in.wav> <out.slau> [name]
aud-unpack <in.slau> <out.wav>
coll-pack <out.slcl> <name> <cx cy cz hx hy hz>...
coll-unpack <in.slcl>
lv-pack <in.json> <out.sllv>
lv-unpack <in.sllv>
sc-pack <in.json> <out.slsc>
sc-unpack <in.slsc>
mf-pack <in.json> <out.slmf>
mf-unpack <in.slmf>
tex-gen-pack <kind> <out.sltx>
aud-gen-pack <id> <out.slau>
gen-assets [tex_dir] [aud_dir]
roundtrip
```

`gen-assets` exports every procedural texture and sound into `res://assets/sltx/` and `res://assets/slau/` (12 files). `tex-gen-pack` / `aud-gen-pack` export a single one.

## runtime loading

Procedural generation is the fallback; SILLYSOFT files win when present.

- `texgen.gd` looks for `res://assets/sltx/<kind>.sltx`. A packed normal map is used directly; if the `.sltx` has none, a normal map is derived from the albedo.
- `audio.gd` looks for `res://assets/slau/sfx/<id>.slau` and `res://assets/slau/music/<id>.slau`, then `res://assets/slau/<id>.slau`.
- Individual files can be redirected with project settings `sillysoft/sltx/<kind>` and `sillysoft/slau/<group>/<id>`. A bad or corrupt file falls back to procedural generation instead of breaking the game.

The generator functions live in `scripts/audio_gen.gd` (no autoload dependencies), so both the runtime autoload and the headless CLI can call the same code.

Use a project-relative `res://...` path when loading a WAV as a Godot resource (`aud-pack`). The binary helpers accept ordinary absolute paths as well, so packed files and JSON fixtures can live anywhere the process can write.

## audio caveat

Godot's default WAV import uses ADPCM compression. SILLYSOFT audio stores raw 16-bit PCM, so `aud-pack` rejects compressed streams. Set `compress/mode=0` in the WAV's `.import` file and reimport before packing.

## fixtures

`tools/fixtures/` contains sample JSON definitions and packed outputs used for real-file smoke tests. `roundtrip` covers the pure binary paths without needing those files.

## viewer

For a native GUI that decodes every format above: [hallway-inspector](https://github.com/the-silly-team/hallway-inspector).
