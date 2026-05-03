COMPOSE ?= docker compose
DOCKER ?= docker
BACKUP ?=
BACKUP_REMOTE ?=

.PHONY: init up down restart logs ps build smoke-test backup restore restore-test sync-backups config release-check shell db-shell theme-path

init:
	scripts/init.sh

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) up -d --force-recreate

build:
	$(COMPOSE) build

smoke-test:
	COMPOSE="$(COMPOSE)" scripts/smoke-test.sh

logs:
	$(COMPOSE) logs -f --tail=200

ps:
	$(COMPOSE) ps

config:
	$(COMPOSE) config

release-check:
	$(COMPOSE) config
	sh -n docker/writefreely/entrypoint.sh
	sh -n scripts/init.sh
	sh -n scripts/backup.sh
	sh -n scripts/restore.sh
	sh -n scripts/restore-test.sh
	sh -n scripts/smoke-test.sh
	sh -n scripts/sync-backups.sh
	$(MAKE) smoke-test
	$(MAKE) restore-test

backup:
	COMPOSE="$(COMPOSE)" DOCKER="$(DOCKER)" scripts/backup.sh

restore:
	@if [ -z "$(BACKUP)" ]; then echo "Usage: make restore BACKUP=backups/<timestamp>"; exit 2; fi
	COMPOSE="$(COMPOSE)" DOCKER="$(DOCKER)" BACKUP="$(BACKUP)" scripts/restore.sh

restore-test:
	COMPOSE="$(COMPOSE)" DOCKER="$(DOCKER)" scripts/restore-test.sh

sync-backups:
	@if [ -z "$(BACKUP_REMOTE)" ]; then echo "Usage: make sync-backups BACKUP_REMOTE=remote:path"; exit 2; fi
	BACKUP_REMOTE="$(BACKUP_REMOTE)" scripts/sync-backups.sh

shell:
	$(COMPOSE) exec writefreely /bin/sh

db-shell:
	$(COMPOSE) exec db sh -c 'mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"'

theme-path:
	@echo assets/themes/dark.css
