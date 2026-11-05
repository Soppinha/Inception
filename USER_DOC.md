# User documentation

This guide is for whoever runs or administers the Inception stack: how to start it, reach the website, find the passwords and check that everything works.

Throughout this guide, `<login>` is the value of `LOGIN` in `srcs/.env`.

## 1. What the stack provides

| Service | What it is for | Address |
|---------|----------------|---------|
| WordPress website | The public site | `https://<login>.42.fr` |
| WordPress admin panel | Manage posts, pages, users and plugins | `https://<login>.42.fr/wp-admin/` |
| Adminer | Browse and edit the MariaDB database in the browser | `https://<login>.42.fr/adminer/` |
| Static page | Presentation page of the project | `https://<login>.42.fr/site/` |
| MariaDB | Stores the WordPress data | internal only |
| Redis | Speeds up WordPress by caching database results | internal only |

Everything is served over HTTPS on port 443. Nothing listens on port 80.

## 2. Start and stop

Run these commands from the root of the repository:

| Command | Effect |
|---------|--------|
| `make` | Builds what is needed and starts everything in the background |
| `make stop` | Pauses the containers (they keep their state) |
| `make start` | Resumes paused containers |
| `make down` | Stops and removes the containers. **The website data is kept** |
| `make fclean` | **Deletes everything**, including the database and the website files |

The first `make` takes a few minutes: it builds the images, then downloads and installs WordPress. Later starts take a few seconds.

If a service crashes, Docker restarts it automatically.

## 3. Access the website and the admin panel

1. Open `https://<login>.42.fr` in a browser.
2. The browser warns that the connection is not private. The certificate is self-signed, which is expected here. Choose **Advanced → Proceed**.
3. To administer the site, open `https://<login>.42.fr/wp-admin/` and log in with the administrator account (see below).

To manage the database directly, open `https://<login>.42.fr/adminer/` and fill in:

| Field | Value |
|-------|-------|
| System | MySQL / MariaDB |
| Server | `mariadb` |
| Username | value of `DB_USER` in `srcs/.env` |
| Password | content of `secrets/db_password.txt` |
| Database | value of `DB_NAME` in `srcs/.env` |

## 4. Credentials

None of these files are in Git. They exist only on the machine that runs the stack.

| What | User name | Password |
|------|-----------|----------|
| WordPress administrator | `WP_ADMIN_USER` in `srcs/.env` | `WP_ADMIN_PASSWORD` line in `secrets/credentials.txt` |
| WordPress second user | `WP_USER` in `srcs/.env` | `WP_USER_PASSWORD` line in `secrets/credentials.txt` |
| Database user (WordPress, Adminer) | `DB_USER` in `srcs/.env` | `secrets/db_password.txt` |
| Database root | `root` | `secrets/db_root_password.txt` |

To read a password: `cat secrets/credentials.txt`

### Changing a password

The files are only read **the first time** the stack is installed. After that, the passwords live in the database:

- **WordPress users:** change the password in the admin panel (*Users → Profile*). Also update `secrets/credentials.txt`, so the file matches the real password.
- **Database passwords:** the simplest way is a full reinstall, which **deletes all site data**: edit the files in `secrets/`, then run `make re`.

## 5. Check that everything is running

```sh
make ps
```

All six containers (`nginx`, `wordpress`, `mariadb`, `redis`, `adminer`, `website`) should show `Up`.

Further checks:

```sh
make logs                                    # live logs of every service (Ctrl+C to quit)
docker logs wordpress                        # logs of a single service
curl -k https://<login>.42.fr -o /dev/null -w '%{http_code}\n'   # should print 200
docker exec wordpress wp --allow-root redis status               # should show "Status: Connected"
```

Each service prints a line such as `[wordpress] Iniciando php-fpm na porta 9000...` when it is ready.

### Common problems

| Symptom | Likely cause and fix |
|---------|----------------------|
| The browser cannot find the site | `/etc/hosts` lacks `127.0.0.1 <login>.42.fr` |
| A container keeps restarting | Run `docker logs <name>`. Usually a variable is missing from `srcs/.env` (*parameter null or not set*) or a file in `secrets/` is missing |
| `make` fails with "address already in use" | Another program is using port 443 on the machine |
