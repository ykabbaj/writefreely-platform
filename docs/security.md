# Security Scanning

CI scans the custom WriteFreely image with Trivy in two passes.

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

## Advisory Scan

The advisory scan checks application dependencies embedded in the upstream
WriteFreely release binary:

```yaml
vuln-type: library
severity: CRITICAL,HIGH
exit-code: "0"
ignore-unfixed: true
```

The WriteFreely binary is downloaded from the official release tarball. If
Trivy reports Go standard library CVEs in `/opt/writefreely/writefreely`, those
findings need an upstream WriteFreely release rebuilt with a fixed Go toolchain,
or a project decision to build WriteFreely from source in this image.

The advisory scan stays visible in CI logs, but it does not block unrelated
repository changes because this repository does not currently compile the
WriteFreely binary.

## Response Policy

- Fixed OS package vulnerabilities: update the base image or package versions.
- Fixed upstream binary vulnerabilities: check for a newer WriteFreely release.
- No fixed upstream release: document the exposure and decide whether to carry a
  source-build image path.
