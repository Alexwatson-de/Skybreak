# Open-source dependencies

The game code, procedural pilot/arena artwork, icon and synthesized effects are original to this project. No reference-game assets are used.

- Godot Engine 4.5.1 — MIT and bundled third-party licenses. https://godotengine.org/license/ . The runtime and export builds retain Godot's bundled license notices.
- Socket.IO / Engine.IO and socket.io-client — MIT. https://github.com/socketio/socket.io
- Zod — MIT. https://github.com/colinhacks/zod
- TypeScript — Apache-2.0. https://github.com/microsoft/TypeScript
- tsx — MIT. https://github.com/privatenumber/tsx
- @types/node — MIT. https://github.com/DefinitelyTyped/DefinitelyTyped
- Node.js — MIT and bundled third-party licenses. https://nodejs.org/en/about

Pinned direct versions and exact transitive versions are in backend/package-lock.json. Individual packages include their licenses in node_modules after installation. The game uses Godot's bundled fallback font; no separately downloaded font is required.

Full Godot notices are included in `docs/licenses/` and copied into the native and browser builds.

## Pixabay weapon audio (1.3)

Six processed game samples derive from “Gun shot 1” by EAGLAXLE on Pixabay. These are governed by the Pixabay Content License, not MIT. Source, creator, processing and license links are in [the audio notice](docs/licenses/PIXABAY-AUDIO.md). The original stock recording is not included.
