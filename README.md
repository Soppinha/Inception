*This project has been created as part of the 42 curriculum by svaladar.*

# Inception

## Description

Inception is a system administration project: it sets up a small web infrastructure made of several Docker containers, all built from scratch on a virtual machine and orchestrated with Docker Compose.

The stack serves a WordPress website over HTTPS. Every service runs in its own container, built from its own Dockerfile on top of `debian:12` (Bookworm, the penultimate stable Debian release). No ready-made images are pulled from Docker Hub other than the Debian base image.

### Services

| Container   | Role | Reached through |
|-------------|------|-----------------|
| `nginx`     | The only entrypoint. Terminates TLS (v1.2 and v1.3 only) on port 443 | `https://<login>.42.fr` |
| `wordpress` | WordPress + php-fpm (no web server inside) | NGINX, FastCGI on port 9000 |
| `mariadb`   | Database for WordPress | internal network only, port 3306 |
| `redis` *(bonus)*   | Object cache for WordPress | internal network only, port 6379 |
| `adminer` *(bonus)* | Web UI to manage the database | `https://<login>.42.fr/adminer/` |
| `website` *(bonus)* | Static showcase page (HTML + CSS, no PHP) | `https://<login>.42.fr/site/` |

```
                 Host (VM)  :443
                     │
               ┌─────▼─────┐
               │   nginx   │  TLS 1.2 / 1.3
               └─┬───┬───┬─┘
       FastCGI   │   │   │  HTTP
   ┌─────────────┘   │   └──────────────┐
┌──▼────────┐  ┌─────▼─────┐      ┌─────▼─────┐
│ wordpress │  │  adminer  │      │  website  │
└──┬─────┬──┘  └─────┬─────┘      └───────────┘
   │     │           │
┌──▼──┐ ┌▼───────────▼┐
│redis│ │   mariadb   │
└─────┘ └─────────────┘
        network: inception (bridge)
```

### Sources included in the project

```
.
├── Makefile                  builds and runs everything through docker compose
├── secrets/                  passwords (git-ignored), mounted as Docker secrets
└── srcs/
    ├── .env                  every non-secret setting (git-ignored)
    ├── .env.example          template for .env, without personal values
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/          Dockerfile, conf/99-server-override.cnf, tools/init.sh
        ├── wordpress/        Dockerfile, conf/www.conf (php-fpm pool), tools/init.sh
        ├── nginx/            Dockerfile, conf/inception.conf.template, tools/init.sh
        └── bonus/
            ├── redis/        Dockerfile, conf/redis.conf, tools/init.sh
            ├── adminer/      Dockerfile, conf/www.conf, tools/init.sh
            └── website/      Dockerfile, conf/lighttpd.conf, site/ (index.html, style.css), tools/init.sh
```

Each `tools/init.sh` is the container's entrypoint. It validates its environment, performs first-run setup when the volume is empty, and then replaces itself with the service process via `exec`. The service therefore runs as PID 1 in the foreground and receives the `SIGTERM` sent by `docker stop`.

### Main design choices

