# Jackal Squad

Jackal Squad is an original top-down 2D cooperative jeep action game for Windows, built with Godot 4 and GDScript. It takes inspiration from the broad genre and play style of classic top-down action games; all game code, art, maps, audio, and branding will be original.

## Development setup

- Windows 11 x86-64
- Godot 4.x stable (Godot 4.7.2 is currently installed)
- GDScript; .NET is not required
- Git
- VS Code is the planned editor; Godot's editor is used to open, run, and export the project

Open this folder in Godot, or launch and test it from PowerShell after Godot is available on `PATH`:

```powershell
godot --path .
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_milestone1.gd
```

Godot's Windows export templates for 4.7.2 are installed in the current user's profile. A Windows build has not been produced yet.

## Controls

- WASD or arrow keys: drive
- Space or left mouse button: machine gun
- Ctrl or right mouse button: grenade

## Current status

Milestones 0 and 1 are complete. The current single-player prototype has a finite vertical battlefield, a jeep with an independent camera, machine-gun and grenade attacks, infantry enemies, collisions, health, and respawning. Multiplayer, upgrades, rescue mechanics, and the complete mission remain future milestones.

See [DESIGN.md](./DESIGN.md), [TASKS.md](./TASKS.md), and [TESTING.md](./TESTING.md) for scope and progress.
