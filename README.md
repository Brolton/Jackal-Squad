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

Godot's Windows export templates for 4.7.2 are installed in the current user's profile. The release preset produces a self-contained x86-64 executable at `builds/JackalSquad.exe`:

```powershell
godot --headless --path . --export-release "Windows Desktop" builds\JackalSquad.exe
```

## Controls

- WASD or arrow keys: drive
- Space or left mouse button: machine gun
- Ctrl or right mouse button: grenade

## Current status

Milestones 0 through 5 are complete. The prototype has a finite vertical battlefield, infantry, turrets, tanks, armed boats, health and respawning, player-specific machine-gun and grenade upgrades, destructible rescue buildings, helicopter extraction, and a final base. Rescue all six passengers and destroy the base to complete the mission; the HUD tracks mission time, enemy defeats, and player contributions, then shows a victory summary. Up to four players can play solo or online by hosting/joining by IP; the host authoritatively simulates movement, combat, passenger cargo, and mission progress.

Automated solo and two-/four-player loopback tests pass. The Windows release export was built and its headless startup check passed. Windowed visual play and connectivity outside loopback remain unverified.

## Playing with friends

1. Run `builds\JackalSquad.exe` on each Windows PC. The exported build embeds its game data in the executable.
2. The host chooses **Host Game**. Friends choose **Join Game**, enter the host address, and wait in the lobby; the host then chooses **Start Game**. The host counts toward the four-player maximum.
3. On the same LAN, friends can use the host PC's private IPv4 address. Allow inbound UDP port `24567` through Windows Firewall; router port forwarding is not needed for devices on the same LAN.
4. Over the public internet, either use Tailscale or forward UDP `24567` on the router to the host PC's private address and share the host's public IPv4 address. With Tailscale, join using the host's Tailscale IPv4 address; no router port forwarding is needed, but the host firewall must allow UDP `24567` on the Tailscale interface.

Use the same game build on all PCs. LAN, Tailscale, and public-internet sessions have not yet been tested; only local loopback multiplayer has been verified.

See [DESIGN.md](./DESIGN.md), [TASKS.md](./TASKS.md), and [TESTING.md](./TESTING.md) for scope and progress.
