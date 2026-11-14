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

## Milestone 2 multiplayer checks

The automated ENet loopback smoke test uses separate Godot processes. Run the host and client commands in separate PowerShell windows:

```powershell
godot --headless --path . res://tests/network_smoke.tscn -- --server
godot --headless --path . res://tests/network_smoke.tscn -- --client
```

For four players, run one host with `--server4` and three clients with `--client`, `--client2`, and `--client3`, each in its own process. Godot 4.7.2 loopback checks passed for both two and four total players. They verify lobby registration, nicknames and color slots, host-started scene loading, per-player camera selection, client movement, authoritative damage and snapshots, player-specific upgrade replication, and removal of disconnected players.

LAN/Tailscale connectivity and windowed play have not been manually verified.

## Milestone 3 combat and upgrades

```powershell
godot --headless --path . --script res://tests/test_milestone3.gd
```

The test passed on Godot 4.7.2. It checks infantry, turrets, tanks, and armed boats; enemy durability and projectile damage; pickup collection and removal; primary and grenade upgrade effects; and the maximum weapon level. The Milestone 1 regression test also passes with the expanded enemy roster.

## Milestone 4 rescue and extraction

```powershell
godot --headless --path . --script res://tests/test_milestone4.gd
```

The test passed on Godot 4.7.2. It checks that destroying a rescue building releases three passengers, nearby passengers board a jeep, capacity stops at six, extraction unloads passengers one at a time, leaving pauses unloading, returning resumes it, and the helicopter transfers evacuated passengers into the rescued total. Enemy units are removed from this focused test scene so combat damage cannot trigger a respawn during extraction assertions.

The multiplayer smoke test also passed with two and four total players. It checks host-authoritative building destruction and boarding, simultaneous unloading by two jeeps, cargo replication to the correct client, and synchronization of helicopter rescue totals. The four-player run also verified lobby registration, movement, damage, upgrades, camera ownership, and disconnect handling.

## Milestone 5 mission completion

```powershell
godot --headless --path . --script res://tests/test_milestone5.gd
```

The test passed on Godot 4.7.2. It defeats the enemy roster, destroys the final base, rescues all six passengers, and verifies that victory is gated on both objectives. It also checks elapsed time, per-player enemy and rescue credit, and the victory panel. The multiplayer smoke tests verify host replication of enemy totals, player contributions, and final-base destruction without premature victory.

## Environment notes

- Git and winget were found; the existing repository is initialized and already has Godot-specific ignore rules.
- Godot Engine 4.7.2 was installed through winget.
- The Godot command alias may require reopening the terminal before it is available on `PATH`.
- Godot 4.7.2 Windows export templates were installed in `%APPDATA%\Godot\export_templates\4.7.2.stable` after approval. The package SHA-256 matched the official GitHub release digest.
- The Windows x86-64 debug and release templates and `version.txt` were verified in the installed template directory.

## Remaining gameplay and build checks

- Test LAN/Tailscale connectivity when available.
- Run windowed visual play.

## Milestone 6 Windows export

```powershell
godot --headless --path . --export-release "Windows Desktop" builds\JackalSquad.exe
builds\JackalSquad.exe --headless --quit-after 3
```

The Godot 4.7.2 Windows x86-64 release export completed successfully. The self-contained executable was 109,236,944 bytes, and its headless startup check exited with code 0. The export preset embeds project data, so the executable can be shared as a single file. Windowed visual play has not been verified.

See `README.md` for the tested build command and LAN/Tailscale connection setup. Network instructions are documented but have not been tested outside loopback.

Do not mark a check as passing unless it was actually run.

## Production stage 1 — campaign foundation

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_campaign.gd
```

The focused campaign test verifies three distinct loadable mission scene entry points, selected-mission startup, synchronized level metadata, campaign advancement, and finale detection. The Milestone 1, 3, 4, and 5 regression suites are run again before the stage commit.

## Production stage 2 — large mission layouts

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_level_layouts.gd
```

