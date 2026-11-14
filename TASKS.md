# Tasks

## Milestone 0 — Environment and project setup

- [x] Check Windows, PowerShell, Git, winget, and repository state.
- [x] Install Godot 4.7.2 after the user requested starting with Godot installation.
- [x] Ask approval before installing Godot export templates.
- [x] Create and verify the Godot project scaffold.
- [x] Run headless editor/import and project startup checks.
- [x] Confirm the existing Git repository and review its Godot `.gitignore`.
- [x] Install the approved Godot 4.7.2 Windows export templates.
- [x] Record actual results in `TESTING.md` and commit the verified milestone.

## Milestone 1 — Single-player core

- [x] Build a finite map with a jeep, collision, and an independent camera.
- [x] Add arcade movement, machine gun, grenades, and basic enemies.
- [x] Test movement, aiming, firing, damage, and map bounds.

## Milestone 2 — Multiplayer

- [x] Add solo, host, join-by-IP, lobby, nicknames, and slot-based jeep colors.
- [x] Synchronize remote movement and give each player an independent camera.
- [x] Test two- and four-player loopback sessions, disconnects, and one-to-four player slots.

LAN/Tailscale sessions have not been tested yet.

## Milestone 3 — Combat and upgrades

- [x] Add enemy types, authoritative damage, projectiles, upgrades, and respawning.
- [x] Test combat and upgrade ownership in solo and multiplayer sessions.

## Milestone 4 — Rescue mechanics

- [ ] Add destructible rescue buildings, passenger pickup, and six-person jeep capacity.
- [ ] Implement automatic extraction unloading, stop-on-exit/resume-on-return, and helicopter collection.
- [ ] Test simultaneous arrivals and host-authoritative score/state synchronization.

## Milestone 5 — Complete level

- [ ] Complete the battlefield, final base, mission progress, and victory screen.
- [ ] Track mission time, enemies destroyed, passengers rescued, and player contributions.
- [ ] Test that one player can complete every objective.

## Milestone 6 — Testing and Windows build

- [ ] Run automated, parser, solo, and multiplayer checks; resolve failures.
- [ ] Create and verify a Windows export.
- [ ] Document LAN/Tailscale setup and friend distribution.
