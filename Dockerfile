FROM node:22-bookworm-slim AS lobby
WORKDIR /app
COPY backend/package*.json ./
RUN npm ci
COPY backend/tsconfig.json ./
COPY backend/src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libgl1 libasound2 libpulse0 && rm -rf /var/lib/apt/lists/* \
 && curl --fail -L --retry 2 https://github.com/godotengine/godot/releases/download/4.5.1-stable/Godot_v4.5.1-stable_linux.x86_64.zip -o /tmp/godot.zip \
 && echo "02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd  /tmp/godot.zip" | sha256sum --check - \
 && unzip /tmp/godot.zip -d /opt && mv /opt/Godot_v4.5.1-stable_linux.x86_64 /opt/godot && rm /tmp/godot.zip
WORKDIR /app/backend
COPY --from=lobby /app/dist ./dist
COPY --from=lobby /app/node_modules ./node_modules
COPY --from=lobby /app/package.json ./package.json
COPY game /app/game
RUN chown -R node:node /app
USER node
ENV GODOT_BIN=/opt/godot GAME_PATH=/app/game PORT=3000 GAME_PORT_BASE=29500 MAX_ROOMS=2 GAME_TRANSPORT=websocket
EXPOSE 3000/tcp 29500-29507/udp
CMD ["node","dist/index.js"]
