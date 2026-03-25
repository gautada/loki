# ------------------------------------------------------------- [STAGE] BUILD
ARG DEBIAN_TAG=latest
FROM gautada/debian:$DEBIAN_TAG as builder

ARG LOKI_VERSION=v2.9.4
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    golang \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --branch $LOKI_VERSION --depth 1 https://github.com/grafana/loki.git .

# Build Loki and Promtail
RUN go build -ldflags "-s -w" ./cmd/loki
RUN go build -ldflags "-s -w" ./cmd/promtail

# ----------------------------------------------------------- [STAGE] FINAL
FROM gautada/debian:$DEBIAN_TAG

# Standard Loki ports: 3100 (HTTP), 9095 (gRPC)
EXPOSE 3100 9095

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/loki /usr/bin/loki
COPY --from=builder /src/promtail /usr/bin/promtail

# Standard Loki config location
RUN mkdir -p /etc/loki /var/loki

# Set up non-root user (matching gautada/debian conventions if any, otherwise standard)
ARG USER=loki
RUN groupadd -r $USER && useradd -r -g $USER $USER \
    && chown -R $USER:$USER /etc/loki /var/loki

USER $USER
WORKDIR /var/loki

ENTRYPOINT ["/usr/bin/loki"]
CMD ["-config.file=/etc/loki/local-config.yaml"]
