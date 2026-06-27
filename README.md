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

- CodeFX Smoke and Splashes
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

A **visual enhancement resource pack (PK3)** for **GZDoom / UZDoom**. It loads *after* an IWAD (Doom or Doom II) and replaces/augments how the game looks and feels, without changing gameplay, weapons, balance, or maps. The repo root is the PK3 root: each filename becomes a lump (e.g. `zscript.zc` → `ZSCRIPT`, `mapinfo.txt` → `MAPINFO`).

- **Engine:** GZDoom **4.10.0+** (declared in `zscript.zc`); also runs on UZDoom.
- **IWADs:** Doom and Doom II are the focus. The `filter/doom.id.doom1/` and `filter/doom.id.doom2/` folders hold per-game overrides that the engine only loads when the matching IWAD is in use.

### Mod compatibility (`DDS_` namespace)

Pack-owned actors (CodeFX smoke, Nash splashes, enchanted projectiles, D64 decorations) are prefixed with `DDS_` so they do not collide with other mods in a stacked load order. ZScript base classes are `DDS_Smoke` and `DDS_StillSmoke` in `zscript.zc`. Splash actors are defined once in `DECORATE.Splash` (not duplicated in `decorate.txt`).

### EXTRAS branch

This branch enables the heavier optional subsystems: RealGore ZScript, extra blood, UDV Fog, Rain Remixed, shiny gore materials, hires assets, and related menu CVars in `cvarinfo`. Options are surfaced through the in-game **".DDS Texture Pack EXTRAS"** menu (`MENUDEF.txt`).

### Installing / running

Load it like any GZDoom PK3 — drag the `.pk3` onto the engine executable, or add it to autoload **after** your IWAD:

```powershell
& "uzdoom.exe" -iwad "DOOM2.WAD" -file "DDS_TexturesPBR_PLUS.pk3"
```

