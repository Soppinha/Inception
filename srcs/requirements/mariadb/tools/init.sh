#!/bin/bash

set -e

: "${DB_NAME:?}"
: "${DB_USER:?}"
: "${DB_PORT:?}"

DB_PASS="$(cat /run/secrets/db_password)"
DB_ROOT_PASS="$(cat /run/secrets/db_root_password)"

DATADIR=/var/lib/mysql

chown -R mysql:mysql "$DATADIR"

if [ ! -d "$DATADIR/mysql" ]; then
    echo "[mariadb] Volume vazio: criando tabelas do sistema..."
    mariadb-install-db --user=mysql --datadir="$DATADIR" > /dev/null
fi

if [ ! -d "$DATADIR/$DB_NAME" ]; then
    echo "[mariadb] Primeira execucao: criando database '$DB_NAME'..."

    mysqld --user=mysql --datadir="$DATADIR" --skip-networking &
    TMP_PID=$!

    for i in $(seq 1 30); do
        mysqladmin --silent ping 2>/dev/null && break
        sleep 1
    done
    mysqladmin --silent ping || { echo "[mariadb] servidor temporario nao subiu"; exit 1; }

    mariadb -u root <<EOF
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
FLUSH PRIVILEGES;
EOF

    mysqladmin -u root -p"${DB_ROOT_PASS}" shutdown
    wait "$TMP_PID"
    echo "[mariadb] Configuracao inicial concluida."
fi

echo "[mariadb] Iniciando MariaDB na porta ${DB_PORT}..."
exec mysqld --user=mysql --datadir="$DATADIR" --port="${DB_PORT}"