The layout test instantiates all three campaign missions and verifies their distinct 1200×3200, 1400×3600, and 1600×4000 world bounds; matching camera limits; encounter rosters; rescue sites; extraction zones; and command bases. Campaign and Milestone 1, 3, 4, and 5 regression suites all passed after the data-driven level refactor.

## Production stage 3 — 2D art and presentation

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_visual_presentation.gd
godot --headless --path . --export-debug "Windows Desktop" builds\JackalSquad-visual-qa.exe
```

The focused presentation test verifies that both high-resolution generated art assets import and load, the main menu actually uses the campaign key art and production panel theme, all three mission briefings are exposed, and the tactical HUD/result panel use the new theme and campaign action. The level-layout, campaign, and Milestone 1, 3, 4, and 5 suites all passed after the visual refactor. A Windows debug export also completed successfully. The generated source images were visually inspected, but automated Windows UI control was not permitted to launch the fresh QA executable, so interactive windowed QA remains part of the final validation stage.

## Production stage 4 — gameplay polish

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_gameplay_polish.gd
```

The gameplay-polish test verifies designed minefields and authoritative mine damage, explosion state, player hit flash and camera trauma, four-player enemy durability/fire-pressure scaling, the complete pause menu, solo pause/resume, and current-mission restart semantics. The presentation, level-layout, campaign, and Milestone 1, 3, 4, and 5 suites all passed after these additions.

## Production stage 5 — final validation

Final validation completed on Godot `4.7.2.stable.official.ed1daf0bf`:

- Headless editor import/parser check passed.
- Campaign, level-layout, visual-presentation, gameplay-polish, and Milestone 1, 3, 4, and 5 tests all passed in one final gate.
- Two-player ENet loopback passed on both the host and client processes.
- Four-player ENet loopback passed on the host and all three client processes, including unique slots, independent cameras, authoritative movement/damage, upgrades, rescue cargo, extraction, mission totals, and disconnect cleanup.
- Windows release export completed at `builds\JackalSquad.exe` (113,456,472 bytes).
- The exported executable started headlessly and exited successfully after three seconds.

Interactive windowed QA could not be automated because Windows UI control did not permit launching the newly built local executable. The generated source art was visually inspected, and its real project wiring, dimensions, scene composition, and UI styles are covered by `test_visual_presentation.gd`. LAN/Tailscale connectivity still requires target machines and is not represented as tested.

## Player feedback pass — camera and controls

`test_controls_camera.gd` verifies fixed `canvas_items` stretching with `keep` aspect, the tighter 1.3× gameplay camera, J/K bindings, both mouse alternatives, and removal of the Space/Ctrl requirement. The Milestone 1 gameplay and campaign suites passed again after the input and viewport changes.

## Player feedback pass — production unit art

`test_visual_presentation.gd` now verifies five high-resolution gameplay sprite sources, real alpha transparency, menu/HUD styling, and changing weapon-visual signatures. Primary upgrades add visible barrels and cyan indicators; grenade upgrades add side-mounted rocket pods and orange indicators. The focused presentation and Milestone 3 combat/upgrade suites passed after the sprite replacement.

## Player feedback pass — rebuilt Emerald Approach

The opening mission is now a 1500×4200 battlefield with four branching road paths, two water barriers, four usable bridges, 30 enemies, 10 mine hazards, 64 blocking terrain objects, two rescue camps, four upgrades, and 22 landmark decorations. `test_level_layouts.gd` verifies the new bounds, encounter roster, landmarks, branches, bridge count, camera bounds, rescue objectives, extraction, and base. Milestone 1, 3, 4, 5, and gameplay-polish suites all passed against the rebuilt geometry.

River banks now use a vehicle/AI-only physics layer. The Milestone 1 test directly verifies that a jeep is stopped by a non-bridge river segment while a projectile crosses the same barrier.

## Player feedback pass — final validation

Final validation completed on Godot `4.7.2.stable.official.ed1daf0bf`:

