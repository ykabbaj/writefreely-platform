# Security Scanning

CI scans the custom source-built WriteFreely image with Trivy in two blocking
passes.

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
