// Siren's Bargain — two-peer WebSocket relay.
//
// No game logic lives here. Peers connect with a 5-char room code; the second
// peer to arrive is paired with the first, and every message from either side
// is forwarded as-is to the other. First peer to arrive is player 0 (host),
// second is player 1. That mapping is echoed back to each peer on join so
// the Godot side knows which player it controls.
//
// Message envelope (JSON on the wire):
//   incoming from clients:
//     { "op": "hello",   "room": "ABCDE" }          // first message
//     { "op": "message", "payload": {...} }         // relayed to other peer
//   outgoing to clients:
//     { "op": "joined",  "peer_id": 0|1, "peers": N }
//     { "op": "peer_joined", "peer_id": 1 }         // sent to host when guest arrives
//     { "op": "message", "from": 0|1, "payload": {...} }
//     { "op": "peer_left" }
//     { "op": "error",   "reason": "room_full" | "bad_hello" | ... }
//
// Env vars:
//   PORT   — listening port (default 8765)
//   HOST   — bind address (default 0.0.0.0)

import { WebSocketServer } from "ws";
import { createServer } from "node:http";

const PORT = Number.parseInt(process.env.PORT ?? "8765", 10);
const HOST = process.env.HOST ?? "0.0.0.0";
const MAX_PEERS_PER_ROOM = 2;
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no I/O/0/1
const CODE_LENGTH = 5;

/** @type {Map<string, {peers: Array<{ws: WebSocket, id: number}>}>} */
const rooms = new Map();

function randomCode() {
    let code = "";
    for (let i = 0; i < CODE_LENGTH; i++) {
        code += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
    }
    return code;
}

function newRoomCode() {
    for (let attempts = 0; attempts < 20; attempts++) {
        const code = randomCode();
        if (!rooms.has(code)) return code;
    }
    // Astronomically unlikely at 32^5 ~= 33M codes with a small live set.
    throw new Error("could not allocate a fresh room code");
}

function send(ws, obj) {
    if (ws.readyState !== ws.OPEN) return;
    ws.send(JSON.stringify(obj));
}

const httpServer = createServer((req, res) => {
    if (req.method === "POST" && req.url === "/rooms") {
        const code = newRoomCode();
        rooms.set(code, { peers: [] });
        res.writeHead(200, {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        });
        res.end(JSON.stringify({ code }));
        return;
    }
    if (req.method === "OPTIONS") {
        res.writeHead(204, {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
        });
        res.end();
        return;
    }
    if (req.method === "GET" && req.url === "/health") {
        res.writeHead(200, { "Content-Type": "text/plain" });
        res.end(`ok, ${rooms.size} rooms\n`);
        return;
    }
    res.writeHead(404);
    res.end();
});

const wss = new WebSocketServer({ server: httpServer, path: "/ws" });

wss.on("connection", (ws) => {
    /** @type {string | null} */
    let joinedRoom = null;
    /** @type {number} */
    let myId = -1;

    ws.on("message", (raw) => {
        let msg;
        try {
            msg = JSON.parse(raw.toString());
        } catch {
            send(ws, { op: "error", reason: "bad_json" });
            return;
        }

        if (!joinedRoom) {
            if (msg?.op !== "hello" || typeof msg.room !== "string") {
                send(ws, { op: "error", reason: "bad_hello" });
                ws.close();
                return;
            }
            const code = msg.room.toUpperCase();
            const room = rooms.get(code);
            if (!room) {
                send(ws, { op: "error", reason: "no_such_room" });
                ws.close();
                return;
            }
            if (room.peers.length >= MAX_PEERS_PER_ROOM) {
                send(ws, { op: "error", reason: "room_full" });
                ws.close();
                return;
            }
            myId = room.peers.length;
            room.peers.push({ ws, id: myId });
            joinedRoom = code;
            send(ws, { op: "joined", peer_id: myId, peers: room.peers.length });
            // Notify the other peer (if any) that we arrived.
            for (const peer of room.peers) {
                if (peer.ws !== ws) {
                    send(peer.ws, { op: "peer_joined", peer_id: myId });
                }
            }
            return;
        }

        // Relay any subsequent message to the OTHER peer in the room.
        if (msg?.op !== "message") {
            send(ws, { op: "error", reason: "unexpected_op" });
            return;
        }
        const room = rooms.get(joinedRoom);
        if (!room) return;
        for (const peer of room.peers) {
            if (peer.ws !== ws) {
                send(peer.ws, { op: "message", from: myId, payload: msg.payload });
            }
        }
    });

    ws.on("close", () => {
        if (!joinedRoom) return;
        const room = rooms.get(joinedRoom);
        if (!room) return;
        room.peers = room.peers.filter((p) => p.ws !== ws);
        for (const peer of room.peers) {
            send(peer.ws, { op: "peer_left" });
        }
        if (room.peers.length === 0) {
            rooms.delete(joinedRoom);
        }
    });
});

httpServer.listen(PORT, HOST, () => {
    console.log(`Siren's Bargain relay listening on ${HOST}:${PORT}`);
    console.log(`  POST http://localhost:${PORT}/rooms       to create a room`);
    console.log(`  WS   ws://localhost:${PORT}/ws            for peers`);
    console.log(`  GET  http://localhost:${PORT}/health      for a heartbeat`);
});