- `test_controls_camera.gd`, `test_campaign.gd`, `test_level_layouts.gd`, `test_visual_presentation.gd`, `test_gameplay_polish.gd`, and Milestone 1, 3, 4, and 5 all passed in one regression run.
- Two-player ENet loopback passed on both host and client processes.
- Four-player ENet loopback passed on the host and all three client processes.
- The refreshed Windows release export was written to `builds\JackalSquad.exe` (121,480,648 bytes).
- The exported executable started headlessly and exited successfully after three seconds.
- SHA-256: `0AC87B755FAF60283D6439859CB364FCEBC306E143248F7B6C23A106DED23049`.

Interactive windowed play and LAN/Tailscale connectivity still require a real player session and are not represented as tested.

## Presentation pass — framing and interface

The parser/import check, `test_controls_camera.gd`, and `test_visual_presentation.gd` passed after changing the gameplay camera from 1.3× to 0.9×. The camera now exposes roughly 1067×600 world units while the fixed 16:9 viewport still prevents fullscreen resizing from revealing additional terrain. Automated layout checks verify that the HUD backdrop is no taller than 64 virtual pixels and the complete main-menu panel fits within the 960×540 base viewport. Player jeeps were reduced and heavy enemies enlarged for a more coherent vehicle scale.

## Presentation pass — vehicle combat

The parser/import check, `test_milestone3.gd`, and `test_visual_presentation.gd` passed after separating infantry onto a non-blocking trample physics layer. The focused combat test places a soldier under the jeep and verifies that the authoritative ramming sensor defeats it, while heavy enemies remain solid. Player-color rectangles at the rear of the jeep were replaced by an inset body stripe, and upgrade pods now use compact bordered hardware shapes.

## Presentation pass — battlefield rendering

The parser/import check, `test_visual_presentation.gd`, and `test_level_layouts.gd` passed after replacing flat terrain primitives. The test verifies the high-resolution painted river texture and the rendering contract for layered road shoulders, surfaces, dual wheel tracks, irregular bank/foam layers, and planked bridge decks. All three campaign maps still instantiate with their expected bounds, encounters, rescues, cameras, extraction zones, and bases.

## Presentation pass — original audio

`test_audio_presentation.gd` and the Milestone 3 regression passed after adding runtime-synthesized 16 kHz PCM. The focused test verifies a four-second looping chiptune, a responsive looping engine waveform, seven gameplay effect types, level music startup, and live machine-gun/grenade triggers. Mission teardown stops and frees active audio voices so scene changes do not retain playback nodes.

## Presentation and atmosphere pass — final validation

Final validation completed on Godot `4.7.2.stable.official.ed1daf0bf`:

- Controls/camera, campaign, level layouts, visual presentation, audio presentation, gameplay polish, and Milestone 1, 3, 4, and 5 suites passed.
- Two-player ENet loopback passed on the host and client.
- Four-player ENet loopback passed on the host and all three clients after making the cargo/rescue snapshot test deterministic.
- The Windows release export was refreshed at `builds\JackalSquad.exe` (122,891,568 bytes).
- The exported executable started headlessly and exited successfully after three seconds.
- SHA-256: `7F410442F1A082D286C211C137454DD8BE1B821A31901E1DE832BF70EA800D77`.

Windows window capture did not grant automation access to the local QA executable, so final interactive visual judgment remains a manual check. Automated tests directly cover base-viewport menu fit, compact HUD dimensions, fixed fullscreen framing, vehicle scale contracts, terrain assets/rendering layers, and audio wiring.

## Action pass — wider tactical camera

The gameplay camera now uses 0.78× zoom, exposing roughly 1231×692 world units instead of 1067×600, while fixed 16:9 stretching still prevents window resizing from revealing additional terrain. A 70-unit forward offset gives the player more reaction space in the driving direction. `test_controls_camera.gd` directly verifies the zoom, look-ahead, world-visibility ceiling, aspect behavior, and combat bindings.

## Action pass — music and infantry death audio

