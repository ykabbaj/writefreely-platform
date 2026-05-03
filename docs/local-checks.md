## Local Checks

Run the same checks locally before pushing to reduce CI surprises.

## Install Tools

The local lint targets expect these tools on your workstation:

- `shellcheck`
- `hadolint`
- `yamllint`
- `go`
- `gomarklint`

For Python-based tools:

```sh
python3 -m pip install --user yamllint
```

For gomarklint:

```sh
make install-gomarklint
```

`make install-gomarklint` uses:

```sh
go install github.com/shinagawa-web/gomarklint@latest
```

## Fast Checks

```sh
make ci-local
```

This renders Compose config, checks shell syntax, dry-runs Make targets, and
runs all lint targets.

Run individual linters with:

```sh
make lint-shell
make lint-dockerfile
make lint-yaml
make lint-markdown
```

## Runtime Checks

Use these before tagging a release image:

```sh
make dev-smoke-test
make dev-restore-test
```
