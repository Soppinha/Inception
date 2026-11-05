#!/bin/bash

set -e

: "${ADMINER_PORT:?}"

echo "[adminer] Iniciando php-fpm na porta ${ADMINER_PORT}..."
exec php-fpm8.2 -F
