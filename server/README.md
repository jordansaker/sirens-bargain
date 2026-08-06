# Siren's Bargain relay

Two-peer WebSocket relay used by the online-play mode. **No game logic here** —
the server hands out short room codes, accepts two connections per room, and
forwards every message from one peer to the other.

## Run it locally

```
cd server
npm install
npm start
```

Defaults: binds `0.0.0.0:8765`. Override with `PORT` / `HOST` env vars.

## Endpoints

- `POST /rooms` → `{ "code": "ABCDE" }`
- `GET  /health` → `ok, N rooms\n`
- `WS   /ws`     → the peer socket (see message envelope below)

## Wire protocol

Client → server:

```json
{ "op": "hello",   "room": "ABCDE" }              // first message after connect
{ "op": "message", "payload": { ... anything ... } }
```

Server → client:

```json
{ "op": "joined",      "peer_id": 0, "peers": 1 }
{ "op": "peer_joined", "peer_id": 1 }              // sent to peer 0 when peer 1 arrives
{ "op": "message",     "from": 0,    "payload": { ... } }
{ "op": "peer_left" }
{ "op": "error",       "reason": "room_full" | "no_such_room" | "bad_hello" | ... }
```

The `payload` bodies are the game's own event protocol (see
`scripts/net/MessageProtocol.gd` on the Godot side). The relay is
message-agnostic.

## Deploy

Any single-container Node host works — Fly.io, Render, Railway, an EC2
micro. The container needs:

- Node 18+ (see `engines` in `package.json`)
- One public TCP port (default 8765)
- WebSocket support (all mainstream PaaS handle this natively)

Example Dockerfile if you're rolling your own:

```
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./
EXPOSE 8765
CMD ["node", "server.js"]
```
