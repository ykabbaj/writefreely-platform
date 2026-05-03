# Security Scanning

CI scans the custom source-built WriteFreely image with Trivy in two blocking
passes.

## Runtime Hardening

The Compose stack applies container and edge hardening where it is compatible
with the upstream images:

- Caddy sends HSTS, `nosniff`, clickjacking, referrer, and permissions-policy
  headers.
- Caddy and WriteFreely drop Linux capabilities.
- Caddy keeps only `NET_BIND_SERVICE` so it can bind `80` and `443`.
- Caddy and WriteFreely run with read-only root filesystems and writable
  `tmpfs` at `/tmp`.
- Services use `no-new-privileges`.
- MySQL stays on the internal network and is not published on host ports.
- Backup directories are written with owner-only permissions.

MySQL keeps Docker's default capability set because dropping all capabilities
caused startup health failures in runtime testing. It remains isolated on the
internal Compose network.

The smoke test checks the public HTTPS endpoint and verifies the expected
security headers.

## Blocking Scan

The blocking scan checks operating system packages in the image:

```yaml
vuln-type: os
severity: CRITICAL,HIGH
exit-code: "1"
ignore-unfixed: true
```

This repository controls the Alpine base image and packages installed in the
runtime image, so fixed high and critical OS vulnerabilities should fail CI.

## Library Scan

The library scan checks application dependencies embedded in the WriteFreely
binary:

```yaml
vuln-type: library
severity: CRITICAL,HIGH
exit-code: "1"
ignore-unfixed: true
```

The image builds WriteFreely from the official source tag with the Go toolchain
version pinned in `docker/writefreely/Dockerfile`. If Trivy reports Go standard
library CVEs in `/opt/writefreely/writefreely`, update `GO_VERSION` to a patched
Go release and rebuild the image.

## Response Policy

- Fixed OS package vulnerabilities: update the base image or package versions.
- Fixed Go standard library vulnerabilities: update `GO_VERSION`.
- Fixed WriteFreely dependency vulnerabilities: check for a newer WriteFreely
  release or evaluate whether the dependency can be patched safely.
