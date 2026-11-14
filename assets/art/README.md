# Art assets

The raster art in this directory was generated specifically for Jackal Squad with OpenAI's built-in ImageGen tool on 2026-11-14. It is original project art and is not copied from the classic *Jackal* game or another commercial title.

## `campaign_key_art.png`

Prompt summary: a polished, hand-painted, pixel-art-inspired 16:9 main-menu illustration of four red, blue, yellow, and violet cooperative jeeps driving through a dusk jungle toward a fortified command base, with negative space for UI and no text or logos.

## `jungle_ground.png`

Prompt summary: a seamless orthographic tropical battlefield ground tile with grass, damp soil, leaves, moss, pebbles, and restrained olive/umber/teal colors, with no objects, text, border, or directional shadows.

## Production gameplay sprites

`player_jeep_v2.png`, `enemy_infantry.png`, `enemy_turret.png`, `enemy_tank.png`, and `enemy_boat.png` were generated as separate transparent assets with the built-in ImageGen tool. Each prompt requested one centered, exact orthographic top-down military unit pointing upward, a crisp hand-painted pixel-art-inspired premium arcade style, neutral upper-left lighting, transparent padding, and no terrain, text, logo, border, watermark, muzzle flash, or isometric perspective. Vehicle-specific prompts called for readable armor, tires/tracks, weapons, storage, windows, and battle wear; the infantry prompt called for a helmet, rifle, webbing, backpack, and readable limbs.

Godot imports these large sources with mipmaps so the detailed art remains stable at gameplay scale. Player weapon attachments remain code-rendered because their barrel and rocket-pod counts change at runtime with upgrades.
