ARG BUILD_FROM=debian:bookworm-slim

# ---------------------------------------------------------------------------
# Build stage: compile vban_emitter from quiniouben/vban.
# Only the ALSA backend is needed: it opens the "pulse" PCM that Home Assistant
# maps into the add-on when `audio: true` is set.
# ---------------------------------------------------------------------------
FROM ${BUILD_FROM} AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ca-certificates \
        curl \
        libasound2-dev \
    && rm -rf /var/lib/apt/lists/*

# v2.2.0, pinned by commit so the image always builds the same source.
ARG VBAN_SHA=9c3d558bbdb9d971cdddf95dff1abdcb95e94466

RUN set -eux; \
    curl -fsSL "https://github.com/quiniouben/vban/archive/${VBAN_SHA}.tar.gz" -o /tmp/vban.tar.gz; \
    mkdir -p /src; \
    tar -xzf /tmp/vban.tar.gz -C /src --strip-components=1; \
    cmake -S /src -B /src/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DWITH_PULSEAUDIO=OFF \
        -DWITH_JACK=OFF; \
    cmake --build /src/build --parallel "$(nproc)"; \
    cmake --install /src/build

# ---------------------------------------------------------------------------
# Runtime stage
# ---------------------------------------------------------------------------
FROM ${BUILD_FROM}

ENV DEBIAN_FRONTEND=noninteractive

# libasound2-plugins supplies the "pulse" ALSA PCM that routes capture to
# Home Assistant's PulseAudio socket.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        jq \
        libasound2 \
        libasound2-plugins \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/vban_emitter /usr/local/bin/vban_emitter

COPY rootfs /

RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
