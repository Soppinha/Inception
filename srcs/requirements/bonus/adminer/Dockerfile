FROM debian:12

RUN apt-get update && apt-get install --no-install-recommends -y \
        php8.2-fpm php8.2-mysql curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/php /var/www/adminer

ARG ADMINER_VERSION
RUN curl -fsSL -o /var/www/adminer/index.php \
        "https://github.com/vrana/adminer/releases/download/v${ADMINER_VERSION}/adminer-${ADMINER_VERSION}.php" \
    && chown -R www-data:www-data /var/www/adminer

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

ARG ADMINER_PORT
EXPOSE ${ADMINER_PORT}

ENTRYPOINT [ "/usr/local/bin/init.sh" ]
