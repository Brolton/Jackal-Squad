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

Milestones 0 through 4 are complete. The prototype uses a generated 1200-by-3200 battlefield with a road, river crossing, blocking terrain, and original procedural placeholder graphics. It has arcade jeep movement, a map-clamped camera, machine-gun projectiles, grenade area damage, infantry, turrets, tanks, armed river boats, health, respawning, and player-specific weapon upgrades. Destroying rescue buildings releases passengers that board nearby jeeps up to a six-person capacity; jeeps unload automatically at extraction, pause unloading when they leave, and resume when they return. A periodic helicopter collects evacuated passengers, with the shared score shown in the HUD. The host controls multiplayer movement, combat, cargo, and rescue scoring. Solo and ENet host/join-by-IP sessions support up to four players, lobby nicknames and color slots, and independent cameras. Automated tests cover solo gameplay and two-/four-player loopback sessions. LAN/Tailscale play, windowed testing, Windows export, and mission completion remain unverified.

The next milestone is completing the level, final base, and victory flow.
