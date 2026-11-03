# Skybreak Arena 1.2 — browser multiplayer

An original Godot 4.5.1 jetpack arena shooter with a browser client, native LAN play, and authoritative online matches. Three underground maps, six guns, three grenade types, deathmatch and team deathmatch. No purchases, ads, subscriptions, analytics SDK, or Firebase dependency.

## Play in a browser

The website runs the actual Godot game. Choose **Play Online**, create a room or join a code/invite, chat, choose teams, ready up, and let the host start. Practice against three bots is also available. A keyboard and mouse are required; mobile touch controls have not been implemented.

Vercel serves the browser client. A Render **Free** Docker service runs the Node.js/TypeScript/Socket.IO lobby and a dedicated Godot process per match. Browser and current native online clients use WebSocket/WSS through the same public HTTPS port. Native Wi-Fi/hotspot hosting continues to use ENet. All modes share `game/scripts/sim.gd`; no game rules are reimplemented in the website.

Free Render hosting sleeps after 15 minutes without traffic. The first connection can take about a minute to wake. The client shows a wake-up state and retries with backoff. Free usage limits apply; no paid plan or payment method is required by the project. Rooms and match state are in memory, so a server restart ends active matches.

## Controls

| Action | Input |
|---|---|
| Move | A / D or left / right arrows |
| Jump | Space |
| Jetpack | W / up arrow / right mouse |
| Aim / fire | Mouse / left mouse |
| Collect a nearby gun | E |
| Switch collected guns | 1–6 |
| Reload | R |
| Select grenade / throw | Q / G |
| Scoreboard / match menu | Tab / Escape |

Start with the Sable pistol. Find Kestrel AR, Breach Shotgun, Needle SMG, Longshot DMR and Volt Carbine racks. The server validates pickup distance, line of cover, ownership, ammunition, damage, kills and scores. Racks regenerate after 18 seconds. Frag grenades bounce on a timer; impact grenades detonate on terrain; incendiaries create a brief damaging fire patch. Death resets equipment; respawn takes three seconds. Team damage is disabled.

The Hollow, Rootbound Ruins and Ember Quarry include irregular earth masses, slopes, masonry arches, underground chambers, roots, grass, lanterns and mine supports. All characters, map layouts, weapon drawings, grenade illustrations and sounds are original.

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

Source and original assets are MIT licensed. See [third-party notices](THIRD_PARTY.md). No Mini Militia maps, characters, assets or code are included.
