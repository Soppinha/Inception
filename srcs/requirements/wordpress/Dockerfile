FROM debian:12

RUN apt-get update && apt-get install --no-install-recommends -y \
        php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring \
        php8.2-xml php8.2-zip php8.2-intl \
        mariadb-client curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/php

ARG WP_CLI_VERSION
RUN curl -fsSL -o /usr/local/bin/wp \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar" \
    && chmod +x /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

WORKDIR /var/www/html

ARG WP_PORT
EXPOSE ${WP_PORT}

ENTRYPOINT [ "/usr/local/bin/init.sh" ]
