#!/bin/bash
# maxwell-reconcile.sh - keep PipeWire's Maxwell nodes matched to the dongle.
# The Maxwell dongle exposes its ALSA card only while the headset is on.
# Card present -> the three adapter nodes must exist (created at runtime,
# never from pipewire.conf.d: a conf.d adapter for a missing card kills
# pipewire at startup). Card absent -> the nodes must not exist.
# Idempotent; safe to run any time. Logs under ~/.local/share/maxwell-reconcile/
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path="$XDG_RUNTIME_DIR/bus"
LOGDIR="$HOME/.local/share/maxwell-reconcile"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/reconcile.log"
exec 9>"$LOGDIR/.lock"
flock -n 9 || exit 0
log() { echo "[$(date '+%F %T')] $*" >>"$LOG"; }

LEVELS="$LOGDIR/levels.env"

vol_pct() { # node.name -> int percent via wpctl
  local id v
  id=$(node_id "$1")
  [ -z "$id" ] && return 0
  v=$(wpctl get-volume "$id" 2>/dev/null | awk '{print $2}')
  [ -n "$v" ] && awk -v x="$v" 'BEGIN{printf "%d", x*100+0.5}'
}

snapshot_levels() {
  local g c m eg tmp
  g=$(vol_pct maxwell-game); c=$(vol_pct maxwell-chat); m=$(vol_pct maxwell-mic)
  eg=$(vol_pct output.vb-ear-game)
  [ -z "$g$c$m$eg" ] && return 0
  tmp="$LEVELS.tmp"
  { [ -n "$g" ] && echo "GAME=$g"; [ -n "$c" ] && echo "CHAT=$c"; [ -n "$m" ] && echo "MIC=$m"
    [ -n "$eg" ] && echo "EARGAME=$eg"; } > "$tmp" && mv "$tmp" "$LEVELS"
}

set_vol() { # node.name percent
  local id
  id=$(node_id "$1")
  [ -z "$id" ] && return 0
  wpctl set-volume "$id" "$(awk -v p="$2" 'BEGIN{printf "%.2f", p/100}')" >/dev/null 2>&1
}

apply_levels() {
  [ -f "$LEVELS" ] || return 0
  . "$LEVELS"
  [ -n "${GAME:-}" ] && set_vol maxwell-game "$GAME"
  [ -n "${CHAT:-}" ] && set_vol maxwell-chat "$CHAT"
  [ -n "${MIC:-}" ] && set_vol maxwell-mic "$MIC"
  [ -n "${EARGAME:-}" ] && set_vol output.vb-ear-game "$EARGAME"
  log "levels applied: game=${GAME:-?} chat=${CHAT:-?} mic=${MIC:-?} eargame=${EARGAME:-?}"
}

pw-cli info >/dev/null 2>&1 || { log "pipewire not reachable; nothing to do"; exit 0; }

node_id() {
  pw-dump 2>/dev/null | python3 -c "
import json,sys
want='$1'
try: data=json.load(sys.stdin)
except Exception: sys.exit(0)
for o in data:
    p=(o.get('info') or {}).get('props') or {}
    if p.get('node.name')==want:
        print(o['id']); break
"
}

create_nodes() {
  pw-cli create-node adapter '{ factory.name=api.alsa.pcm.sink node.name="maxwell-game" node.description="Audeze Maxwell Game" media.class="Audio/Sink" api.alsa.path="hw:Dongle,0" audio.format="S24LE" audio.rate=48000 audio.channels=2 audio.position="FL,FR" object.linger=true }' >/dev/null 2>&1
  pw-cli create-node adapter '{ factory.name=api.alsa.pcm.sink node.name="maxwell-chat" node.description="Audeze Maxwell Chat" media.class="Audio/Sink" api.alsa.path="hw:Dongle,1" audio.format="S16LE" audio.rate=48000 audio.channels=2 audio.position="FL,FR" object.linger=true }' >/dev/null 2>&1
  pw-cli create-node adapter '{ factory.name=api.alsa.pcm.source node.name="maxwell-mic" node.description="Audeze Maxwell Mic" media.class="Audio/Source" api.alsa.path="hw:Dongle,0" audio.format="S16LE" audio.rate=48000 audio.channels=1 object.linger=true }' >/dev/null 2>&1
}

repair_links() {
  pw-link output.vb-ear-game:output_FL maxwell-game:playback_FL 2>/dev/null
  pw-link output.vb-ear-game:output_FR maxwell-game:playback_FR 2>/dev/null
  pw-link maxwell-mic:capture_MONO input.vb-team-mic:input_MONO 2>/dev/null
  pw-link -d maxwell-mic:capture_MONO maxwell-game:playback_FL 2>/dev/null
  pw-link -d maxwell-mic:capture_MONO maxwell-game:playback_FR 2>/dev/null
  pw-link -d maxwell-mic:capture_MONO maxwell-chat:playback_FL 2>/dev/null
  pw-link -d maxwell-mic:capture_MONO maxwell-chat:playback_FR 2>/dev/null
  true
}

if [ "${1:-}" = "--snapshot" ]; then snapshot_levels; exit 0; fi

if grep -q 'Dongle' /proc/asound/cards; then
  missing=0
  for n in maxwell-game maxwell-chat maxwell-mic; do
    [ -z "$(node_id "$n")" ] && missing=1
  done
  if [ "$missing" = 1 ]; then
    create_nodes
    sleep 3
    apply_levels
    log "card present: created missing Maxwell nodes"
  fi
  # Pin the dongle's hardware output stage to full (73 = top step, ~0 dB).
  # It was found at 54 (-20 dB) - the 'thin sound' choke.
  # Standing level: full. Runs only on card events / heals, so the
  # headset wheel still wins between events.
  amixer -c Dongle sset 'PCM',0 73 >/dev/null 2>&1
  amixer -c Dongle sset 'PCM',1 73 >/dev/null 2>&1
  repair_links
else
  snapshot_levels
  for n in maxwell-game maxwell-chat maxwell-mic; do
    id="$(node_id "$n")"
    if [ -n "$id" ]; then
      pw-cli destroy "$id" >/dev/null 2>&1 && log "card absent: destroyed $n (id $id)"
    fi
  done
fi
exit 0
