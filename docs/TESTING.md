# Verification scope, 1.3

Tests run with Godot 4.5.1 and Node.js. Test clients are separate native processes using real ENet or WebSocket connections. Browser checks use the actual Godot web export, not a recreated game or UI mockup.

## Automated checks

- **45 simulation checks:** movement/speed, jumping/fuel, polygon slopes and cover, free spawns, all map loot, weapon cadence/damage/ammunition/reload, ownership and distance-limited pickups, contested racks, supplies, friendly fire, kills, respawn starter equipment, frag fuse/input gating, impact contact, incendiary damage/expiry, empty inventory and results.
- **Online integration, both transports:** real Socket.IO room create/join, invite links, chat, host-only start, ready/team gates, unique tickets, dedicated Godot startup, two clients, live snapshots/combat, invalid input, forced gameplay disconnect/reconnect and lobby-session recovery.
- **Gateway:** invalid/unknown game upgrades close promptly; an untrusted browser origin is denied. The gateway never accepts a client-specified upstream host or port.
- **Capacity:** eight WebSocket clients on every map. Latest successful maximum compressed snapshots were 822, 872 and 844 bytes. These are local capacity checks, not a claim that free cloud CPU has unlimited capacity.
- **Delayed startup:** the first WebSocket connection is refused, the dedicated endpoint starts later, and the client retries into an authenticated match. Initial retries do not count as reconnecting an existing player.
- Native LAN discovery and Socket.IO client suites remain available in `scripts/test.sh --full`.

Commands:

```sh
./scripts/test.sh
GAME_TRANSPORT=websocket npm --prefix backend test
GAME_TRANSPORT=websocket python3 scripts/test_capacity.py
python3 scripts/test_join_retry.py
bash scripts/build_web.sh
```

GitHub Actions repeats web export, simulation, ENet, WebSocket integration and delayed-join checks on Linux. Retain each completed CI run's actual result before claiming cloud verification.

## Browser / deployment checks

Check canvas size and input coordinates, menu/armory interaction, room invites, chat, teams/readiness, two browser clients in a live match, movement/shooting, connection diagnostics, reload/reconnect, console errors and cloud logs. Capture screenshots and non-secret diagnostics. Source-level and local loopback tests do not prove a public deployment works.

The website exposes a Connection details panel with FPS, ping, snapshot count and player state. No lobby session token or match ticket is included. Local `SKYBREAK_DEV=1` exports may accept explicit QA/auto-play arguments; Vercel exports disable them.

## Known limits

Production verification on 2026-11-03: Vercel and Render both deployed `e00baad`; two real browser tabs joined an invite and started a synchronized match. The real Render integration test passed with 8 hits, 1 kill, 304/271 snapshots and one gameplay reconnect. The simulation suite passed 48 checks. [GitHub CI](https://github.com/Alexwatson-de/Skybreak/actions/runs/41585625956) passed the Linux checks.

Spatial indexing preserved the previous collision trajectories on all three maps. A 3,000-step native movement benchmark took 500,883 µs without indexing and 122,289 µs with indexing (about 4.1× faster). Two simultaneous browser clients on the test machine improved from roughly 6–7 FPS to 15 FPS, still below a smooth 60 FPS target. These measurements do not certify performance on other devices. Sanitized live evidence and the actual browser screenshot are in `live-online-test-evidence.json`, `live-browser-test-evidence.json` and `live-browser-match.png`.

Keyboard/mouse only; no mobile touch, persistent accounts, host migration or cross-region matchmaking. Render Free can cold-start after inactivity and loses in-memory sessions on restart. No guarantee of zero lag or unlimited free hosting is made. Physical multi-device, adverse Internet packet-loss, long soak and recipient-Mac checks require their actual environments. Docker/Linux build verification is supplied by the CI/hosting run rather than inferred from macOS tests.

## 1.3 local verification

- 72 simulation checks passed, including six map spawn/loot checks, crouch passage traversal, blocked standing, preserved foot contact and the reduced crouch bullet target.
- Seven prediction checks passed: immediate cosmetic feedback, weapon cadence, empty/dead-player rejection and authoritative acknowledgement; prediction cannot change server ammo or damage.
- ENet and WebSocket lobby → two native clients → combat → reconnection tests passed. The WebSocket run recorded 13 hits and 2 kills. Operator identity changes were verified through the lobby server.
- Eight real WebSocket clients passed on every map (six maps); the largest compressed snapshot was 930 bytes. The observation interval was extended to 12 seconds so the loaded test machine had time to process enough snapshots without reducing the required snapshot count.
- Browser UI review confirmed distinct operator silhouettes, six map cards, crouch state and a separate lower HUD band. Final public-cloud evidence is recorded separately in the live evidence files.

Weapon audio is six processed variants of one credited Pixabay gun recording, not six unrelated stock recordings. The recording was trimmed, pitch-shifted, filtered, equalized and given different envelopes/echo per weapon. License and attribution are in `licenses/PIXABAY-AUDIO.md`.
