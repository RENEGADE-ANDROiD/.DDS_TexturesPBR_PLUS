# AGENTS.md — DDS_TexturesPBR_PLUS

Orientation for AI agents and contributors working on this project.

## 1. Project Identity

DDS_TexturesPBR_PLUS is a **visual enhancement resource pack (PK3)** for **GZDoom / UZDoom**. It adds high-quality DDS textures with pre-generated mipmaps, PBR materials, brightmaps, dynamic lights, ambient/environmental FX, liquid splashes, enhanced projectiles, voxel gore, and teleporter particle effects.

- **Type:** Graphics / materials / FX layer — **no gameplay changes**. It loads after an IWAD and enhances visuals only.
- **Engine target:** GZDoom **4.8.2+** (`zscript.txt` declares `version "4.8.2"`); also runs on UZDoom.
- **IWADs:** Doom and Doom II are primary (`filter/doom.id.doom1/`, `filter/doom.id.doom2/`). Heretic/Hexen/Strife have GLDEFS stubs only (`HTICDEFS`, `HEXNDEFS`, `STRFDEFS`).
- **Distribution:** Standard GZDoom PK3 — the repo root is the archive root. Filenames map to lump names (e.g. `zscript.txt` → `ZSCRIPT`, `mapinfo.txt` → `MAPINFO`).

> Note: most `.dds` texture payloads referenced in `GLDEFS` / `doomdefs.txt` are **not committed to git** (only sample `materials/metallic/auto/EXIT1.dds`). This repo is mostly definitions and scripts; a full release ships the much larger texture payload separately.

## 2. Repository Layout

| Path | Role |
|------|------|
| `zscript.txt` | ZScript entry point (`version "4.8.2"`); `#include` chain + several inline EventHandlers/classes |
| `ZMAPINFO` | Registers EventHandlers, `defaultbloodcolor`, `gibfactor`, large `PrecacheTextures` list |
| `mapinfo.txt` | Registers `SpawnEnvActorHandler` only |
| `GLDEFS` | PBR `material` blocks, glowing textures, waterfall glow (~6200 lines) |
| `GLDEFS.lights` | Actor-attached dynamic lights (explosions, lamps, columns) |
| `GLDEFS.shaders` | Postprocess `DPWipe` death-wipe shader registration |
| `doomdefs.txt` / `doomdefs2` / `doomdefs3` | Brightmap includes, flicker-light color presets, extra material defs |
| `LTEXDEFS.txt` | Texture hotspot → dynamic-light coordinates, parsed at load by `LightTextureHandler` |
| `decorate.txt` | Enchanted Vanilla Projectiles (`Better_*`) + Nash liquid splashes (`NJ*`) |
| `DECORATE.deco` / `.Splash` | Decorations, FX library, liquid splash variants |
| `actors/` | FancyWorld FX: `fancy_floors.zsc`, `fancy_ceilings.zsc`, `fancy_walls.zsc` |
| `zscript/CheelloVox/` | Voxel gore support (blood billboard, death-facing, monster/powerup variants) |
| `zscript/Gore/` | Full RealGore ZScript — **present but NOT wired in** (see below) |
| `zscript/fountain.zsc` | `GravityFountain`, `TeleporterEffect` actors |
| `zscript/teleporter_effects.zsc` | `TeleporterEffects` EventHandler — spawns colored particle fountains on teleport sectors |
| `filter/doom.id.doom1/` / `filter/doom.id.doom2/` | IWAD-specific overrides (Doom 2 adds extra monster ZScript + `VOXELDEF`) |
| `BMaps/` | Brightmap / glow-flat `.bm` lumps (included from `doomdefs.txt`) |
| `shaders/` | GLSL `.fp` shaders (`parallax2.fp`, `displacement.fp`, `DPWipe.fp`) |
| `materials/` | DDS PBR maps (normal/metallic/roughness/displacement) — mostly absent in git |
| `Source/` / `SRC/` | ACS source (`Ambience.acs`, fog, droplets) — must be compiled to BEHAVIOR |
| `terrain.txt` | Splash actor assignments (points at `NJ*` actors) |
| `ANIMDEFS.txt` / `ANIMDEFS2` | OTEX-style texture animation sequences |
| `CVARINFO.txt` | User CVars (gore amount, teleporter flats, auto-clear gore) |
| `MENUDEF.txt` | ".DDS Texture Pack EXTRAS" options submenu |
| `LOADACS` | Loads `fog`, `droplets`, `Ambience` ACS modules |
| `voxeldef.txt` | Nash/Cheello gore voxel bindings |
| `LANGUAGE.enu` / `.eng` | Menu strings |

Not in git: `brightmaps/`, `normalmaps/`, `patches/`, `sprites/`, `sounds/`, compiled ACS, `.pk3`/`.wad` binaries.

## 3. Active Subsystems

