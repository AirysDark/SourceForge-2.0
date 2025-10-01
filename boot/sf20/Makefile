SHELL := /bin/bash
PROJECT := sourceforge20
COMPOSE := docker compose
FILES := compose/base.yml compose/proxy.yml compose/core.yml compose/runner.yml compose/codespace.yml compose/observability.yml

.PHONY: up down pull logs ps restart proxy core runner codespace observability uptime

up:
	$(COMPOSE) -f $(FILES) up -d

down:
	$(COMPOSE) -f $(FILES) down

pull:
	$(COMPOSE) -f $(FILES) pull

logs:
	$(COMPOSE) -f $(FILES) logs -f --tail=200

ps:
	$(COMPOSE) -f $(FILES) ps

proxy:
	$(COMPOSE) -f compose/proxy.yml up -d

core:
	$(COMPOSE) -f compose/base.yml -f compose/core.yml up -d

runner:
	$(COMPOSE) -f compose/runner.yml up -d

codespace:
	$(COMPOSE) -f compose/codespace.yml up -d

observability:
	$(COMPOSE) -f compose/observability.yml up -d

uptime:
	$(COMPOSE) -f compose/uptime.yml up -d
