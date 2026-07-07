# .DDS_TexturesPBR_PLUS

A textures and materials pack for Doom + Doom II in .DDS format with generated mipmaps which relieves the burden on GZDoom / UZDoom from having to generate the mipmaps, vastly improving performance despite the higher quality textures being used.
-----------------

![Demo](https://github.com/user-attachments/assets/7a6d1392-5618-4db4-a9cc-ad5327d502d5)

Comparison Trailer by Shickley aka CACODEMON:
https://youtu.be/STJPOUyMFAA

![Demo](https://github.com/user-attachments/assets/88f38ea1-ed6a-4d8b-b7dd-2b6aec339ff4)

**Salutations!  RENEGADE ANDROiD, here.**  
**I've blended multiple texture packs together for a dark, crisp feel while also enhancing visual FX.  This texture pack has primarily been converted into DDS format (minus transparencies), preserving impressive visuals while keeping performance in mind.**

![Demo](https://github.com/user-attachments/assets/2140b228-40ae-422c-abec-5d66365b3202)

*Thanks to Decibal/Doc for the inspiration and the excellent OTEX texture pack he put together!  Thanks to Generic_Name_Guy for teaching me about DDS format.  Thanks to DarkShadow for extensive testing and suggestions!  Thanks to Derpxeon/Project Mask for great texture suggestions and big thanks to the community and their effort for all the source materials gathered here!*

-----------------

**WHAT'S INCLUDED IN THIS PACK:**

- Deep Water
- Morelights
- FancyWorld
- Nash's Liquid Splashes
- HS's Enchanted Vanilla Projectiles
- Scripted Ambience
- Nashgore/Cheelo Gore Voxels Official
- Teleport FX
- Lamp FX
- Nashgore Shiny Materials (EXTRAS only)
- RealGore v3.0 (EXTRAS only)
- Better Wall Blood Compressed (EXTRAS only)
- ExtraBloodGorev4.0 (EXTRAS only)
- New_blood (EXTRAS only)
- UDV Fog (EXTRAS only)
- Rain Remixed (EXTRAS only)

-----------------

**DHTP+PBR & TEXTURE PACKS USED:**

- DHTP+PBR Optimised
- DHTP_Normal
- Aliens Trilogy Textures
- DarkTexture HQ Pack
- DK's Texture Pack
- Doc's OTEX
- D64ifier Alt
- HD Endmaps
- HOOVER
- Kurikai
- LRHQ
- MMDCXIV-Cyberpunk_City mapwad
- Ultra Pack
- *several assets from OTEX texture source with new animations AND Brightmaps*

-----------------

## Technical Overview

This section is for the curious and for contributors. It explains *what the pack is doing under the hood*. For an agent/developer-oriented map of the repo, see [`AGENTS.md`](AGENTS.md).

### What it is

A **visual enhancement resource pack (PK3)** for **GZDoom / UZDoom**. It loads *after* an IWAD (Doom or Doom II) and replaces/augments how the game looks and feels, without changing gameplay, weapons, balance, or maps. The repo root is the PK3 root: each filename becomes a lump (e.g. `zscript.txt` → `ZSCRIPT`, `mapinfo.txt` → `MAPINFO`).

- **Engine:** GZDoom **4.8.2+** (declared in `zscript.txt`); also runs on UZDoom.
- **IWADs:** Doom and Doom II are the focus. The `filter/doom.id.doom1/` and `filter/doom.id.doom2/` folders hold per-game overrides that the engine only loads when the matching IWAD is in use. Heretic/Hexen/Strife have stub definitions only.

### Why DDS + mipmaps

Textures are shipped in **.DDS format with pre-generated mipmaps**. Normally GZDoom must generate mipmaps at load/runtime for high-resolution textures, which costs memory and time. By baking them in advance, the pack delivers high-quality, high-resolution art while *reducing* the per-frame and load-time burden on the engine.

> Note for anyone browsing the git repo: most of the bulk `.dds` art referenced by the definition files is **not committed to git** (the repo is mostly scripts and definitions). A full release ships the much larger texture payload alongside it.

### What it does technically

| Feature | How it works |
|---------|--------------|
| **PBR materials** | `GLDEFS` defines `material` blocks binding textures to normal / metallic / roughness / displacement maps under `materials/`. Some surfaces use GLSL shaders in `shaders/` (`parallax2.fp`, `displacement.fp`). |
| **Brightmaps & glow** | `.bm` lumps in `BMaps/` (included from `doomdefs.txt`) make specific texture pixels self-illuminate (screens, lamps, lava). |
| **Texture-driven dynamic lights** | At map load, a ZScript handler reads `LTEXDEFS.txt` and places dynamic point/spot lights on surfaces using particular textures — no map editing required. |
| **Ambient environmental FX** | Invisible "probe" actors scan each map and spawn context-appropriate effects: waterfalls, drips, steam, fire flicker, tech hum, and liquid surface motion based on the floor/ceiling/wall textures present. |
| **Liquid splashes** | Nash-style splash actors react to things entering nukage, water, slime, and lava (wired through `terrain.txt`). |
| **Enhanced projectiles** | "Enchanted Vanilla Projectiles" add smoke trails, sparks, and better visuals to rockets, plasma, the BFG, and imp fireballs via DECORATE replacements. |
| **Voxel gore (Nashgore/RA_Vox)** | Voxel models replace flat blood/gibs; a small ZScript layer fixes blood billboarding and makes dying monsters face the player. |
| **Teleporter FX** | A handler scans for teleporter sectors and spawns colored particle fountains over them (colors are configurable via CVars/menu). |
| **Death screen wipe** | A postprocess shader (`DPWipe`) animates a screen effect when the player dies. |
| **Scripted ambience** | ACS modules drive ambient sound/fog (sources in `Source/` / `SRC/`, loaded via `LOADACS`). |
| **Texture animation** | `ANIMDEFS` defines OTEX-style animated texture sequences. |

### EXTRAS

Several heavier gore/weather subsystems (RealGore v3.0, extra blood, UDV Fog, Rain Remixed, shiny gore materials) are marked **EXTRAS only**. In this repo some are present but intentionally *not enabled* by default (for example, the gore ZScript under `zscript/Gore/` is not included in `zscript.txt`; NO-EXTRAS uses `zscript/RA_Vox/` for voxel helpers). They are surfaced through the in-game ".DDS Texture Pack EXTRAS" options menu / separate optional loads.

### Installing / running

Load it like any GZDoom PK3 — drag the `.pk3` onto the engine executable, or add it to autoload **after** your IWAD. Example (UZDoom + Doom II):

```powershell
& "uzdoom.exe" -iwad "DOOM2.WAD" -file "DDS_TexturesPBR_PLUS.pk3"
```

### Configuration

User-facing options live in the **".DDS Texture Pack EXTRAS"** menu (`MENUDEF.txt`), backed by CVars in `CVARINFO.txt` — including teleporter particle colors and gore amount/auto-clear settings.
