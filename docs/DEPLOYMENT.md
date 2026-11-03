# Vercel + Render Free deployment

Current production website: https://skybreak-zeta.vercel.app/. Multiplayer health endpoint: https://skybreak-multiplayer.onrender.com/health. Both use free plans. Vercel rebuilds when `main` is pushed; after changing Render configuration or game/server code, verify its deployed commit in the Render dashboard and manually deploy the latest commit if its automatic deployment has not run.

## 1. Upload to GitHub

Use the repository `https://github.com/Alexwatson-de/Skybreak`. Commit source, lockfile, original assets, license notices, cloud configuration, and the small Godot web export template in `vendor/`. Exclude downloaded engines, dependencies, generated builds, CLI credentials, `.env`, and service-account private keys.

The checked-in GitHub workflow builds the web game, runs the authoritative simulation checks and tests real ENet/WebSocket clients and reconnection. Push completed future changes to `main`; never force-push.

## 2. Create the multiplayer server on Render

Import the repository as a Docker **Web Service**, or apply its `render.yaml` Blueprint. Select **Free** and Singapore. Leave payment-method and paid-upgrade flows unused. Keep one instance and `MAX_ROOMS=2` for the free server.

Set:

| Environment variable | Value |
|---|---|
| `GAME_TRANSPORT` | `websocket` |
| `MAX_ROOMS` | `2` |
| `WEB_URL` | final Vercel HTTPS origin, once known |
| `ALLOWED_ORIGINS` | additional exact browser origins, comma-separated, if needed |

Render supplies `PORT` and `RENDER_EXTERNAL_URL`. The server uses that external URL to advertise `wss://…/game/ROOMCODE`; there is no need to expose the internal Godot ports publicly. `PUBLIC_URL`, if set, overrides this automatic URL and must be the actual reachable HTTPS origin.

The Node service proxies the WebSocket handshake and binary frames to the room's Godot process on loopback. It validates browser origins, bounds connections and does not forward cookies or HTTP authorization to the game process. The Godot server separately validates its unique per-player match ticket before sending any state.

Wait for a healthy deployment. `GET https://YOUR_RENDER_HOST/health` must return `ok:true`, `protocol:3`, and `transport:"websocket"`.

## 3. Deploy the website to Vercel

Import the same GitHub repository into an existing **Hobby** workspace. Framework is **Other**; repository root is the project root. `vercel.json` supplies `bash scripts/build_web.sh` and `builds/web` as the output.

Add the production environment variable `SKYBREAK_LOBBY_URL=https://YOUR_RENDER_HOST`, then deploy. The build downloads the pinned official Godot 4.5.1 Linux engine, checks its SHA-256, imports the project, exports the game using the vendored web template, and writes public `lobby.json`. It fails rather than silently shipping a production client pointed at localhost. Development auto-player URL controls are disabled in Vercel builds.

WebAssembly is gzip-compressed ahead of time; Vercel rewrites its public URL to the compressed file with the correct encoding and MIME headers. Keep HTML/configuration revalidated to avoid mixing old clients and new deployments.

Production packaging removes the uncompressed WASM artifact: physical files take precedence over Vercel rewrites. Keeping the raw file with a gzip response header breaks engine startup. A verification download with `curl --compressed` must decode to the WASM magic bytes `00 61 73 6d`.

Once Vercel assigns its final production URL, set that exact origin as Render's `WEB_URL` and redeploy Render. This completes the browser origin allowlist and makes invite links open the live website. Do not allow every `*.vercel.app` domain. Add exact preview origins only when you want those deployments to reach the server.

## 4. Verify the live game

1. Check the Render health response and Vercel asset/config responses.
2. Open the Vercel production URL in two real browser tabs/devices.
3. Create/join a room using its code and invite link; verify chat and team/ready changes.
4. Start a match and verify both players receive authoritative snapshots, move, shoot, take damage and respawn.
5. Force a temporary connection loss and confirm the same player slot reconnects while its grace period is available.
6. Check browser console and server logs for script/runtime errors. Record the actual results rather than assuming local tests prove the deployment.

The website's Connection details panel exposes non-secret runtime diagnostics (FPS, ping, snapshot count and player state). Match tickets and lobby session tokens are excluded.

## Free-hosting limits

Render Free sleeps after 15 minutes without inbound HTTP/WebSocket traffic and can take about a minute to wake. The client retries and shows this state. A sleeping/restarted service loses in-memory rooms and matches. Monthly usage limits apply and free hosting cannot guarantee unlimited players, zero latency or constant availability. No payment method, paid service plan, database or Firebase usage is required by this project.

References: [Render Free](https://render.com/docs/free), [Render WebSockets](https://render.com/docs/websocket), [Vercel project configuration](https://vercel.com/docs/project-configuration).

## Self-host without Render

Run Node.js 22+ and Godot 4.5.1 on an existing computer:

```sh
./scripts/bootstrap.sh
GAME_TRANSPORT=websocket \
PUBLIC_URL=https://YOUR_EXISTING_HOSTNAME \
WEB_URL=https://YOUR_WEBSITE_ORIGIN \
./scripts/lobby.sh
```

Terminate HTTPS/WSS using an existing reverse proxy and proxy upgrade requests to Node port 3000. No additional publicly exposed game port is needed in WebSocket mode. For native ENet-only hosting, choose `GAME_TRANSPORT=enet`, set `PUBLIC_GAME_HOST`, and expose UDP 29500–29507. The same authoritative simulation is used in either case.

Version 1.3 adds a posture field to snapshots and a protocol check to lobby authentication. Deploy the Render server and Vercel client together, then refresh existing browser tabs. Older cached clients receive a refresh/update message instead of joining an incompatible match.
