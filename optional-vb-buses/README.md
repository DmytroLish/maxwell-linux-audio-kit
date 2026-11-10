# Optional: VoiceMeeter-style buses

Three virtual sinks defined in `40-vb-buses.conf`, routed by `pw-loopback`
units into the Maxwell's two hardware channels:

| Bus      | Feeds              | Via unit        | Typical use          |
|----------|--------------------|-----------------|----------------------|
| VB-Game  | Maxwell **Game**   | vb-ear-game     | the game itself      |
| VB-Music | Maxwell **Chat**   | vb-ear-music    | browser / music app  |
| VB-Team  | (a source for apps)| vb-team-mic + vb-team-music | voice chat input |

Routing rules:

- Game audio goes to the Game channel only; music to the Chat channel only —
  separate KDE sliders, separate levels, both remembered by the reconciler.
- The Team bus is what your voice app records. It carries the headset mic
  (vb-team-mic) and, if you enable it, the music bus (vb-team-music) mixed in
  as **one feed**. If you share music with your team this way, mute discipline
  is yours: mute the mic node when music plays. Don't want music on the team
  bus at all? Just don't enable `vb-team-music.service`.
- Set each app's output once (game → VB-Game, browser → VB-Music) and your
  voice app's input to VB-Team; WirePlumber remembers the routing.

Install with `./install.sh --with-buses`, then restart PipeWire once so the
buses conf loads: `systemctl --user restart pipewire wireplumber`.
