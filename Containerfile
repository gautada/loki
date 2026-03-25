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
 && git clone --branch "v${LOKI_VERSION}" --depth 1 https://github.com/grafana/loki.git .

# Build Loki and Promtail
# RUN go build -ldflags "-s -w" ./cmd/loki
# RUN go build -ldflags "-s -w" ./cmd/promtail

RUN VERSION="${LOKI_VERSION#v}" && \
    BRANCH="$(git rev-parse --abbrev-ref HEAD)" && \
    REVISION="$(git rev-parse HEAD)" && \
    BUILD_USER="root@$(hostname)" && \
    BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" && \
    LDFLAGS="-s -w \
      -X github.com/grafana/loki/pkg/build.Version=${VERSION} \
      -X github.com/grafana/loki/pkg/build.Branch=${BRANCH} \
      -X github.com/grafana/loki/pkg/build.Revision=${REVISION} \
      -X github.com/grafana/loki/pkg/build.BuildUser=${BUILD_USER} \
      -X github.com/grafana/loki/pkg/build.BuildDate=${BUILD_DATE}" && \
    go build -ldflags "${LDFLAGS}" -o /out/loki ./cmd/loki && \
    CGO_ENABLED=0 go build -ldflags "${LDFLAGS}" -o /out/promtail ./clients/cmd/promtail



# Build Loki
# RUN go build -ldflags="-s -w" -o /out/loki ./cmd/loki
# Build Promtail without journald support
# RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/promtail ./clients/cmd/promtail

ENTRYPOINT [ "tail", "-f", "/dev/null" ]

# # ----------------------------------------------------------- [STAGE] FINAL
# FROM gautada/debian:$DEBIAN_TAG
#
# # Standard Loki ports: 3100 (HTTP), 9095 (gRPC)
# EXPOSE 3100 9095
#
# RUN apt-get update && apt-get install -y --no-install-recommends \
#     ca-certificates \
#     libcap2-bin \
#     && rm -rf /var/lib/apt/lists/*
#
# COPY --from=builder /src/loki /usr/bin/loki
# COPY --from=builder /src/promtail /usr/bin/promtail
#
# # Standard Loki config location
# RUN mkdir -p /etc/loki /var/loki
#
# # Set up non-root user (matching gautada/debian conventions if any, otherwise standard)
# ARG USER=loki
# RUN groupadd -r $USER && useradd -r -g $USER $USER \
#     && chown -R $USER:$USER /etc/loki /var/loki
#
# USER $USER
# WORKDIR /var/loki
#
# ENTRYPOINT ["/usr/bin/loki"]
# CMD ["-config.file=/etc/loki/local-config.yaml"]
