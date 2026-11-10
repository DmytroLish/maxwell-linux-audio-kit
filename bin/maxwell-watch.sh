#!/bin/bash
# maxwell-watch.sh - event-driven trigger for maxwell-reconcile.sh.
# Blocks on the udev netlink socket (sound subsystem); zero polling.
"$HOME/.local/bin/maxwell-reconcile.sh"
udevadm monitor --kernel --subsystem-match=sound 2>/dev/null | while IFS= read -r line; do
  case "$line" in
    *add*|*remove*|*change*)
      sleep 2
      "$HOME/.local/bin/maxwell-reconcile.sh"
      ;;
  esac
done
