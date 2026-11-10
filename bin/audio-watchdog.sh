#!/bin/bash
# audio-watchdog.sh - restart the PipeWire stack ONLY when it is provably broken.
# Signatures: (A) any audio unit/socket failed or inactive;
# (B) zombie PCM spew: >50 "No such device" journal lines in the last minute.
# Healthy system: spew is 0 and all units active -> exit 0, no-op. Short-lived oneshot, no resident process.
# After a heal, reconcile the Maxwell nodes (the headset may be on) and
# unmute every sink-input - a heal is a fresh start, and a stream-restore
# mute must not survive it.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
LOGDIR="$HOME/.local/share/audio-watchdog"
LOG="$LOGDIR/watchdog.log"
STAMP="$LOGDIR/last-fire"
mkdir -p "$LOGDIR"
# Level memory: snapshot the Maxwell channel volumes so a heal restores
# the levels last set, not a stale restore.
~/.local/bin/maxwell-reconcile.sh --snapshot >/dev/null 2>&1
UNITS="pipewire.service pipewire-pulse.service wireplumber.service vb-ear-game.service vb-team-music.service vb-team-mic.service"
SOCKETS="pipewire.socket pipewire-pulse.socket"
# Guard only units that exist on this system (the vb-* units come with the
# optional buses; a core-only install must not read them as "broken").
GUARDED=""
for u in $UNITS $SOCKETS; do
  systemctl --user cat "$u" >/dev/null 2>&1 && GUARDED="$GUARDED $u"
done
broken=""
for u in $GUARDED; do
  st=$(systemctl --user is-active "$u" 2>/dev/null)
  if [ "$st" = "failed" ] || [ "$st" = "inactive" ]; then broken="$broken $u=$st"; fi
done
# Hot-plug grace (v3): a Maxwell card event makes pipewire spew
# 'No such device' while the reconciler rebuilds - expected noise, never a
# restart reason. An earlier version false-fired on a dongle test and
# killed the user's music stream.
if [ -n "$(find ~/.local/share/maxwell-reconcile/reconcile.log -mmin -2 2>/dev/null)" ]; then
  spew=0
else
  spew=$(journalctl --user --since '1 min ago' --no-pager 2>/dev/null | grep -c 'No such device')
fi
[ "$spew" -gt 50 ] && broken="$broken spew=${spew}/min"
[ -z "$broken" ] && exit 0
now=$(date +%s)
if [ -f "$STAMP" ]; then
  last=$(cat "$STAMP" 2>/dev/null || echo 0)
  [ $((now - last)) -lt 120 ] && exit 0
fi
echo "$now" > "$STAMP"
echo "$(date '+%F %T') FIRING - broken:$broken - restarting audio stack" >> "$LOG"
systemctl --user reset-failed $GUARDED 2>/dev/null
systemctl --user restart $GUARDED >> "$LOG" 2>&1
echo "$(date '+%F %T') restart issued" >> "$LOG"
sleep 3
"$HOME/.local/bin/maxwell-reconcile.sh" >> "$LOG" 2>&1
for idx in $(pactl list short sink-inputs 2>/dev/null | awk '{print $1}'); do
  pactl set-sink-input-mute "$idx" 0 2>/dev/null
done
echo "$(date '+%F %T') post-heal: reconcile + unmute done" >> "$LOG"
exit 0
