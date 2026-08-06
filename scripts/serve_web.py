#!/usr/bin/env python3
"""Local dev server for the Godot Web export.

Godot 4's Web builds need cross-origin isolation headers (COOP/COEP) to
enable SharedArrayBuffer, which the pthread-based wasm runtime uses.
`python3 -m http.server` doesn't send those, so the game shows a blank
screen. This wrapper adds them and points at build/web/ by default.

Usage:
    python3 scripts/serve_web.py            # defaults: build/web on port 8000
    python3 scripts/serve_web.py --port 3000
    python3 scripts/serve_web.py --dir some/other/build/dir
"""
from __future__ import annotations

import argparse
import http.server
import os
import socketserver
import sys


class COIHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:  # type: ignore[override]
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.strip())
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--dir", default="build/web",
                        help="Directory to serve (relative to the project root)")
    args = parser.parse_args()

    root = os.path.abspath(args.dir)
    if not os.path.isdir(root):
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 1
    os.chdir(root)

    with socketserver.TCPServer(("", args.port), COIHandler) as httpd:
        print(f"Serving {root} at http://localhost:{args.port}/  (Ctrl-C to stop)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
