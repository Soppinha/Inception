#!/bin/bash

set -e

: "${WEBSITE_PORT:?}"

echo "[website] Iniciando httpd na porta ${WEBSITE_PORT}..."
exec busybox httpd -f -v -u www-data -p "$WEBSITE_PORT" -h /var/www/website
