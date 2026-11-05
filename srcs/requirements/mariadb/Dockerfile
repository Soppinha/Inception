FROM debian:12

RUN apt-get update && apt-get install --no-install-recommends -y mariadb-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/mysqld \
    && chown -R mysql:mysql /run/mysqld

COPY conf/99-server-override.cnf /etc/mysql/mariadb.conf.d/99-server-override.cnf

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

ARG DB_PORT
EXPOSE ${DB_PORT}

ENTRYPOINT [ "/usr/local/bin/init.sh" ]
