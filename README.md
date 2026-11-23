# VBAN Bridge

**Turn a turntable, tape deck or CD player plugged into your Home Assistant box into a Music Assistant source.**

[![GitHub release](https://img.shields.io/github/v/release/Thrasher2020/vban-bridge?display_name=tag&sort=semver)](https://github.com/Thrasher2020/vban-bridge/releases)
![Architectures](https://img.shields.io/badge/arch-amd64%20%7C%20aarch64-informational)
![Home Assistant](https://img.shields.io/badge/Home%20Assistant-OS%20%7C%20Supervised-41BDF5)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)

VBAN Bridge is a small Home Assistant add-on that captures a line input on the
host and streams it to [Music Assistant](https://www.music-assistant.io) over
VBAN. In Music Assistant it behaves like an aux input: play it on any player or
speaker group, in one room or all of them, from a record.

## Why this exists

Music Assistant 2.10 can *receive* a VBAN stream, but it cannot open a USB
line-in by itself:

- The **Local Audio** app is a Sendspin *player* — audio out, not in.
- The **Sendspin Source** plugin needs a remote device that advertises a
  `source@v1` capability. A USB interface plugged into the machine running
  Music Assistant is not such a device.
- There is no "local ALSA input" provider; the upstream pull request for one
  was never merged.

So something on the host has to open the input and packetise it. This add-on is
that something: it runs [`vban_emitter`](https://github.com/quiniouben/vban)
against Home Assistant's PulseAudio input.

## How it works

```
turntable / tape / CD
        │  line level (vinyl needs a phono stage first)
        ▼
USB audio interface ──► PulseAudio ──► vban_emitter ──► VBAN/UDP
                                        (this add-on)   127.0.0.1:6980
                                                            │
                                                            ▼
                                     Music Assistant — VBAN Receiver plugin
                                                            │
                                                            ▼
                                                any player or speaker group
```

Details worth knowing:

- **No transcoding.** PCM goes from the interface to the UDP socket untouched,
  so CPU use is negligible and nothing is added to the signal path.
- **`audio: true`** gives the add-on Home Assistant's PulseAudio input and its
  own **Audio input** selector on the Configuration tab. `vban_emitter` records
  from the ALSA `pulse` PCM.
- **`host_network: true`** means this add-on and the Music Assistant add-on
  share the host's loopback, so the default target `127.0.0.1:6980` never
  touches your network. Nothing to open in a firewall.
- The image builds `vban_emitter` from source when installed, pinned to v2.2.0
  (`9c3d558`), ALSA backend only.

## Requirements

- Home Assistant OS or Supervised, with add-ons available. This is an add-on,
  not an integration.
- Music Assistant add-on **2.10 or newer**, for its VBAN Receiver plugin.
- A **line-level** audio source. Vinyl needs a phono stage before the
  interface — either built into the turntable (e.g. AT-LP3BK) or a separate
  preamp. A UCA222/UCA202/UFO202 is line-in only and has no phono input.
- A USB audio interface ALSA can see. Class-compliant interfaces work; the
  PCM2902-based UCA series is what this was developed against.
- Architectures: `amd64`, `aarch64`.
- For the `switch` or `power` gate, a switch or power sensor for the source
  (for example a smart plug). The add-on reads it through the Home Assistant
  API, which it is granted automatically.

## Installation

1. Settings → Apps → **App store** → ⋮ → **Repositories**
2. Add `https://github.com/Thrasher2020/vban-bridge`
3. Install **VBAN Bridge**
4. On its **Configuration** tab set **Audio input** to your interface — not
   *Default*, or it may record from something else entirely
5. Start it. The log should show:

```
[vban_bridge] sending stream 'VinylBridge' to 127.0.0.1:6980 (48000 Hz, 2 ch, 16I) from ALSA device 'pulse'
```

Installing builds the image, which takes a few minutes the first time.

## Music Assistant setup

VBAN Receiver is a **plugin**, not a player provider — that distinction costs
most people ten minutes, because the Providers page is dominated by player
providers and nothing there will ever list it.

**Settings → Plugins → Add a plugin → VBAN Receiver**, then match the add-on:

| Music Assistant setting | Value |
| --- | --- |
| Receiver: UDP Port | `6980` |
| Sender: VBAN Stream Name | `VinylBridge` |
| Sender: VBAN Sender hostname/IP address | `127.0.0.1` |
| PCM audio format | `S16LE` |
| PCM sample rate | `48000` |
| Channels | `2` |

Leave the ADVANCED fields alone: `0.0.0.0` bind is what you want, and the
default queue strategy is fine over loopback.

Then play it: **Browse** → the VBAN stream → play → choose a player or group.

If you change `ma_port`, `stream_name`, `sample_rate`, `channels` or `format`
in the add-on options, change the same field in the plugin. The two sides must
agree; a mismatch produces silence with no error on either side.

## Options

| Option | Default | Notes |
| --- | --- | --- |
| `ma_host` | `127.0.0.1` | Music Assistant address. Only change it if Music Assistant is on another machine. |
| `ma_port` | `6980` | Must match the plugin's UDP port. |
| `stream_name` | `VinylBridge` | 1–16 letters or digits. Must match the plugin's stream name exactly. |
| `sample_rate` | `48000` | `44100` or `48000`. Must match the plugin. |
| `channels` | `2` | `1` or `2`. Must match the plugin. |
| `format` | `16I` | `16I`, `24I`, `32I`, `32F` (S16LE, S24LE, S32LE, F32LE). Must match the plugin. |
| `alsa_device` | `pulse` | ALSA PCM to record from. `pulse` is Home Assistant's selected Audio input. |
| `buffer_size` | `1024` | Frames per packet, ~21 ms at 48 kHz. Lower is lower latency; too low stutters. |
| `log_level` | `3` | 0 fatal, 1 error, 2 warning, 3 info, 4 debug. |
| `gate_mode` | `always` | `always`, `switch` or `power`. See *Only capture when the turntable is in use*. |
| `gate_entity` | empty | Switch or power sensor that opens the gate. Required unless `gate_mode` is `always`. |
| `power_threshold_w` | `1.0` | Power mode: capture starts at or above this many watts. |
| `off_delay_s` | `300` | Seconds the gate must stay closed before capture stops. |
| `stop_player` | empty | Optional `media_player` to stop when capture stops because the gate closed. |

## Latency

Roughly **1–3 seconds** end to end, most of it in the player at the far end
rather than in the bridge. Fine for listening; not for anything that has to
line up with a picture.

If you want to trim it, lower `buffer_size`. 1024 frames is about 21 ms at
48 kHz, and going far below 256 is more likely to stutter than to help.

## What it does not do

**It cannot show what is playing.** Music Assistant's VBAN Receiver fixes the
now-playing text when the stream starts:

```python
stream_metadata=StreamMetadata(title=self._vban_stream_name, artist=self._sender_host)
```

So every Music Assistant player shows the stream name and the sender address
for as long as the stream runs. There is no API to update it afterwards, and
the plugin ignores VBAN's text sub-channel. This is a property of the
receiver, not of this add-on.

If you also run the [Vinyl Listener](https://github.com/Thrasher2020/vinyl_listener)
add-on, its `media_player.vinyl_listener` entity carries the identified artist
and title, so a Home Assistant dashboard can show what is on the turntable even
though the Music Assistant player cannot.

Also not implemented:

- **Needle-drop detection is not built in.** Use the power or switch gate
  below to open capture when the deck is in use.
- **One receiver per port**, one stream name per receiver.
- **Music Assistant playback is not started by this add-on.** Starting capture
  does not start anything playing; that stays a manual choice of player or
  group. Stopping can be automatic (see `stop_player` below).

## Only capture when the turntable is in use

The **gate** options decide when the add-on captures. With the default
`always`, it streams whenever the add-on runs, as before.

- **`switch`**: capture while `gate_entity` is `on`, e.g. `switch.turntable`.
  Works with the switch you already have.
- **`power`**: capture while `gate_entity` reads at or above `power_threshold_w`,
  e.g. a smart plug's power sensor on the deck. A spinning turntable draws about
  1 W, so the default threshold is 1 W. Measure your own deck playing and idle
  first.

Capture stops only after the gate has stayed closed for `off_delay_s` (default
300 s). A short dropout does not interrupt the stream.

Optionally set `stop_player` to a Music Assistant player, for example
`media_player.office_sonos`. When capture stops because the gate closed, that
player is sent a stop. Leave it empty if you prefer to stop playback yourself.

If the gate entity is unavailable or missing, capture stays off and the log says
so.

This idea came from Salapenos on the Home Assistant community forum, who used a
smart plug on the turntable to start and stop the bridge.

## Running alongside other capture add-ons

Several PulseAudio clients can record the same input at once, so this add-on
does not fight with a Shazam-style identifier or anything else that records the
interface. Both read it concurrently; neither seizes it.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `vban_emitter is not installed` in the log | Image problem, not configuration. Reinstall. |
| Log repeats `cannot set sample rate`, `open error`, `set parameters` | Audio input not set, or the interface will not run at the configured rate. |
| Log clean, Music Assistant receives nothing | The six settings above do not match. |
| Music Assistant says it is playing, but silence | The target player or group, not the bridge. Test that player with a normal track. |
| Dropouts or crackle | Raise `buffer_size`. Check nothing else is holding the interface at a different rate. |

`vban_emitter` exits on a hard capture error and `run.sh` restarts it after five
seconds, so a permanently repeating error in the log is your signal — a working
stream logs once and then stays quiet.

## Tested with

- Home Assistant OS 18.3 / Home Assistant 2026.11.1, `amd64`
- Music Assistant add-on 2.10.9
- Behringer UCA222 (TI PCM2902), 48 kHz, 16-bit, stereo
- Alongside Vinyl Listener 1.5.1 recording the same interface

The PCM2902 is 16-bit and tops out at 48 kHz, so `24I` and `32I` in the options
exist for other interfaces, not this one.

## If you don't want an add-on

`vban_emitter` needs no Home Assistant. Build
[quiniouben/vban](https://github.com/quiniouben/vban) yourself, run it against
any ALSA or PulseAudio capture device, and point Music Assistant's VBAN
Receiver at that host. On PipeWire, `libpipewire-module-vban-send` does the same
job with no extra software at all.

## Credits

- [`quiniouben/vban`](https://github.com/quiniouben/vban) — `vban_emitter`,
  GPL-3.0, built from source when the image is built.
- [VBAN](https://vb-audio.com/Voicemeeter/vban.htm) — the protocol, by VB-Audio.
- [Music Assistant](https://www.music-assistant.io) and its VBAN Receiver
  plugin, contributed by sprocket-9.

## Licence

The add-on itself — the `Dockerfile`, `run.sh`, `config.yaml`, translations and
this README — is **MIT** licensed. See [LICENSE](LICENSE); use it, fork it,
ship it.

`vban_emitter` is not part of this repository. It is GPL-3.0 and is compiled
from [quiniouben/vban](https://github.com/quiniouben/vban) on your own machine
when the add-on is installed, so nothing GPL is redistributed here. If you ever
publish a prebuilt image you would be distributing that compiled binary, and
GPL-3.0's terms would then apply to it.

## Issues

Open an issue with your Home Assistant version, your Music Assistant version,
the add-on log, and the exact **Audio input** name shown in the configuration.
Questions about track information are answered above: the receiver cannot show
it.
