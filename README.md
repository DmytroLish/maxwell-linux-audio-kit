# maxwell-linux-audio-kit

Make an **Audeze Maxwell** headset behave on Linux: hot-plug safe, full power,
self-healing — no more dead audio stack because the headset was off.

## The problems this fixes

1. **The dongle is only there when the headset is on.** The Maxwell USB dongle
   (3329:4b19) exposes its ALSA card *only while the headset is powered on*.
   The usual setup — static `pipewire.conf.d` adapters for the Game/Chat/mic
   devices — is therefore fatal: with the headset off, PipeWire fails to start,
   hits its start limit, and takes the *whole* audio stack down with it.
2. **Thin, weak sound.** The dongle's hardware output stage (ALSA `PCM`)
   can sit far below full scale — found at 54/73, i.e. **−20 dB** — so even
   150% in software sounds like earbuds while Windows sounds massive.
3. **The wedged dongle.** Occasionally the dongle presents its card but passes
   no audio. `usbreset` does **not** cure it; only a physical unplug/replug
   (a real power-cycle) does.

## What the kit does

- **Runtime node creation.** The three Maxwell devices (Game sink, Chat sink,
  mic source) are created with `pw-cli` when the card exists and destroyed
  when it vanishes — never from `pipewire.conf.d`. PipeWire starts cleanly
  with the headset on *or* off.
- **Event-driven, zero polling.** A tiny watcher blocks on `udevadm monitor`
  (sound subsystem) and runs the reconciler on add/remove/change. Nothing
  polls your rig.
- **Full-power pin.** Every reconcile sets the dongle's ALSA `PCM` to full
  scale (73/73) on both playback devices. Your headset wheel still wins
  between events.
- **Level memory.** The reconciler snapshots your channel volumes (watchdog
  ticks + the moment the card vanishes) and re-applies them after every
  rebuild, so a heal restores *your* levels — not a stale restore point.
- **A watchdog that knows what a failure is.** Every ~3 minutes it checks the
  audio units and the journal. It restarts the stack only on provable failure
  (dead units, zombie-PCM spew) — and it has a **hot-plug grace**: journal
  noise from a plug event the reconciler is handling is never a restart
  reason. After a heal it reconciles the Maxwell nodes and unmutes streams.
- **Optional VoiceMeeter-style buses** (`--with-buses`): three virtual sinks
  (Game / Music / Team) routed into the Maxwell's separate Game and Chat
  channels with `pw-loopback` units. See `optional-vb-buses/README.md`.

## Requirements

PipeWire + WirePlumber, a systemd user session, `python3`, `wpctl`, `pw-cli`,
`pw-link`, `amixer` (alsa-utils), `udevadm`. Tested on Bazzite (Fedora Atomic,
KDE/Wayland) with an original Maxwell; should work on any systemd + PipeWire
distro. Maxwell 2 is untested.

## Install

```sh
./install.sh              # core kit
./install.sh --with-buses # core + the VB-Game / VB-Music / VB-Team buses
```

The installer parks any static dongle adapters it finds in
`~/.config/pipewire/pipewire.conf.d/` (renamed to `.disabled`) — see problem 1.
Everything lands in `~/.local/bin` and `~/.config/systemd/user`; nothing is
touched system-wide.

## Verify

Turn the headset off and on, pull and replug the dongle, reboot — the stack
stays up and the devices come back by themselves, at your levels.

- State: `wpctl status`
- Reconciler log: `~/.local/share/maxwell-reconcile/reconcile.log`
- Watchdog log: `~/.local/share/audio-watchdog/watchdog.log`

## Notes

- The watchdog guards only systemd units that exist on your system, so a
  core-only install never reads the optional bus units as "broken".
- EQ presets, sidetone and other headset DSP settings are out of scope —
  see [HeadsetControl](https://github.com/Sapd/HeadsetControl) for those.
- One honest limit: if the dongle wedges (problem 3), software cannot
  power-cycle USB for you on most hubs — unplug it for ~10 seconds.

## License

MIT — see `LICENSE`.
