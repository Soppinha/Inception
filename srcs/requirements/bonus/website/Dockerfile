FROM debian:12

RUN apt-get update && apt-get install --no-install-recommends -y lighttpd \
    && rm -rf /var/lib/apt/lists/*

COPY conf/lighttpd.conf /etc/lighttpd/lighttpd.conf

COPY site/ /var/www/website/

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

ARG WEBSITE_PORT
EXPOSE ${WEBSITE_PORT}

ENTRYPOINT [ "/usr/local/bin/init.sh" ]
