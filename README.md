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
- J or left mouse button: machine gun
- K or right mouse button: grenade
- Escape: pause, restart the current mission, or return to command

## Current status

The game has three selectable campaign missions: Emerald Approach, Desert Basin, and Snowbound Highlands. Each map is about 1.75 times wider and seven times longer than its original layout, with more encounters along the extended routes. Emerald Approach is a green jungle operation with branching roads, two rivers, four bridge choices, rescue camps, fortified checkpoints, and visual landmarks. Desert Basin has brown-gray terrain and cactus fields; Snowbound Highlands has pale snowy ground, snow-covered trees, and icy passes. Each mission has its own enemy roster, rescue sites, upgrades, extraction points, and command base. Rescues are optional repair and score bonuses; destroying every independently firing boss turret and then the exposed base core completes the mission and advances the campaign automatically. Boss turret counts scale with both mission number and squad size. Near the final base, each mission also deploys capped infantry and tank reinforcements that return after a level-specific delay.

The presentation uses original project-specific key art, painted terrain, and high-resolution transparent top-down sprites for player jeeps, infantry, turrets, tanks, and boats. Primary upgrades add visible gun barrels and cyan indicators; grenade upgrades add rocket pods and orange indicators. The menu, mission briefings, tactical HUD, and mission-result flow share a cohesive teal, jungle-green, and warm-gold visual language.

The soundtrack and sound effects are original procedural 8-bit PCM synthesized by the game at runtime. Missions use a fast 148 BPM jungle-action chiptune with marching snares, syncopated bass, heroic lead phrases, and tom fills. Gameplay includes responsive jeep-engine, machine-gun, enemy-fire, grenade, explosion, impact, ramming, pickup, infantry-death, helicopter-arrival, and passenger-boarding audio. Grenades have a shorter throw and defeat a standard tank in two close hits; an upgraded rocket defeats a standard tank in one hit, while boss turrets take reduced rocket damage.

Minefields create route hazards on all three maps. Damage now produces a hit flash and local camera response, enemy durability and firing pressure scale with squad size, and the pause/results flows support restart, mission advancement, campaign completion, and return to command.

Automated solo and two-/four-player loopback tests pass. The Windows release export was built and its headless startup check passed. Windowed visual play and connectivity outside loopback remain unverified.

## Playing with friends

The ready-to-copy Windows package is `builds\JackalSquad-LAN.zip`. Extract the same package on both PCs.

1. Put `JackalSquad.exe` and `Allow-JackalSquad-Firewall.cmd` in the same folder on each Windows PC. If Windows does not show its own network-access prompt, run the firewall helper once as administrator.
2. The host chooses **Host Game**. The lobby displays the host's real Wi-Fi IPv4 address and advertises the room over the LAN.
3. On another PC, the room appears automatically in the LAN game selector. Select it, choose **Join Game**, and wait for the host to choose **Start Game**. The host counts toward the four-player maximum.
4. If discovery is blocked, enter the LAN address shown on the host manually. Both PCs must use the same normal home network, not an isolated guest Wi-Fi. Router port forwarding is not needed on a LAN.
5. Over the public internet, either use Tailscale or forward UDP `24567` on the router to the host PC's private address and share the host's public IPv4 address. With Tailscale, join using the host's Tailscale IPv4 address.

Use the same game build on all PCs. Gameplay uses UDP `24567`; automatic LAN discovery uses UDP `24568`. Cross-process LAN discovery and two-/four-player loopback are verified. A session between two physical PCs, Tailscale, and public-internet play still require target machines for final verification.

See [DESIGN.md](./DESIGN.md), [TASKS.md](./TASKS.md), and [TESTING.md](./TESTING.md) for scope and progress.
