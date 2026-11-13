# Changelog

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