- **Debian 12 as the base for every image.** Its packages (`mariadb-server`, `php8.2-fpm`, `nginx`, `redis-server`) are stable and well documented.
- **All configuration lives in `srcs/.env`:** ports, host names, user names, tool versions, certificate data. Nothing is hard-coded in the Dockerfiles or scripts. Build-time values reach the Dockerfiles through `ARG` and compose `build.args`; runtime values reach the scripts through `env_file`. Static config files that cannot read variables are filled in at startup (`envsubst` for NGINX) or overridden with command-line flags (`mysqld --port`).
- **Passwords never appear in environment variables.** They are Docker secrets, read from `/run/secrets/*` by the entrypoint scripts.
- **Idempotent first run.** MariaDB initializes only if the database directory is missing. WordPress installs only if `wp-config.php` is missing. Restarting or recreating the containers never resets the data.
- **No infinite loops.** The only waiting loops (WordPress waiting for MariaDB, MariaDB's temporary bootstrap server) are bounded to 30 attempts and exit with an error on timeout.
- **NGINX is the single public entrypoint.** Bonus web services are routed through it (`/adminer/` via FastCGI, `/site/` via reverse proxy), so they are also served over TLS and no extra ports are opened.
- **Containers restart on crash** (`restart: unless-stopped`).

### Virtual Machines vs Docker

A **virtual machine** emulates a whole computer: it boots its own kernel on virtualized hardware provided by a hypervisor. This gives strong isolation, but every VM pays for a full operating system in RAM, disk and boot time.

A **Docker container** is an isolated process running on the host's kernel. Linux namespaces give it its own view of processes, network and filesystem, and cgroups limit its resources. Containers start in milliseconds and images are small and layered, but isolation is weaker because the kernel is shared.

In this project the two are combined: the VM provides an isolated, disposable machine, and Docker splits the services inside it into lightweight, independently rebuildable units.

### Secrets vs Environment Variables

**Environment variables** (here, from `.env`) are convenient for configuration, but they are visible to anyone who can run `docker inspect`, they appear in `/proc/<pid>/environ`, and child processes inherit them. That is fine for ports or user names, but not for passwords.

**Docker secrets** are files mounted read-only at `/run/secrets/<name>`, only in the containers that declare them. They are not part of the container's environment or the image layers. In this project:

- `db_password` and `db_root_password` are used by MariaDB (and `db_password` by WordPress);
- `credentials` holds the WordPress users' passwords.

Both `.env` and `secrets/` are git-ignored.

### Docker Network vs Host Network

With **`network_mode: host`**, a container shares the host's network stack: every port it opens is open on the host, and there is no isolation between services. This is forbidden by the subject.

A user-defined **bridge network** (`inception`) gives the containers a private network with its own built-in DNS: WordPress reaches the database simply as `mariadb:3306`. Nothing on that network is reachable from outside unless it is explicitly published. Here only NGINX publishes a port (`443`), so MariaDB, Redis, php-fpm and the other internal services are not exposed.

### Docker Volumes vs Bind Mounts

A **bind mount** maps an arbitrary host path straight into a container. It depends on the host's directory layout and permissions, and Docker does not manage it.

A **named volume** is an object managed by Docker (`docker volume ls`, `docker volume inspect`), referenced by name and independent of the container's lifecycle.

This project uses two named volumes, `mariadb` and `wordpress`. The subject requires their data to live in `/home/<login>/data`, so they use the `local` driver with `driver_opts` (`type: none`, `o: bind`, `device: /home/${LOGIN}/data/...`). They remain named volumes, created and managed by Docker; the options only choose where the local driver stores the data.

## Instructions

### Prerequisites

- A Linux virtual machine (Debian or Ubuntu)
- Docker Engine with the Compose plugin (`docker compose`)
- `make`

### Setup

1. Point the domain to the local machine:
   ```sh
   echo "127.0.0.1 <login>.42.fr" | sudo tee -a /etc/hosts
   ```
2. Create the configuration from the template, then fill in the `<...>` placeholders. `LOGIN` drives the domain, the data path and the certificate:
   ```sh
   cp srcs/.env.example srcs/.env
   ```
3. Create the password files in `secrets/` (commands in [DEV_DOC.md](DEV_DOC.md)).

### Run

```sh
make          # build the images and start the stack
make ps       # show container status
make logs     # follow the logs
make down     # stop and remove the containers (data is kept)
make fclean   # remove containers, images, volumes and /home/<login>/data
make re       # fclean + make
```

Then open `https://<login>.42.fr`. The certificate is self-signed, so the browser shows a warning that must be accepted.

See [USER_DOC.md](USER_DOC.md) for day-to-day usage and [DEV_DOC.md](DEV_DOC.md) for development details.

## Resources

### Documentation

- [Docker — Dockerfile reference](https://docs.docker.com/reference/dockerfile/) and [Building best practices](https://docs.docker.com/build/building/best-practices/)
- [Docker Compose — Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Docker — Secrets in Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker — Volumes](https://docs.docker.com/engine/storage/volumes/) and [Bridge networks](https://docs.docker.com/engine/network/drivers/bridge/)
- [NGINX — ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html) and [ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [MariaDB — Configuring with option files](https://mariadb.com/kb/en/configuring-mariadb-with-option-files/) and [mariadb-install-db](https://mariadb.com/kb/en/mariadb-install-db/)
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [Redis configuration](https://redis.io/docs/latest/operate/oss_and_stack/management/config/) and the [Redis Object Cache plugin](https://wordpress.org/plugins/redis-cache/)
- [Adminer](https://www.adminer.org/)

### Articles

- [Docker and the PID 1 zombie reaping problem](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/) (Phusion)
- [Shell form vs exec form](https://docs.docker.com/reference/dockerfile/#shell-and-exec-form) (Docker docs)

### Use of AI

An AI assistant (Claude, by Anthropic) was used throughout the project:

- **Documentation:** Generating this **README, USER_DOC** and **DEV_DOC** based on the project source code and 42 specification requirements.

All generated content was reviewed, tested on the VM and adjusted before being kept. Naming, structure and the choice of what goes in `.env` were decided during that review.
