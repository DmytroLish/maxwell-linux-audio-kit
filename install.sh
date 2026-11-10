#!/usr/bin/env bash
# install.sh - install the Maxwell Linux audio kit for the current user.
# Usage: ./install.sh [--with-buses]
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_BUSES=0
[ "${1:-}" = "--with-buses" ] && WITH_BUSES=1

mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user" \
         "$HOME/.local/share/maxwell-reconcile" "$HOME/.local/share/audio-watchdog"


# Public builds do not route VB-Music to the Maxwell Chat channel. Remove the
# legacy vb-ear-music unit from earlier installs so an upgrade cannot keep
# that route alive.
if [ -f "$HOME/.config/systemd/user/vb-ear-music.service" ]; then
  systemctl --user disable --now vb-ear-music.service >/dev/null 2>&1 || true
  rm -f "$HOME/.config/systemd/user/vb-ear-music.service"
  echo "removed legacy vb-ear-music unit (music is not routed to Chat)"
fi

install -m 0755 "$KIT/bin/maxwell-reconcile.sh" "$HOME/.local/bin/"
install -m 0755 "$KIT/bin/maxwell-watch.sh"     "$HOME/.local/bin/"
install -m 0755 "$KIT/bin/audio-watchdog.sh"    "$HOME/.local/bin/"
install -m 0644 "$KIT/systemd/maxwell-watch.service"  "$HOME/.config/systemd/user/"
install -m 0644 "$KIT/systemd/audio-watchdog.service" "$HOME/.config/systemd/user/"
install -m 0644 "$KIT/systemd/audio-watchdog.timer"   "$HOME/.config/systemd/user/"

# Park any static pipewire.conf.d adapters for the dongle. They are FATAL:
# the dongle exposes its ALSA card only while the headset is on, so a static
# adapter makes pipewire refuse to start whenever the headset is off.
CONFD="$HOME/.config/pipewire/pipewire.conf.d"
if [ -d "$CONFD" ]; then
  for f in "$CONFD"/*.conf; do
    [ -e "$f" ] || continue
    if grep -q 'api.alsa.pcm' "$f" && grep -q 'Dongle' "$f"; then
      mv "$f" "$f.disabled"
      echo "parked static dongle adapter: $f -> $f.disabled"
    fi
  done
fi

if [ "$WITH_BUSES" = 1 ]; then
  mkdir -p "$CONFD"
  install -m 0644 "$KIT/optional-vb-buses/40-vb-buses.conf" "$CONFD/"
  for u in vb-ear-game vb-team-music vb-team-mic; do
    install -m 0644 "$KIT/optional-vb-buses/$u.service" "$HOME/.config/systemd/user/"
  done
fi

systemctl --user daemon-reload
systemctl --user enable --now maxwell-watch.service audio-watchdog.timer
if [ "$WITH_BUSES" = 1 ]; then
  systemctl --user enable --now vb-ear-game vb-team-music vb-team-mic
  echo "NOTE: the VB buses conf loads at pipewire start - restart it once:"
  echo "  systemctl --user restart pipewire wireplumber"
fi

"$HOME/.local/bin/maxwell-reconcile.sh" || true
echo "Installed. Turn the headset on and check: wpctl status"
echo "Logs: ~/.local/share/maxwell-reconcile/reconcile.log"
echo "      ~/.local/share/audio-watchdog/watchdog.log"
