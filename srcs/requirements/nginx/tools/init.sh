#!/bin/bash

set -e

: "${DOMAIN_NAME:?}"
: "${NGINX_PORT:?}"
: "${WP_HOST:?}"
: "${WP_PORT:?}"
: "${CERT_DAYS:?}"
: "${CERT_SUBJECT:?}"

CRT=/etc/nginx/ssl/inception.crt
KEY=/etc/nginx/ssl/inception.key

if [ ! -f "$CRT" ] || [ ! -f "$KEY" ]; then
    echo "[nginx] Gerando certificado para ${DOMAIN_NAME}..."
    openssl req -x509 -nodes -newkey rsa:2048 \
        -days "$CERT_DAYS" \
        -keyout "$KEY" -out "$CRT" \
        -subj "${CERT_SUBJECT}/CN=${DOMAIN_NAME}" \
        -addext "subjectAltName=DNS:${DOMAIN_NAME}" 2>/dev/null
    chmod 600 "$KEY"
fi

envsubst '${DOMAIN_NAME} ${NGINX_PORT} ${WP_HOST} ${WP_PORT}' \
    < /etc/nginx/templates/inception.conf.template \
    > /etc/nginx/conf.d/inception.conf

nginx -t

echo "[nginx] Iniciando nginx na porta ${NGINX_PORT} (TLSv1.2/TLSv1.3)..."
exec nginx -g "daemon off;"
