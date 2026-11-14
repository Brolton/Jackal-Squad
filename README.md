# Jackal Squad

Jackal Squad is an original top-down 2D cooperative jeep action game for Windows, built with Godot 4 and GDScript. It takes inspiration from the broad genre and play style of classic top-down action games; all game code, art, maps, audio, and branding will be original.

## Development setup

- Windows 11 x86-64
- Godot 4.x stable (Godot 4.7.2 is currently installed)
- GDScript; .NET is not required
- Git
- VS Code is the planned editor; Godot's editor is used to open, run, and export the project

Open this folder in Godot, or run these checks from PowerShell after Godot is available on `PATH`:

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 2
```

Godot's Windows export templates for 4.7.2 are installed in the current user's profile. A Windows build has not been produced yet.

## Current status

Milestone 0 is complete: the project scaffold passes headless import and startup checks. Gameplay and multiplayer features have not started.

See [DESIGN.md](./DESIGN.md), [TASKS.md](./TASKS.md), and [TESTING.md](./TESTING.md) for scope and progress.
