#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"
RESTART_DELAY=5

log() {
    printf '%s [vban_bridge] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

if [[ ! -r "$OPTIONS_FILE" ]]; then
    log "FATAL: ${OPTIONS_FILE} is not readable"
    exit 1
fi

MA_HOST="$(jq -r '.ma_host // "127.0.0.1"' "$OPTIONS_FILE")"
MA_PORT="$(jq -r '.ma_port // 6980' "$OPTIONS_FILE")"
STREAM_NAME="$(jq -r '.stream_name // "VinylBridge"' "$OPTIONS_FILE")"
SAMPLE_RATE="$(jq -r '.sample_rate // 48000' "$OPTIONS_FILE")"
CHANNELS="$(jq -r '.channels // 2' "$OPTIONS_FILE")"
FORMAT="$(jq -r '.format // "16I"' "$OPTIONS_FILE")"
ALSA_DEVICE="$(jq -r '.alsa_device // "pulse"' "$OPTIONS_FILE")"
BUFFER_SIZE="$(jq -r '.buffer_size // 1024' "$OPTIONS_FILE")"
LOG_LEVEL="$(jq -r '.log_level // 3' "$OPTIONS_FILE")"

if ! command -v vban_emitter >/dev/null 2>&1; then
    log "FATAL: vban_emitter is not installed"
    exit 1
fi

log "sending stream '${STREAM_NAME}' to ${MA_HOST}:${MA_PORT} (${SAMPLE_RATE} Hz, ${CHANNELS} ch, ${FORMAT}) from ALSA device '${ALSA_DEVICE}'"

child=""
cleanup() {
    log "shutting down"
    if [[ -n "$child" ]] && kill -0 "$child" 2>/dev/null; then
        kill "$child" 2>/dev/null || true
        wait "$child" 2>/dev/null || true
    fi
    exit 0
}
trap cleanup TERM INT

while true; do
    # Options are passed as --name=value on purpose: --bufsize takes an
    # optional argument, which getopt only accepts in the "=value" form.
    vban_emitter \
        --ipaddress="$MA_HOST" \
        --port="$MA_PORT" \
        --streamname="$STREAM_NAME" \
        --backend="alsa" \
        --device="$ALSA_DEVICE" \
        --rate="$SAMPLE_RATE" \
        --nbchannels="$CHANNELS" \
        --format="$FORMAT" \
        --bufsize="$BUFFER_SIZE" \
        --loglevel="$LOG_LEVEL" &
    child=$!

    status=0
    wait "$child" || status=$?

    log "vban_emitter exited with status ${status}; restarting in ${RESTART_DELAY} s"
    sleep "$RESTART_DELAY" || true
done
