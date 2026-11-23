#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="${OPTIONS_FILE:-/data/options.json}"
HA_API="${HA_API:-http://supervisor/core/api}"
RESTART_DELAY=5
POLL_SECONDS=3

log() {
    printf '%s [vban_bridge] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

if [[ ! -r "$OPTIONS_FILE" ]]; then
    log "FATAL: ${OPTIONS_FILE} is not readable"
    exit 1
fi

if ! command -v vban_emitter >/dev/null 2>&1; then
    log "FATAL: vban_emitter is not installed"
    exit 1
fi

opt() {
    jq -r --arg key "$1" --arg default "$2" '.[$key] // $default' "$OPTIONS_FILE"
}

MA_HOST="$(opt ma_host 127.0.0.1)"
MA_PORT="$(opt ma_port 6980)"
STREAM_NAME="$(opt stream_name VinylBridge)"
SAMPLE_RATE="$(opt sample_rate 48000)"
CHANNELS="$(opt channels 2)"
FORMAT="$(opt format 16I)"
ALSA_DEVICE="$(opt alsa_device pulse)"
BUFFER_SIZE="$(opt buffer_size 1024)"
LOG_LEVEL="$(opt log_level 3)"
GATE_MODE="$(opt gate_mode always)"
GATE_ENTITY="$(opt gate_entity "")"
POWER_THRESHOLD="$(opt power_threshold_w 1.0)"
OFF_DELAY="$(opt off_delay_s 300)"
STOP_PLAYER="$(opt stop_player "")"

if [[ "$GATE_MODE" != "always" ]]; then
    if [[ -z "${SUPERVISOR_TOKEN:-}" ]]; then
        log "FATAL: gate_mode is '${GATE_MODE}' but Home Assistant API access is unavailable"
        exit 1
    fi
    if [[ -z "$GATE_ENTITY" ]]; then
        log "FATAL: gate_mode is '${GATE_MODE}' but gate_entity is empty"
        exit 1
    fi
fi

ha_get_state() {
    curl -fsS -m 5 -H "Authorization: Bearer ${SUPERVISOR_TOKEN:-}" \
        "$HA_API/states/$1" 2>/dev/null | jq -r '.state // empty' 2>/dev/null || true
}

ha_call_media_stop() {
    local body
    body="$(jq -cn --arg entity "$1" '{entity_id: $entity}')"
    curl -fsS -m 10 -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN:-}" \
        -H "Content-Type: application/json" \
        -d "$body" "$HA_API/services/media_player/media_stop" >/dev/null 2>&1 || true
}

gate_open() {
    local state
    case "$GATE_MODE" in
        always)
            return 0
            ;;
        switch)
            state="$(ha_get_state "$GATE_ENTITY")"
            [[ "$state" == "on" ]]
            ;;
        power)
            state="$(ha_get_state "$GATE_ENTITY")"
            if [[ ! "$state" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
                return 1
            fi
            awk -v v="$state" -v t="$POWER_THRESHOLD" 'BEGIN { exit !(v + 0 >= t + 0) }'
            ;;
    esac
}

EMITTER_PID=""

emitter_running() {
    [[ -n "$EMITTER_PID" ]] && kill -0 "$EMITTER_PID" 2>/dev/null
}

start_emitter() {
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
    EMITTER_PID=$!
    log "capture started, sending stream '${STREAM_NAME}' to ${MA_HOST}:${MA_PORT}"
}

reap_emitter() {
    local status=0
    wait "$EMITTER_PID" || status=$?
    EMITTER_PID=""
    log "vban_emitter exited with status ${status}"
}

stop_emitter() {
    if emitter_running; then
        kill "$EMITTER_PID" 2>/dev/null || true
    fi
    if [[ -n "$EMITTER_PID" ]]; then
        wait "$EMITTER_PID" 2>/dev/null || true
    fi
    EMITTER_PID=""
}

cleanup() {
    log "shutting down"
    stop_emitter
    exit 0
}
trap cleanup TERM INT

log "mode '${GATE_MODE}': sending stream '${STREAM_NAME}' to ${MA_HOST}:${MA_PORT} (${SAMPLE_RATE} Hz, ${CHANNELS} ch, ${FORMAT}) from ALSA device '${ALSA_DEVICE}'"

LAST_GATE=""
closed_since=0
next_start=0

while true; do
    now="$(date +%s)"

    if [[ -n "$EMITTER_PID" ]] && ! emitter_running; then
        reap_emitter
        next_start=$(( now + RESTART_DELAY ))
    fi

    if gate_open; then
        if [[ "$LAST_GATE" != "open" ]]; then
            LAST_GATE="open"
            log "gate open"
        fi
        closed_since=0
        if ! emitter_running && (( now >= next_start )); then
            start_emitter
        fi
    else
        if [[ "$LAST_GATE" != "closed" ]]; then
            LAST_GATE="closed"
            log "gate closed (entity state: '$(ha_get_state "$GATE_ENTITY")')"
        fi
        if emitter_running; then
            if (( closed_since == 0 )); then
                closed_since=$now
            fi
            if (( now - closed_since >= OFF_DELAY )); then
                stop_emitter
                log "capture stopped after ${OFF_DELAY} s with the gate closed"
                if [[ -n "$STOP_PLAYER" ]]; then
                    ha_call_media_stop "$STOP_PLAYER"
                    log "stop requested for ${STOP_PLAYER}"
                fi
                closed_since=0
            fi
        fi
    fi

    sleep "$POLL_SECONDS"
done
