FROM debian:12

RUN apt-get update && apt-get install --no-install-recommends -y redis-server \
    && rm -rf /var/lib/apt/lists/*

COPY conf/redis.conf /etc/redis/redis.conf

COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

USER redis

ARG REDIS_PORT
EXPOSE ${REDIS_PORT}

ENTRYPOINT [ "/usr/local/bin/init.sh" ]
