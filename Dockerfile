# ----------------------------------------------------------------
# Builder: use a generic, slim Debian to keep things minimal
FROM golang:1.25.6 AS builder

ENV DEBIAN_FRONTEND=noninteractive
# Install build dependencies (Go is provided by base image)
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    ca-certificates git build-essential \
    libbrotli-dev liblzo2-dev libsodium-dev curl cmake && \
  rm -rf /var/lib/apt/lists/*

# Fetch project and build
RUN git clone --single-branch https://github.com/wal-g/wal-g /tmp/wal-g && \
  cd /tmp/wal-g && \
  GOEXPERIMENT=jsonv2 USE_BROTLI=1 USE_LIBSODIUM=1 USE_LZO=1 make deps pg_build && \
  cp main/pg/wal-g /usr/local/bin/wal-g && \
  chmod +x /usr/local/bin/wal-g && \
  rm -rf /tmp/wal-g

# Show wal-g version
RUN wal-g --version

FROM debian:stable-slim AS bin

COPY --from=builder /usr/local/bin/wal-g /usr/local/bin/

# Wal-G env utility to choose backups interactively
COPY scripts/wal-g-env /usr/local/bin/wal-g-env

# Entrypoint + Command
COPY scripts/restore.sh /usr/local/bin/restore.sh

# ----------------------------------------------------------------
# Final: PostgreSQL with the wal-g binary copied in
ARG POSTGRES_IMAGE=postgres:16
# ARG POSTGRES_IMAGE=timescale/timescaledb-ha:pg16-all
FROM $POSTGRES_IMAGE

# Use standard data directory (base timescaledb image is non-standard)
ENV PGDATA=/var/lib/postgresql/data
WORKDIR /var/lib/postgresql

# Install wal-g binary
COPY --from=bin /usr/local/bin/* /usr/local/bin/
#COPY --from=bin /usr/local/bin/wal-g /usr/local/bin/
#COPY --from=bin /usr/local/bin/wal-g-env /usr/local/bin/
#COPY --from=bin /usr/local/bin/restore.sh /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/restore.sh"]
CMD ["postgres"]
