# Changelog

## 0.2.0

- New **gate** options so capture only runs when the source is in use:
  - `gate_mode`: `always` (default, unchanged behaviour), `switch` or `power`.
  - `gate_entity`: the switch or power sensor that opens the gate.
  - `power_threshold_w` (default 1.0 W) and `off_delay_s` (default 300 s).
  - `stop_player` (optional): a Music Assistant player to stop when capture
    stops because the gate closed.
- Gate polling uses the Home Assistant API, so the add-on now requests
  `homeassistant_api: true`. It uses the Supervisor token only.
- Dockerfile runtime now includes `curl`.
- Thanks to Salapenos for the smart-plug idea on the community forum.

## 0.1.1

- Drop `build.yaml`. Supervisor validates its `build_from` entries against a
  regex that requires a `namespace/name` form, so `debian:bookworm-slim` was
  rejected and the build fell back to `ghcr.io/home-assistant/base:latest`
  (Alpine, no `apt-get`). The base image now comes from the Dockerfile's
  `ARG BUILD_FROM` default, which is also the non-deprecated route.

## 0.1.0

- Initial release. Streams Home Assistant's PulseAudio input to Music Assistant
  over VBAN, using `vban_emitter` from quiniouben/vban (pinned to v2.2.0) with
  the ALSA backend and the `pulse` PCM.
