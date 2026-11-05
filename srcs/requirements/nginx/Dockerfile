FROM debian:12

RUN apt-get update && apt-get install --no-install-recommends -y \
        nginx openssl gettext-base \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default \
    && mkdir -p /etc/nginx/ssl

COPY conf/inception.conf.template /etc/nginx/templates/inception.conf.template

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

ARG NGINX_PORT
EXPOSE ${NGINX_PORT}

ENTRYPOINT [ "/usr/local/bin/init.sh" ]
