ENV_FILE	:= srcs/.env
LOGIN		:= $(shell grep '^LOGIN=' $(ENV_FILE) | cut -d= -f2)
DATA_DIR	:= /home/$(LOGIN)/data
COMPOSE		:= docker compose -f srcs/docker-compose.yml

all: up

up: dirs
	$(COMPOSE) up -d --build

dirs:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down --rmi all

fclean:
	$(COMPOSE) down --rmi all --volumes
	@if [ -d $(DATA_DIR) ]; then \
		docker run --rm -v $(DATA_DIR):/data debian:12 sh -c 'rm -rf /data/*'; \
		rmdir $(DATA_DIR); \
		echo "$(DATA_DIR) removido"; \
	fi

re: fclean all

.PHONY: all up dirs down start stop ps logs clean fclean re
