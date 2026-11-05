#!/bin/bash

set -e

: "${WEBSITE_PORT:?}"

lighttpd -tt -f /etc/lighttpd/lighttpd.conf

echo "[website] Iniciando lighttpd na porta ${WEBSITE_PORT}..."
exec lighttpd -D -f /etc/lighttpd/lighttpd.conf
