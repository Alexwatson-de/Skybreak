# Skybreak Arena working agreements

- Keep the game free. Do not add purchases, advertisements, paid hosting plans, or billing integrations.
- Preserve the original characters, maps, and assets. Do not copy Mini Militia material.
- Keep the authoritative Godot simulation shared between practice, native LAN/ENet, and browser/desktop online WebSocket modes. Clients send intentions and cannot award health, ammunition, damage, kills, or scores.
- The user explicitly requested that future code changes also be updated in `https://github.com/Alexwatson-de/Skybreak`. After completing and checking authorized changes, commit and push this repository without asking for the same authorization again. If authentication is unavailable, preserve the commit and explain the exact blocker. Never force-push or overwrite remote history.
- Vercel hosts the browser client. Render's **Free** Docker service hosts the Node/Socket.IO lobby and Godot processes. Do not substitute a paid service. Do not claim a deployment or live multiplayer test succeeded without returned deployment evidence and a real client check.
- Rebuild the browser export after game changes (`bash scripts/build_web.sh`). Run simulation and relevant networking tests; retain public, sanitized verification evidence in `docs/`.
- Never commit access tokens, service-account private keys, `.env`, CLI authentication files, or runtime match tickets. Firebase is not required for gameplay.
