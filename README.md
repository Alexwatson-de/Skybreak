# Skybreak Arena 1.3 — browser multiplayer

An original Godot 4.5.1 jetpack arena shooter with a browser client, native LAN play, and authoritative online matches. Six arenas, four distinct operators, six guns, three grenade types, deathmatch and team deathmatch. No purchases, ads, subscriptions, analytics SDK, or Firebase dependency.

## Play in a browser

Live game: **https://skybreak-zeta.vercel.app/**. Source: [Alexwatson-de/Skybreak](https://github.com/Alexwatson-de/Skybreak). The multiplayer service runs at `https://skybreak-multiplayer.onrender.com`.

The website runs the actual Godot game. Choose **Play Online**, create a room or join a code/invite, chat, choose teams, ready up, and let the host start. Practice against three bots is also available. Desktop supports keyboard/mouse; Android uses a native landscape touch layout.

## Android APK

The Android build uses the same Godot simulation, LAN ENet play, and online WebSocket match client as desktop/web. In a match, use the left stick to move (push up to jump and down to crawl), drag/touch the open right side to aim and fire, and use the on-screen **Jump**, **Jet**, **Crouch**, **Grenade**, **Reload**, **Pick up**, and weapon-rack controls. The server still validates movement, shooting, health, ammunition, kills, and scores.

Prerequisites: Godot 4.5 Android export templates, Android SDK platform 35/build-tools, and a Java 17+ JDK. Set Godot's Android SDK and debug keystore paths in Editor Settings, then run:

```sh
GODOT_BIN=/path/to/Godot bash scripts/build_android.sh
```

The resulting installable APK is `builds/android/Skybreak-Arena.apk`. Install it with `adb install -r builds/android/Skybreak-Arena.apk`, or transfer it to an Android device and allow installation from your file manager. Android local Wi-Fi/hostpot rooms require the same network and the host's reachable LAN IP.

The interface stays at native display resolution. **Connection details → Graphics quality** adjusts the terrain detail without downscaling labels, avatars or the HUD. Auto reduces world detail during slower matches; Low and High are also available.

Vercel serves the browser client. A Render **Free** Docker service runs the Node.js/TypeScript/Socket.IO lobby and a dedicated Godot process per match. Browser and current native online clients use WebSocket/WSS through the same public HTTPS port. Native Wi-Fi/hotspot hosting continues to use ENet. All modes share `game/scripts/sim.gd`; no game rules are reimplemented in the website.

Free Render hosting sleeps after 15 minutes without traffic. The first connection can take about a minute to wake. The client shows a wake-up state and retries with backoff. Free usage limits apply; no paid plan or payment method is required by the project. Rooms and match state are in memory, so a server restart ends active matches.

## Controls

| Action | Input |
|---|---|
| Move | A / D or left / right arrows |
| Jump | Space |
| Crouch / crawl | Hold S, down arrow or Ctrl; move with A / D |
| Jetpack | W / up arrow / right mouse |
| Aim / fire | Mouse / left mouse |
| Collect a nearby gun | E |
| Switch collected guns | 1–6 |
| Reload | R |
| Select grenade / throw | Q / G |
| Scoreboard / match menu | Tab / Escape |

Start with the Sable pistol. Find Kestrel AR, Breach Shotgun, Needle SMG, Longshot DMR and Volt Carbine racks. The server validates pickup distance, line of cover, ownership, ammunition, damage, kills and scores. Racks regenerate after 18 seconds. Frag grenades bounce on a timer; impact grenades detonate on terrain; incendiaries create a brief damaging fire patch. Death resets equipment; respawn takes three seconds. Team damage is disabled.

Catacombs, Outpost, Pyramid and So Long are reference-inspired arenas alongside Rootbound Ruins and Ember Quarry. These are original layouts and drawings, not exact replicas of Mini Militia maps. Low passages require crouching; the authority prevents standing under a ceiling and applies the reduced movement speed and hit target.

Wren is a hooded pathfinder, Rivet an armored automaton, Vesper a masked runner with a cape, and Kite a goggle-wearing aviator. Lobby cards show each player's operator, team and readiness. Browser room-code and invite-link buttons use real browser click events for clipboard access.

