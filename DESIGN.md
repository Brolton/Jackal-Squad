# Jackal Squad — Design

## Vision

Create a complete, playable, top-down 2D cooperative action level for one to four players. Players drive distinctively colored jeeps north through a finite battlefield, fight enemies, destroy installations, rescue prisoners, and reach an extraction zone and final base.

The project is an original work. It will not use Jackal sprites, music, maps, level layouts, or branding.

## Platform and technology

- Windows 11 x86-64; Godot 4.x stable; GDScript.
- Godot's high-level multiplayer API with ENet over UDP; listen-server hosting on port 24567.
- Solo play works offline. A host is one of the playable participants; up to four players total.
- No paid software or hosted server is required. Native Windows development is the target; WSL is not required.

## Core experience

- A finite, vertically oriented map with room for side exploration and distinct jungle, camp, river/bridge, enemy defense, extraction, and base areas.
- Each jeep has a separate, smooth-follow camera with map-bound clamping. The shared world persists when players are far apart.
- Arcade movement with collision; simultaneous movement and fire; facing-directed primary fire; health and respawning.
- An unlimited-ammunition machine gun and a cooldown-based grenade/rocket weapon. Upgrade levels belong to individual players.
- Infantry, turrets, tanks, and river boats provide distinct combat challenges.
- Destroyed rescue buildings release three people. They seek nearby jeeps with passenger capacity; each jeep carries up to six.
- Passenger unloading begins automatically at extraction, pauses immediately if the jeep leaves, and resumes on return. A periodic helicopter collects evacuated passengers.
- The host validates shared combat, AI, pickups, rescue, extraction, and mission progress. Clients do not set authoritative world state.

## Presentation

Use original, simple pixel art or procedural placeholders with a compact HUD. Player slots determine jeep colors: red, blue, yellow, and purple. Nicknames remain readable above jeeps. Audio is optional for the first milestone.

## Milestones

0. Environment and project setup.
1. Single-player movement, map, camera, weapons, basic enemies, and collision.
2. Host/join, lobby, player identity, synchronization, and independent cameras.
3. Enemy variety, combat, upgrades, and respawning.
4. Rescue, passenger boarding/unloading, helicopter extraction, and scoring.
5. Complete level, final base, and victory flow.
6. Testing, Windows export, and distribution instructions.

## Current implementation

The production expansion is complete. Jackal Squad now has three distinct missions: the 2625-by-29400 green Emerald Approach, 2450-by-25200 brown-gray Desert Basin with cactus fields, and 2800-by-28000 snowy Snowbound Highlands. Each battlefield is about 1.75 times wider and seven times longer than its original layout, with added route encounters. Each has its own terrain, routes, enemy roster, rescue sites, upgrades, minefields, extraction area, and command base. Original high-resolution campaign artwork, detailed procedural unit art, combat effects, and a shared teal/gold interface replace the placeholder presentation.

Arcade driving, map-clamped cameras, machine-gun and grenade combat, infantry, turrets, tanks, boats, rescue/extraction, helicopter collection, mission statistics, per-player upgrades, respawning, pause/restart, campaign advancement, and cooperative difficulty scaling are integrated. The host remains authoritative over movement, combat, hazards, cargo, and progress for up to four players. Automated tests cover all three layouts, presentation wiring, gameplay polish, solo completion, two-player multiplayer, and four-player multiplayer. The Windows release export and headless startup are verified; LAN/Tailscale and interactive windowed play still require manual checks on the target PCs.
