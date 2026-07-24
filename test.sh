#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Refresh the global class_name registry so newly-added class_name scripts
# are visible to the test runner. Idempotent — fast when nothing changed.
godot --headless --editor --quit >/dev/null 2>&1 || true

exec godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
