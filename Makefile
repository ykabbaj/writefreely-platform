COMPOSE ?= docker compose
DOCKER ?= docker
BACKUP ?=
BACKUP_REMOTE ?=

.PHONY: up down restart logs ps build backup restore sync-backups config shell db-shell theme-path

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) up -d --force-recreate

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f --tail=200

ps:
	$(COMPOSE) ps

config:
	$(COMPOSE) config

backup:
	COMPOSE="$(COMPOSE)" DOCKER="$(DOCKER)" scripts/backup.sh

restore:
	@if [ -z "$(BACKUP)" ]; then echo "Usage: make restore BACKUP=backups/<timestamp>"; exit 2; fi
	COMPOSE="$(COMPOSE)" DOCKER="$(DOCKER)" BACKUP="$(BACKUP)" scripts/restore.sh

sync-backups:
	@if [ -z "$(BACKUP_REMOTE)" ]; then echo "Usage: make sync-backups BACKUP_REMOTE=remote:path"; exit 2; fi
	BACKUP_REMOTE="$(BACKUP_REMOTE)" scripts/sync-backups.sh

shell:
	$(COMPOSE) exec writefreely /bin/sh

db-shell:
	$(COMPOSE) exec db sh -c 'mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"'

theme-path:
	@echo assets/themes/dark.css