| Subsystem | Files | Wired in? |
|-----------|-------|-----------|
| Death wipe shader | `DPWipeHandler` (in `zscript.txt`), `shaders/DPWipe.fp`, `GLDEFS.shaders` | Yes (ZMAPINFO) |
| Texture-driven lights | `LightTextureHandler` (in `zscript.txt`), `LTEXDEFS.txt` | Yes (ZMAPINFO) |
| Env actor spawning | `SpawnEnvActorHandler`, `actors/fancy_*.zsc` | Yes (mapinfo.txt) |
| Teleporter FX | `TeleporterEffects`, `fountain.zsc`, `teleporter_effects.zsc` | Yes (ZMAPINFO) |
| Cheello voxels | `zscript/CheelloVox/*.zc`, `voxeldef.txt` | Partial (blood + death-facing handler only) |
| Enchanted projectiles | `decorate.txt` (`Better_*`) | Yes (DECORATE auto-load) |
| Nash liquid splashes | `decorate.txt` (`NJ*`), `terrain.txt` | Yes |
| FancyWorld | `actors/fancy_*.zsc`, `DECORATE.effects`, `DECORATE.deco` | Yes |
| Gore ZScript | `zscript/Gore/*.zs`, `DropletsEventHandler` | **NOT wired** (no `#include`, not registered) |
| Cheello monsters/powerups | `CheelloVox/CheelloMonsters*.zc`, `CheelloPowerups*.zc`, `CheelloSphereShell.zc`, `CheelloRocketPlugin.zc` | **Commented out** in `zscript.txt` |
| ACS Ambience/Fog | `Source/*.acs`, `LOADACS` | Needs compiled BEHAVIOR lumps |

## 4. Naming Conventions

| Prefix | Meaning |
|--------|---------|
| `Fancy*` | FancyWorld ambient sector/wall/ceiling FX actors |
| `Better_*` | Enhanced projectile replacements (rockets, plasma, BFG, imp balls, puffs) |
| `NJ*` | Nash gore liquid splash actors (referenced by `terrain.txt`) |
| `64*` | Doom 64-style decoration variants (e.g. `64EvilEye`, `64Column`) |
| `Cheello*` | Voxel gore actors (MIT, by Nash Muhandes) |

## 5. How to Make Changes (by task)

- **Add/modify a PBR material** → edit `GLDEFS` (`material` block), place DDS under `materials/` matching the referenced path.
- **Add a brightmap** → add a `.bm` lump to `BMaps/` and `#include` it from `doomdefs.txt`.
- **Add a texture-driven dynamic light** → add an entry to `LTEXDEFS.txt` (parsed by `LightTextureHandler`).
- **Add/edit a ZScript actor** → edit/create a `.zc`/`.zsc` under `zscript/` or `actors/`; add a `#include` in `zscript.txt` if it is a new file.
- **Register a new EventHandler** → add it to the `AddEventHandlers` block in `ZMAPINFO` (or `mapinfo.txt`).
- **Enable the Gore ZScript subsystem** → add `#include` lines for `zscript/Gore/*.zs` in `zscript.txt` and register `DropletsEventHandler` (and `PB_AutoClearGore_Handler` if wanted) in `ZMAPINFO`.
- **Enable Cheello monsters/powerups** → uncomment the relevant `#include` lines near the top of `zscript.txt`.
- **Add/modify a DECORATE actor** → edit the appropriate `DECORATE.*` lump (projectiles → `decorate.txt`, decorations → `DECORATE.deco`, splashes → `DECORATE.Splash`).
- **Add a texture animation** → edit `ANIMDEFS.txt` (or `ANIMDEFS2`).
- **Add a terrain splash** → edit `terrain.txt` and ensure the referenced splash actor exists in a DECORATE lump.
- **Edit ACS ambience/fog** → modify the source in `Source/` / `SRC/`, then recompile to a BEHAVIOR `.o` lump (e.g. with `acc`).
- **Add a per-IWAD override** → place files under `filter/doom.id.doom1/` or `filter/doom.id.doom2/`.

## 6. Build, Test & Distribution

- **No build system.** Package by zipping the contents of the repo root into a `.pk3`.
- **ACS:** `.acs` sources in `Source/` / `SRC/` must be compiled to BEHAVIOR lumps before packaging (`#library "Ambience"` in `Ambience.acs`); compiled output is not committed.
- **Texture payload:** most DDS assets live outside git; a full visual build requires the separate texture payload.
- **Load order:** drag the PK3 onto the engine executable, or add it to autoload **after** the IWAD.
- **Test run:** launch GZDoom/UZDoom with a Doom or Doom II IWAD and this repo as the loaded file. Substitute your own engine, IWAD, and repo paths:

```sh
<gzdoom-or-uzdoom> -iwad <path/to/DOOM2.WAD> -file <path/to/DDS_TexturesPBR_PLUS>
```

## 7. Documentation References

When writing or modifying ZScript/DECORATE, materials, actors, flags, properties, or states, consult these authoritative sources:

- **Primary ZScript reference (stable):** <https://github.com/zdoom-docs/stable>
- **UZDoom source (versioned engine context):** <https://github.com/UZDoom/UZDoom/tree/4.14.3>
- **DECORATE format specifications:** <https://zdoom.org/w/index.php?title=DECORATE_format_specifications>
- **Action functions:** <https://zdoom.org/w/index.php?title=Action_functions>
- **Classes:** <https://zdoom.org/w/index.php?title=Classes>
- **Actor flags:** <https://zdoom.org/w/index.php?title=Actor_flags>
- **Actor properties:** <https://zdoom.org/w/index.php?title=Actor_properties>
- **Actor states:** <https://zdoom.org/w/index.php?title=Actor_states>
- **DECORATE expressions:** <https://zdoom.org/w/index.php?title=DECORATE_expressions>
