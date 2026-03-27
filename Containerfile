# ------------------------------------------------------------- [STAGE] BUILD
ARG DEBIAN_TAG=latest
FROM docker.io/library/golang:1.24-trixie AS builder

ARG LOKI_VERSION=2.9.4
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    golang \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git config --global advice.detachedHead false \
 && git clone --branch "v${LOKI_VERSION}" --depth 1 https://github.com/grafana/loki.git . \
 && VERSION="${LOKI_VERSION#v}" && \
    BRANCH="$(git rev-parse --abbrev-ref HEAD)" && \
    REVISION="$(git rev-parse HEAD)" && \
    BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
    LDFLAGS="-s -w \
      -X github.com/grafana/loki/pkg/util/build.Version=${VERSION} \
      -X github.com/grafana/loki/pkg/util/build.Branch=${BRANCH} \
      -X github.com/grafana/loki/pkg/util/build.Revision=${REVISION} \
      -X github.com/grafana/loki/pkg/util/build.BuildUser=gautada \
      -X github.com/grafana/loki/pkg/util/build.BuildDate=${BUILD_DATE}" && \
    echo "${LDFLAGS}" && echo "------------------------------------------" && \
    go build -ldflags "${LDFLAGS}" -o /out/loki ./cmd/loki && \
    CGO_ENABLED=0 go build -ldflags "${LDFLAGS}" -o /out/promtail ./clients/cmd/promtail
# ENTRYPOINT [ "tail", "-f", "/dev/null" ]

# # ----------------------------------------------------------- [STAGE] FINAL
FROM gautada/debian:$DEBIAN_TAG as container

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL org.opencontainers.image.title="loki"
LABEL org.opencontainers.image.description="A Grafana Loki database."
LABEL org.opencontainers.image.source="https://github.com/gautada/loki"
LABEL org.opencontainers.image.license="Apache-2.0"


# Standard Loki ports: 3100 (HTTP), 9095 (gRPC)
EXPOSE 3100 9095

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/loki /usr/bin/loki
COPY --from=builder /out/promtail /usr/bin/promtail

# ╭──────────────────────────────────────────────────────────╮
# │ User                                                     │
# ╰──────────────────────────────────────────────────────────╯
ARG USER=loki
RUN /usr/sbin/usermod -l $USER debian \
 && /usr/sbin/usermod -d /home/$USER -m $USER \
 && /usr/sbin/groupmod -n $USER debian \
 && /bin/passwd -d $USER \
 && rm -rf /home/debian 

# ╭――――――――――――――――――――╮
# │ CONFIGURATION      │
# ╰――――――――――――――――――――╯
COPY config.yaml /etc/loki/loki.yaml
RUN chown $USER:$USER /etc/loki/loki.yaml

# ╭――――――――――――――――――――╮
# │ VERSION            │
# ╰――――――――――――――――――――╯
COPY version.sh /usr/bin/container-version
RUN chmod +x /usr/bin/container-version

# ╭――――――――――――――――――――╮
# │ ENTRYPOINT         │
# ╰――――――――――――――――――――╯
COPY loki.s6 /etc/services.d/loki/run
RUN chmod +x /etc/services.d/loki/run

# Standard Loki config location 
# RUN mkdir -p /var/loki \
# WORKDIR /var/loki
WORKDIR /loki
# RUN chown $USER:$USER -R /var/loki
RUN chown $USER:$USER -R /loki

#
# ENTRYPOINT ["/usr/bin/loki"]
# CMD ["-config.file=/etc/loki/local-config.yaml"]
