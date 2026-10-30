#!/bin/sh
# Scripted stand-in for an agent write-back. This is not a live model.
# It creates one session note in a vault copy so a demo can re-import it.
# Usage: docs/simulated-agent-step.sh DEST
set -eu

if [ $# -ne 1 ]; then
  echo "Usage: docs/simulated-agent-step.sh DEST" >&2
  exit 2
fi

dest=$1
if [ ! -d "$dest/sessions" ]; then
  echo "simulated-agent-step: sessions directory not found: $dest/sessions" >&2
  exit 1
fi

note="$dest/sessions/2026-10-23.md"
cat > "$note" <<'EOF'
---
type: session
tags:
  - session
created: 2026-10-23
updated: 2026-10-23
sources:
  - "[[wiki/projects/garden-planner]]"
---

# Session 2026-10-23

Simulated agent step, not a live model.

Sam Rivera keeps garden planner bed maps on the device. Index phrase: cedar-latch session note.
EOF

echo "simulated agent step, not a live model"
echo "wrote sessions/2026-10-23.md"
