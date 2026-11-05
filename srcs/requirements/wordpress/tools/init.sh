#!/bin/bash

set -e

: "${DOMAIN_NAME:?}"
: "${DB_NAME:?}" "${DB_USER:?}" "${DB_HOST:?}"
: "${DB_PORT:?}"
: "${WP_TITLE:?}" "${WP_ADMIN_USER:?}" "${WP_ADMIN_EMAIL:?}"
: "${WP_USER:?}" "${WP_USER_EMAIL:?}" "${WP_USER_ROLE:?}"
: "${WP_PORT:?}" "${WP_VERSION:?}"
: "${REDIS_HOST:?}" "${REDIS_PORT:?}" "${REDIS_CACHE_VERSION:?}"

DB_PASS="$(cat /run/secrets/db_password)"

get_cred() { grep "^$1=" /run/secrets/credentials | cut -d= -f2-; }
WP_ADMIN_PASS="$(get_cred WP_ADMIN_PASSWORD)"
WP_USER_PASS="$(get_cred WP_USER_PASSWORD)"
[ -n "$WP_ADMIN_PASS" ] && [ -n "$WP_USER_PASS" ] \
    || { echo "[wordpress] faltam senhas em credentials"; exit 1; }

if echo "$WP_ADMIN_USER" | grep -qi admin; then
    echo "[wordpress] WP_ADMIN_USER nao pode conter 'admin'"; exit 1
fi

WP="wp --allow-root --path=/var/www/html"

for i in $(seq 1 30); do
    mariadb -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
        -e "SELECT 1" "$DB_NAME" > /dev/null 2>&1 && break
    echo "[wordpress] esperando o MariaDB ($i/30)..."
    sleep 1
done
mariadb -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" "$DB_NAME" > /dev/null \
    || { echo "[wordpress] MariaDB inacessivel"; exit 1; }

if [ ! -f /var/www/html/wp-config.php ]; then
    echo "[wordpress] Primeira execucao: instalando o WordPress..."

    $WP core download --version="$WP_VERSION"

    $WP config create \
        --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" \
        --dbhost="$DB_HOST:$DB_PORT" --skip-check

    $WP core install \
        --url="https://$DOMAIN_NAME" --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS" \
        --admin_email="$WP_ADMIN_EMAIL" --skip-email

    $WP user create "$WP_USER" "$WP_USER_EMAIL" \
        --role="$WP_USER_ROLE" --user_pass="$WP_USER_PASS"

    echo "[wordpress] Instalacao concluida."
fi

$WP config set WP_REDIS_HOST "$REDIS_HOST"
$WP config set WP_REDIS_PORT "$REDIS_PORT" --raw
if ! $WP plugin is-installed redis-cache; then
    echo "[wordpress] Instalando o plugin Redis Object Cache..."
    $WP plugin install redis-cache --version="$REDIS_CACHE_VERSION"
fi
$WP plugin is-active redis-cache || $WP plugin activate redis-cache
[ -f /var/www/html/wp-content/object-cache.php ] || $WP redis enable

chown -R www-data:www-data /var/www/html

echo "[wordpress] Iniciando php-fpm na porta ${WP_PORT}..."
exec php-fpm8.2 -F
