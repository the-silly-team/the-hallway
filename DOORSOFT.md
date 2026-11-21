# DOORSOFT formats

DOORSOFT is this project's own proprietary asset-layer format family. It is original to this game; it does not copy any other game's file formats.

Every `.dr*` file shares one envelope:

```
magic(4) + vendor(6 "DRSOFT") + version(u16) + payload + crc32(u32)
```

All integers are little-endian. Strings are length-prefixed UTF-8 (`u8` length + bytes). Floats are 32-bit, so JSON round-trips can show tiny precision tails like `1.70000004768372`.

## formats

| ext | magic | purpose |
|---|---|---|
| `.drtx` | `DRTX` | RGBA8 texture, optional RGBA8 normal map |
| `.drau` | `DRAU` | 16-bit PCM audio, mono/stereo, optional loop points |
| `.drcl` | `DRCL` | collision boxes (center, half-extents, type) |
| `.drlv` | `DRLV` | editable level definition |
| `.drsc` | `DRSC` | compiled scene instances with asset references |
| `.drmf` | `DRMF` | package manifest with file sizes, CRCs, dependencies |

`.drlv`, `.drsc`, and `.drmf` use JSON-friendly dictionaries: vectors are `[x,y,z]`, colors are `[r,g,b]`. That makes them easy to author by hand and easy for an agent to generate.

## cli

Run from the project root with a godot 4.7.2 console build:

```powershell
$godot = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path . --script res://tools/dr_tool.gd -- roundtrip
& $godot --headless --path . --script res://tools/dr_tool.gd -- info tools/fixtures/menu.drtx
```

Commands:

```text
info <file>
tex-pack <in.png> <out.drtx> [name]
tex-unpack <in.drtx> <out.png>
aud-pack <in.wav> <out.drau> [name]
aud-unpack <in.drau> <out.wav>
coll-pack <out.drcl> <name> <cx cy cz hx hy hz>...
coll-unpack <in.drcl>
lv-pack <in.json> <out.drlv>
lv-unpack <in.drlv>
sc-pack <in.json> <out.drsc>
sc-unpack <in.drsc>
mf-pack <in.json> <out.drmf>
mf-unpack <in.drmf>
tex-gen-pack <kind> <out.drtx>
aud-gen-pack <id> <out.drau>
gen-assets [tex_dir] [aud_dir]
roundtrip
```

`gen-assets` exports every procedural texture and sound into `res://assets/drtx/` and `res://assets/drau/` (12 files). `tex-gen-pack` / `aud-gen-pack` export a single one.

## runtime loading

Procedural generation is the fallback; DOORSOFT files win when present.

- `texgen.gd` looks for `res://assets/drtx/<kind>.drtx`. A packed normal map is used directly; if the `.drtx` has none, a normal map is derived from the albedo.
- `audio.gd` looks for `res://assets/drau/sfx/<id>.drau` and `res://assets/drau/music/<id>.drau`, then `res://assets/drau/<id>.drau`.
- Individual files can be redirected with project settings `doordsoft/drtx/<kind>` and `doordsoft/drau/<group>/<id>`. A bad or corrupt file falls back to procedural generation instead of breaking the game.

The generator functions live in `scripts/audio_gen.gd` (no autoload dependencies), so both the runtime autoload and the headless CLI can call the same code.

Use a project-relative `res://...` path when loading a WAV as a Godot resource (`aud-pack`). The binary helpers accept ordinary absolute paths as well, so packed files and JSON fixtures can live anywhere the process can write.

## audio caveat

Godot's default WAV import uses ADPCM compression. DOORSOFT audio stores raw 16-bit PCM, so `aud-pack` rejects compressed streams. Set `compress/mode=0` in the WAV's `.import` file and reimport before packing.

## fixtures

`tools/fixtures/` contains sample JSON definitions and packed outputs used for real-file smoke tests. `roundtrip` covers the pure binary paths without needing those files.

## viewer

For a native GUI that decodes every format above: [door-inspector](https://github.com/the-silly-team/door-inspector).