The original mission loop now runs at 148 BPM for sixteen beats, with a 32-step lead phrase, syncopated pulse/triangle bass, offbeat action stabs, marching kick/snare/hi-hat layers, and a closing tom fill. It intentionally evokes the general energy of a 1990s jungle action film without copying an existing score. Infantry deaths trigger a separate descending, formant-shaped 8-bit cry on the authority and remote clients. `test_audio_presentation.gd` verifies loop duration, tempo, effect coverage, live weapon triggers, engine audio, and the death-cry trigger.

## Action pass — final validation

Final validation completed on Godot `4.7.2.stable.official.ed1daf0bf`:

- All ten focused and regression suites passed in one run.
- Two-player ENet loopback passed on both host and client.
- Four-player ENet loopback passed on the host and all three clients.
- The refreshed Windows release at `builds\JackalSquad.exe` is 122,892,896 bytes.
- The exported executable started headlessly and exited successfully after three seconds.
- SHA-256: `CE67E396ADA1004751E2F90C63CD454C279C47B26F3219F313FBEF516094F13C`.

## Boss pass — mission rules and infantry durability

Infantry maximum health is fixed at one in solo and co-op, while heavy-unit durability still scales with player count. Mission completion now depends only on destroying the final boss; enemy clearing and rescues are optional. Boarding a rescued passenger repairs one missing health point and rescue totals remain in the result statistics. The HUD labels boss destruction as the goal and rescues as a bonus, and solo/host sessions automatically advance four seconds after victory if the player does not press the button first.

## Boss pass — scalable final encounters

Final bases are shielded boss cores surrounded by independently destructible, independently aiming gun turrets. Turret-count scaling is `1/1/2/2` on mission 1, `1/2/3/3` on mission 2, and `1/2/3/4` on mission 3 for one through four players. Each turret is assigned a player target by its index, has mission-scaled health, rate of fire, projectile speed, and damage, and must be destroyed before the core accepts damage. `test_boss_scaling.gd` verifies the complete count matrix, shield gating, sequential turret destruction, and core exposure.

## Boss pass — extraction clarity

The extraction zone is labeled as an optional rescue/repair bonus. Its former abstract fly-by has been replaced with a larger recognizable helicopter silhouette including cockpit, fuselage, tail boom, landing gear, main rotor, and tail rotor. Empty periodic fly-bys were removed: the helicopter now appears only when evacuated passengers are waiting. Milestone 4 directly verifies that no helicopter launches with an empty rescue queue and that a real flight still transfers waiting passengers.

## Boss pass — upgrade clarity

Weapon pickups now have distinct arcade silhouettes and labels: gold multi-barrel `MG / RAPID FIRE` and cyan grenade/ring `BIGGER BOOM`. Collection triggers a large colored ring and `MG UP!` or `BLAST UP!` over the jeep plus type-specific pickup audio. Machine-gun levels change projectile color, core size, glow, and trail length. Grenade levels change projectile size, explosion palette, spark count, shockwave-ring count, radius, and use four distinct synthesized blast sounds. Presentation and Milestone 3 tests verify pickup semantics, jeep attachments, projectile/blast style propagation, level-specific sounds, and mechanical stat changes.

## Boss and campaign pass — final validation

Final validation completed on Godot `4.7.2.stable.official.ed1daf0bf`:

- All 12 focused and regression suites passed, including the complete boss scaling matrix and a real mission-one-to-mission-two scene transition.
- Two-player ENet loopback passed on the host and client, including turret destruction, core destruction, contribution totals, and boss-based mission completion.
- Four-player ENet loopback passed on the host and all three clients with the two-turret mission-one boss.
- The refreshed Windows release at `builds\JackalSquad.exe` is 122,912,544 bytes.
- The exported executable started headlessly and exited successfully with code 0.
- SHA-256: `57AEAF49AB41CEC3F9C9E20AEA341E3CA31F1D8C0780C840C118C507AC5A548F`.

The campaign transition regression specifically verifies that a boss victory changes the active scene instead of only incrementing the mission index. Interactive windowed play and LAN/Tailscale connectivity still require real player sessions and are not represented as tested.
