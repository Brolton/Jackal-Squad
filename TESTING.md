# Testing

## Milestone 0 checks

Run from the repository root in PowerShell. Godot 4.7.2 was invoked directly from its winget install location because the current terminal has not refreshed its `PATH`:

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 3
```

Both checks passed with exit code 0 on Godot `4.7.2.stable.official.ed1daf0bf`:

- `--headless --editor --path . --quit` — project scan/editor initialization passed.
- `--headless --path . --quit-after 3` — configured main scene startup passed.

## Milestone 1 gameplay checks

```powershell
godot --headless --path . --script res://tests/test_milestone1.gd
```

The test script passed three consecutive runs. It checks camera activation and map limits, enemy presence and pursuit, movement, river and map-edge collisions, simultaneous movement and fire, facing-directed shots, grenade creation and area damage, projectile damage, and player respawning. The main scene also started headlessly with exit code 0.

Windowed visual play has not been manually verified.

## Environment notes

- Git and winget were found; the existing repository is initialized and already has Godot-specific ignore rules.
- Godot Engine 4.7.2 was installed through winget.
- The Godot command alias may require reopening the terminal before it is available on `PATH`.
- Godot 4.7.2 Windows export templates were installed in `%APPDATA%\Godot\export_templates\4.7.2.stable` after approval. The package SHA-256 matched the official GitHub release digest.
- The Windows x86-64 debug and release templates and `version.txt` were verified in the installed template directory. A Windows build has not been exported yet.

## Future gameplay and multiplayer checks

- Test solo movement, map bounds, independent camera behavior, firing, damage, and respawn.
- Test two- and four-player host sessions, player colors/nicknames, remote movement, disconnects, and separate cameras.
- Test pickup ownership, passenger capacity, automatic boarding/unloading, immediate unload stop on zone exit, resume on return, helicopter collection, and score synchronization.
- Test mission completion in solo mode and LAN/Tailscale connectivity when available.

Do not mark a check as passing unless it was actually run.
