# VPS Deployment Notes

This guide targets a small Linux VPS. The deployment uses the published GHCR
image and runs Docker Compose directly on the host.

## Networking

Allow inbound traffic to the VM:

- TCP `22` from your IP for SSH.
- TCP `80` from the internet for Caddy HTTP and certificate issuance.
- TCP `443` from the internet for HTTPS.
- UDP `443` from the internet when possible for HTTP/3.

Also confirm the host firewall allows HTTP and HTTPS.

For firewalld-based distributions:

```sh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

For UFW-based distributions:

```sh
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
```

## Host Setup

SSH to the VM as `root`:

```sh
ssh root@<vm-public-ip>
```

Install Git, Make, Docker, and the Docker Compose plugin.

You can automate host setup with Ansible instead of running these commands by
hand. See `docs/ansible.md`.

For Ubuntu:

```sh
apt-get update
apt-get install -y ca-certificates curl git gnupg make
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

For RHEL-compatible distributions:

```sh
dnf install -y git make docker docker-compose-plugin
systemctl enable --now docker
```

Verify:

```sh
docker version
docker compose version
git --version
make --version
```

## Swap

One GB of RAM is tight for MySQL, Caddy, and WriteFreely. Add a small swap file
before starting the stack:

```sh
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

## First Deploy

From your workstation, deploy the published image:

```sh
DEPLOY_HOST=<vm-public-ip> \
SSH="ssh -i ~/.ssh/<key>" \
WRITEFREELY_IMAGE=ghcr.io/ykabbaj/writefreely-platform:v0.1.1 \
make deploy
```

The deploy command reads site settings from local `.env` and writes them to the
remote `.env`. Before first deploy, set production values locally:

```env
CADDY_SITE_ADDRESS=blog.example.com
WRITEFREELY_HOST=https://blog.example.com
WRITEFREELY_SITE_NAME=MyBlog
WRITEFREELY_SINGLE_USER=true
WRITEFREELY_OPEN_REGISTRATION=false
```

Use `DEPLOY_ENV_FILE=path/to/env` to deploy from a different env file, or pass
`DEPLOY_SITE_ADDRESS` / `DEPLOY_HOST_URL` to override one run.

If your SSH target is not `root@host`, use `DEPLOY_TARGET`:

```sh
DEPLOY_TARGET=user@host \
WRITEFREELY_IMAGE=ghcr.io/ykabbaj/writefreely-platform:v0.1.1 \
make deploy
```

The deploy command clones the repo into `/opt/writefreely-platform` when it is
missing, creates `.env` with generated database and admin passwords, applies
the local site settings, validates the release Compose config, pulls the image,
starts the stack, and prints `docker compose ps`.

The deploy refuses to start if `.env` still points at `localhost` or contains
default placeholder credentials.

## VM Operations

Run these on the VM:

```sh
cd /opt/writefreely-platform
make ps
make logs
make backup
make restore BACKUP=backups/<timestamp>
```

Run restore tests during maintenance windows. On a 1 GB VM, they can briefly
increase memory pressure because they create a second disposable stack.
