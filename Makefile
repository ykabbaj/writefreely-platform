DEV_COMPOSE ?= docker compose
RELEASE_COMPOSE ?= docker compose -f docker-compose.yml -f docker-compose.release.yml
COMPOSE ?= $(RELEASE_COMPOSE)
DOCKER ?= docker
BACKUP ?=
BACKUP_REMOTE ?=
ANSIBLE_INVENTORY ?= ansible/inventory.yml
GOMARKLINT_VERSION ?= latest

.PHONY: init up down restart logs ps build smoke-test backup restore restore-test sync-backups admin-bootstrap deploy ansible-collections ansible-setup config lint lint-shell lint-dockerfile lint-yaml lint-markdown install-gomarklint ci-local release-check dev-up dev-down dev-restart dev-build dev-smoke-test dev-backup dev-restore dev-restore-test shell db-shell theme-path

init:
	scripts/init.sh

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) up -d --force-recreate

build:
	$(MAKE) dev-build

smoke-test:
	COMPOSE="$(COMPOSE)" scripts/smoke-test.sh

logs:
	$(COMPOSE) logs -f --tail=200

ps:
	$(COMPOSE) ps

config:
	$(COMPOSE) config

lint: lint-shell lint-dockerfile lint-yaml lint-markdown

lint-shell:
	shellcheck scripts/*.sh docker/writefreely/entrypoint.sh

lint-dockerfile:
	hadolint docker/writefreely/Dockerfile

lint-yaml:
	yamllint .github/workflows ansible docker-compose.yml .yamllint.yml .hadolint.yaml

lint-markdown:
	gomarklint

install-gomarklint:
	go install github.com/shinagawa-web/gomarklint@$(GOMARKLINT_VERSION)

ci-local:
	$(DEV_COMPOSE) config
	$(RELEASE_COMPOSE) config
	sh -n docker/writefreely/entrypoint.sh
	sh -n scripts/init.sh
	sh -n scripts/admin-bootstrap.sh
	sh -n scripts/backup.sh
	sh -n scripts/deploy.sh
	sh -n scripts/restore.sh
	sh -n scripts/restore-test.sh
	sh -n scripts/smoke-test.sh
	sh -n scripts/sync-backups.sh
	$(MAKE) -n init backup restore BACKUP=backups/example restore-test admin-bootstrap deploy ansible-collections ansible-setup release-check dev-up dev-backup dev-restore BACKUP=backups/example dev-restore-test smoke-test sync-backups BACKUP_REMOTE=example:writefreely
	$(MAKE) lint

release-check:
	$(DEV_COMPOSE) config
	$(RELEASE_COMPOSE) config
	sh -n docker/writefreely/entrypoint.sh
	sh -n scripts/init.sh
	sh -n scripts/backup.sh
	sh -n scripts/restore.sh
	sh -n scripts/restore-test.sh
	sh -n scripts/smoke-test.sh
	sh -n scripts/sync-backups.sh
	$(MAKE) dev-smoke-test
	$(MAKE) dev-restore-test

dev-up:
	$(DEV_COMPOSE) up -d --build

dev-down:
	$(DEV_COMPOSE) down

dev-restart:
	$(DEV_COMPOSE) up -d --build --force-recreate

dev-build:
	$(DEV_COMPOSE) build

dev-smoke-test:
	COMPOSE="$(DEV_COMPOSE)" scripts/smoke-test.sh

dev-backup:
	COMPOSE="$(DEV_COMPOSE)" DOCKER="$(DOCKER)" scripts/backup.sh

dev-restore:
	@if [ -z "$(BACKUP)" ]; then echo "Usage: make dev-restore BACKUP=backups/<timestamp>"; exit 2; fi
	COMPOSE="$(DEV_COMPOSE)" DOCKER="$(DOCKER)" BACKUP="$(BACKUP)" scripts/restore.sh

dev-restore-test:
	COMPOSE="$(DEV_COMPOSE)" DOCKER="$(DOCKER)" scripts/restore-test.sh

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

admin-bootstrap:
	COMPOSE="$(COMPOSE)" scripts/admin-bootstrap.sh

deploy:
	scripts/deploy.sh

ansible-collections:
	ansible-galaxy collection install -r ansible/requirements.yml

ansible-setup:
	ansible-playbook -i $(ANSIBLE_INVENTORY) ansible/site.yml

shell:
	$(COMPOSE) exec writefreely /bin/sh

db-shell:
	$(COMPOSE) exec db sh -c 'mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"'

theme-path:
	@echo assets/themes/dark.css
