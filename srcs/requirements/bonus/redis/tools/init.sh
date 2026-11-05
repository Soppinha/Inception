#!/bin/bash

set -e

: "${REDIS_PORT:?}"
: "${REDIS_MAXMEMORY:?}"

echo "[redis] Iniciando Redis na porta ${REDIS_PORT} (maxmemory ${REDIS_MAXMEMORY})..."
exec redis-server /etc/redis/redis.conf \
    --port "$REDIS_PORT" \
    --maxmemory "$REDIS_MAXMEMORY"
