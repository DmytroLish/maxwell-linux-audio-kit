# Optional: VoiceMeeter-style buses

Three virtual sinks defined in `40-vb-buses.conf`. Only the Game bus is
routed to hardware by a `pw-loopback` unit:

| Bus      | Feeds              | Via unit        | Typical use          |
|----------|--------------------|-----------------|----------------------|
| VB-Game  | Maxwell **Game**   | vb-ear-game     | the game itself      |
| VB-Music | not routed by default | —            | browser / music app bus |
| VB-Team  | (a source for apps)| vb-team-mic + vb-team-music | voice chat input |

Routing rules:

- Game audio goes to the Maxwell Game channel. Voice/chat apps should use
  the Maxwell Chat sink directly.
- Music is **not** routed to Maxwell Chat in this build. VB-Music exists as
  a separate bus for the optional team feed, or for manual patching in
  qpwgraph; if you point an app at VB-Music and do neither, you won't hear
  it — that's deliberate, so the kit never decides your music's channel.
- The Team bus is what your voice app records. It carries the headset mic
  (vb-team-mic) and, if you enable it, the music bus (vb-team-music) mixed
  in as **one feed**. If you share music with your team this way, mute
  discipline is yours: mute the mic node when music plays. Don't want music
  on the team bus at all? Just don't enable `vb-team-music.service`.
- Set each app's output once (game → VB-Game, voice app → Maxwell Chat)
  and your voice app's input to VB-Team; WirePlumber remembers the routing.

Install with `./install.sh --with-buses`, then restart PipeWire once so the
buses conf loads: `systemctl --user restart pipewire wireplumber`.
