# VBAN Bridge — Home Assistant add-on

Streams a line-level audio input on the Home Assistant host to
[Music Assistant](https://music-assistant.io) as a **VBAN** source, so a
turntable, tape deck or CD player connected to a USB audio interface can play
on any Music Assistant player or speaker group.

```
turntable ──► phono stage ──► USB audio interface ──► PulseAudio
                                                        │
                                              VBAN Bridge (this add-on)
                                                        │  VBAN/UDP 127.0.0.1:6980
                                                        ▼
                                          Music Assistant — VBAN Receiver
                                                        │
                                                        ▼
                                              any MA player or group
```

## Why an add-on is needed

Music Assistant 2.10.x can play a **VBAN** stream but cannot capture a USB
line-in by itself: its Sendspin *source* plugin needs a device that advertises
a `source@v1` capability, and its Local Audio app is output-only. Something on
the host has to open the input and packetise it. This add-on is that something:
it runs [`quiniouben/vban`](https://github.com/quiniouben/vban) `vban_emitter`
against Home Assistant's PulseAudio input.

## Installation

1. Settings → Apps (the old Add-ons panel) → **App store** → ⋮ →
   **Repositories**, add `https://github.com/Thrasher2020/vban-bridge`, then
   install **VBAN Bridge**.
2. On its **Configuration** tab, set **Audio input** to the interface the
   source is plugged into (for example the Behringer UCA222). Leave the other
   options alone unless you need to change them.
3. Start the add-on and check the log — it should report the stream it is
   sending.

Both add-ons run on the host network, so the default target
`127.0.0.1:6980` never leaves the machine.

## Music Assistant setup

1. Settings → Providers → **Add provider** → **VBAN Receiver**.
2. Configure it to match this add-on:

   | VBAN Receiver setting | Value |
   | --- | --- |
   | UDP port | `6980` |
   | Stream name | `VinylBridge` |
   | Sender IP | `127.0.0.1` (or leave open) |
   | PCM format | `S16LE` |
   | Sample rate | `48000` |
   | Channels | `2` |

3. In Music Assistant, open **Live Inputs**, pick the VBAN stream and play it
   on a player or group.

If you change `sample_rate`, `channels`, `format`, `ma_port` or `stream_name`
in the add-on options, change the matching field on the plugin too — the two
sides must agree.

## Running alongside Vinyl Listener

The add-on can stay running while the **Vinyl Listener** add-on is also
recording from the same interface. Both are PulseAudio clients, so the single
input is shared rather than seized by one of them. Vinyl identification is
unaffected; this add-on simply keeps sending the same audio to Music Assistant.

## Limits

- **Latency** is roughly one to three seconds end to end, depending on the
  player. Fine for casual listening, not for video sync.
- **No automatic switching.** The stream runs whenever the add-on is started;
  it does not know about needle drops. Use the add-on's start/stop, or an
  automation calling `hassio.addon_start` / `hassio.addon_stop`, if you want it
  tied to the turntable switch.
- **One Music Assistant target at a time.** Playback is controlled from Music
  Assistant once the Live Input is playing; use a speaker group for several
  rooms.
- **16-bit, up to 48 kHz.** That is the limit of the UCA222 class of interface,
  and it is what Music Assistant's Live Input expects.
- The stream is sent continuously whenever the add-on is running, including
  silence. On loopback that costs nothing measurable.

## Options

| Option | Default | Notes |
| --- | --- | --- |
| `ma_host` | `127.0.0.1` | Music Assistant address |
| `ma_port` | `6980` | VBAN UDP port |
| `stream_name` | `VinylBridge` | 1–16 letters or digits |
| `sample_rate` | `48000` | `44100` or `48000` |
| `channels` | `2` | `1` or `2` |
| `format` | `16I` | `16I`, `24I`, `32I`, `32F` |
| `alsa_device` | `pulse` | ALSA PCM name on the host |
| `buffer_size` | `1024` | Frames per packet |
| `log_level` | `3` | 0 fatal … 4 debug |
