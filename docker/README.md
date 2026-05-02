# Docker Runtime

This directory contains files used by the root `docker-compose.yml` stack.

- `caddy/` contains the Caddy reverse proxy config.
- `writefreely/` contains the custom WriteFreely image and entrypoint.

Run the stack from the repository root:

```sh
docker compose up -d --build
```