Local firing feedback and ammunition previews appear immediately. Authoritative acknowledgements reconcile them; only the server can apply damage, kills and scores. Snapshot reconciliation coalesces bursts into one replay per physics frame. The camera reserves a lower HUD strip so grounded players remain above the inventory and ammunition panels.

Each weapon has a separately processed sound derived from a credited Pixabay recording. See [audio attribution and license](docs/licenses/PIXABAY-AUDIO.md). Explosions, jetpack and hit cues remain synthesized.

## Run locally

Install free Node.js 22+ and use Godot 4.5.1:

```sh
./scripts/bootstrap.sh
GAME_TRANSPORT=websocket PUBLIC_URL=http://127.0.0.1:3000 ./scripts/lobby.sh
```

In a second terminal:

```sh
SKYBREAK_DEV=1 bash scripts/build_web.sh
python3 -m http.server 8123 --bind 127.0.0.1 --directory builds/web
```

Open `http://127.0.0.1:8123` in two tabs. The first creates a room; the second joins its invite/code. Both ready up, then the host starts. `SKYBREAK_DEV=1` enables explicit local QA URL controls; Vercel exports always disable them. Serve through HTTP rather than opening `index.html` as a local file.

`./scripts/play.sh` opens the native client from source. Browser/desktop online cross-play requires this updated client; the previously supplied 1.1 Mac package has ENet-only online networking.

## Native Wi-Fi / mobile hotspot play

Connect all native clients to the same network. Host from **Play with Friends / Local**, then use nearby discovery or the host's IP address. UDP 28760 carries gameplay; UDP 28761 carries discovery. Select teams, chat, ready up and start. Direct IP works when broadcasts are blocked; networks that isolate devices cannot support direct LAN play. Closing the host ends the room.

The earlier 1.1 Universal Mac release fixed the original bundle's invalid resource signature. The Mac build remains ad-hoc signed, not Apple-notarized. See [Mac packaging](docs/MACOS-PACKAGING.md). The browser build avoids app installation entirely.

## Deploy / keep GitHub updated

Source repository: [Alexwatson-de/Skybreak](https://github.com/Alexwatson-de/Skybreak).

- `render.yaml` explicitly selects **Free**, Singapore, two rooms, and Docker.
- `vercel.json` builds the browser export and serves compressed WebAssembly.
- Set Vercel's `SKYBREAK_LOBBY_URL` to the Render HTTPS origin.
- Set Render's `WEB_URL` to the final Vercel production origin. `PUBLIC_URL` can be omitted on Render; `RENDER_EXTERNAL_URL` supplies the correct match gateway address.
- Add any additional exact website origins to Render's `ALLOWED_ORIGINS`, separated by commas. Preview domains need their own allowlist entries.
- GitHub Actions checks simulation, browser export, ENet, WebSocket gateway and reconnection on pushes to `main`. Connected hosting projects deploy subsequent pushes; Render waits for checks.

See [deployment steps](docs/DEPLOYMENT.md), [architecture](docs/ARCHITECTURE.md), and [verification scope](docs/TESTING.md). Do not commit tokens, service-account keys, `.env`, `.runtime`, dependencies, or builds. The user requested future completed changes also be committed and pushed; that agreement is recorded in `AGENTS.md`.

## Verify / build

```sh
./scripts/test.sh
GAME_TRANSPORT=websocket npm --prefix backend test
GAME_TRANSPORT=websocket python3 scripts/test_capacity.py
bash scripts/build_web.sh
```

`./scripts/test.sh --full` adds native lobby and capacity checks. On macOS, `./scripts/build.sh` exports and signs the native app as well as the browser build. Godot's web runtime template is vendored with its license notices so cloud builds do not download the full multi-platform template bundle. Linux engine downloads are checked against the official release digest.

The server runs fixed simulation ticks, bounded hitscan rewind, client prediction and replay, remote interpolation, bounded snapshot queues, smooth small corrections, and reconnection. Server-side validation limits cheating; this is an indie game rather than a production-scale account/anti-cheat platform. No public Internet latency, live deployment, or platform test should be claimed without actual evidence.

Source and original assets are MIT licensed; Pixabay-derived weapon audio has its separate Content License. See [third-party notices](THIRD_PARTY.md). No Mini Militia artwork or code is included.
