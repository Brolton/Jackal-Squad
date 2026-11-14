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

1. Environment and project setup.
2. Single-player movement, map, camera, weapons, basic enemies, and collision.
3. Host/join, lobby, player identity, synchronization, and independent cameras.
4. Enemy variety, combat, upgrades, and respawning.
5. Rescue, passenger boarding/unloading, helicopter extraction, and scoring.
6. Complete level, final base, victory flow, testing, Windows export, and distribution instructions.

## Current implementation

Milestones 0 and 1 are complete. The single-player prototype uses a generated 1200-by-3200 battlefield with a road, river crossing, blocking terrain, and original procedural placeholder graphics. It has arcade jeep movement, a map-clamped camera, machine-gun projectiles, grenade area damage, chasing/shooting infantry, a compact HUD, health, and respawning. Multiplayer, weapon progression, rescue, extraction, and mission completion are not implemented yet.

Continue with later milestones only after the user confirms the next phase.
