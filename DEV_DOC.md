# Developer documentation

This guide explains how to set up the project from a fresh clone, how it is built, and where its data lives.

## 1. Set up the environment from scratch

### Prerequisites

| Tool | Check | Install (Debian / Ubuntu) |
|------|-------|---------------------------|
| Docker Engine | `docker --version` | `sudo apt install docker.io` or [docs.docker.com](https://docs.docker.com/engine/install/) |
| Compose plugin | `docker compose version` | `sudo apt install docker-compose-v2` (or `docker-compose-plugin` from Docker's repository) |
| make | `make --version` | `sudo apt install make` |

Allow your user to run Docker without `sudo`, then log out and back in:

```sh
sudo usermod -aG docker $USER
sudo systemctl enable --now docker
```

Point the domain to the machine:

```sh
echo "127.0.0.1 <login>.42.fr" | sudo tee -a /etc/hosts
```

### Configuration files

Two things are deliberately **not** in Git and must be created after cloning: `srcs/.env` and the `secrets/` directory.

#### `srcs/.env`: every non-secret setting

The repository ships a template, [`srcs/.env.example`](srcs/.env.example), with every variable. Copy it and replace the `<...>` placeholders:

```sh
cp srcs/.env.example srcs/.env
nano srcs/.env    # LOGIN, WP_ADMIN_USER, WP_ADMIN_EMAIL, WP_USER, WP_USER_EMAIL
```

The other values work as they are. The template holds no passwords; if a variable is ever added to `.env`, add it to `.env.example` too.

| Group | Notes |
|-------|-------|
| `LOGIN`, `DOMAIN_NAME` | `LOGIN` drives the domain, the data path (`/home/$LOGIN/data`) and the certificate's CN. Compose expands `${LOGIN}` inside the file |
| `*_HOST` | Compose service names; Docker's internal DNS resolves them |
| `*_PORT` | Internal ports. Only `NGINX_PORT` is published on the host |
| `*_VERSION` | Pinned versions of WordPress, WP-CLI, Adminer and the Redis Object Cache plugin |
| `WP_ADMIN_USER` | The WordPress entrypoint refuses to start if it contains `admin` (in any case) |

Every script checks its variables with `: "${VAR:?}"`. A missing variable stops the container with `VAR: parameter null or not set`, instead of silently falling back to a default.

#### `secrets/`: passwords

```sh
mkdir -p secrets && chmod 700 secrets
openssl rand -hex 16 > secrets/db_password.txt
openssl rand -hex 16 > secrets/db_root_password.txt
printf 'WP_ADMIN_PASSWORD=%s\nWP_USER_PASSWORD=%s\n' \
    "$(openssl rand -hex 12)" "$(openssl rand -hex 12)" > secrets/credentials.txt
```

| File | Docker secret | Used by | Format |
|------|---------------|---------|--------|
| `db_password.txt` | `db_password` | mariadb, wordpress | the password alone |
| `db_root_password.txt` | `db_root_password` | mariadb | the password alone |
| `credentials.txt` | `credentials` | wordpress | `KEY=value` lines: `WP_ADMIN_PASSWORD`, `WP_USER_PASSWORD` |

Inside the containers, the files appear at `/run/secrets/<secret name>`. `credentials.txt` is parsed with `grep`/`cut`, never `source`d, so its content is never executed.

Check that nothing sensitive is tracked:

```sh
git check-ignore -v srcs/.env secrets/db_password.txt
```

## 2. Build and launch

```sh
make
```

This runs two steps:

1. `mkdir -p /home/$LOGIN/data/{mariadb,wordpress}`. These are the host directories behind the named volumes, and they must exist before the volumes are created.
2. `docker compose -f srcs/docker-compose.yml up -d --build`

Compose builds one image per service, each named after its service (`mariadb:inception`, `wordpress:inception`, and so on). It passes build arguments from `.env` (the `EXPOSE` ports, the WP-CLI and Adminer versions), then starts the containers. The startup order is `mariadb`, `redis` → `wordpress`, `adminer`, `website` → `nginx`. `depends_on` only orders the startup; WordPress itself waits for MariaDB to accept connections.

### What each entrypoint does

| Service | First run (empty volume) | Every start | PID 1 |
|---------|--------------------------|-------------|-------|
| mariadb | `mariadb-install-db` if needed; temporary server with `--skip-networking`; creates the database and the user `'DB_USER'@'%'`; sets the root password; shuts the temporary server down | — | `mysqld` |
| wordpress | waits for MariaDB (max 30 s); `wp core download`, `config create`, `core install`, `user create` | configures and enables the Redis Object Cache plugin if missing; `chown www-data` | `php-fpm8.2 -F` |
| nginx | — | generates a self-signed certificate; renders the conf template with `envsubst`; `nginx -t` | `nginx -g "daemon off;"` |
| redis | — | — | `redis-server` (as user `redis`) |
| adminer | — | — | `php-fpm8.2 -F` |
| website | — | checks the conf with `lighttpd -tt` | `lighttpd -D` |

## 3. Manage containers and volumes

### Makefile targets

| Target | Command | Effect |
|--------|---------|--------|
| `all` / `up` | `compose up -d --build` | build and start |
| `down` | `compose down` | remove containers and network; keep images and data |
| `stop` / `start` | `compose stop` / `start` | pause and resume without removing |
| `ps` | `compose ps` | status |
| `logs` | `compose logs -f` | follow every log |
| `clean` | `compose down --rmi all` | also remove the project images |
| `fclean` | `compose down --rmi all --volumes` + delete `/home/$LOGIN/data` | full reset |
| `re` | `fclean` + `all` | rebuild from zero |

`fclean` deletes the data through a `debian:12` container. The files belong to container users (`mysql`, `www-data`), so the host user cannot delete them without `sudo`.

### Useful commands

```sh
C="docker compose -f srcs/docker-compose.yml"

$C up -d --build wordpress            # rebuild and restart one service
$C logs -f nginx                      # logs of one service
docker exec -it mariadb bash          # shell inside a container
docker exec -it mariadb mariadb -u root -p    # SQL console (root password from secrets/)
docker exec wordpress wp --allow-root user list
docker exec wordpress wp --allow-root redis status
docker exec redis redis-cli -p 6379 info stats

docker volume ls                      # inception_mariadb, inception_wordpress
docker volume inspect inception_mariadb
docker network inspect inception_inception
docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' nginx
```

Test the TLS policy:

```sh
openssl s_client -connect 127.0.0.1:443 -tls1_2 </dev/null   # handshake succeeds
openssl s_client -connect 127.0.0.1:443 -tls1_3 </dev/null   # handshake succeeds
openssl s_client -connect 127.0.0.1:443 -tls1_1 </dev/null   # handshake fails
```

## 4. Where the data lives and how it persists

| Named volume | Mounted at | Host directory | Content |
|--------------|-----------|----------------|---------|
| `inception_mariadb` | `/var/lib/mysql` in `mariadb` | `/home/$LOGIN/data/mariadb` | database files |
| `inception_wordpress` | `/var/www/html` in `wordpress` and `nginx` | `/home/$LOGIN/data/wordpress` | WordPress core, `wp-config.php`, themes, plugins, uploads |

The volumes are declared at the top level of `docker-compose.yml` with the `local` driver and `driver_opts` (`type: none`, `o: bind`, `device: /home/${LOGIN}/data/...`). They are Docker named volumes; the options only tell the driver where to store the data.

Persistence:

- `make down` / `make` keeps the data. The entrypoints detect an existing installation (`/var/lib/mysql/$DB_NAME`, `wp-config.php`) and skip setup.
- `make fclean` deletes the data. The next `make` installs everything again.
- Redis is a pure cache. It has no volume, and persistence is disabled (`save ""`, `appendonly no`, `allkeys-lru` eviction), so losing it only costs a few slower requests.
- The TLS certificate lives inside the `nginx` container and is regenerated when the container is recreated. It is never baked into the image.

### Moving to another login

1. Change `LOGIN` (and `WP_ADMIN_USER` / `WP_ADMIN_EMAIL` if needed) in `srcs/.env`.
2. Update `/etc/hosts` with the new `<login>.42.fr`.
3. Run `make re`.

`grep -rn <old login> srcs Makefile` should then only match `srcs/.env`.
