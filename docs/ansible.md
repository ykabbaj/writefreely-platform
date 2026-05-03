# Ansible Server Setup

Use the Ansible playbook to prepare a fresh VPS before running `make deploy`.
The role installs required packages, enables Docker, creates swap, opens the
needed firewall ports, and applies conservative SSH and kernel hardening.

## Install Collections

```sh
ansible-galaxy collection install -r ansible/requirements.yml
```

Or through Make:

```sh
make ansible-collections
```

## Inventory

Copy the example inventory and set your host, user, and SSH key:

```sh
cp ansible/inventory.example.yml ansible/inventory.yml
```

Example:

```yaml
all:
  children:
    writefreely:
      hosts:
        production:
          ansible_host: 203.0.113.10
          ansible_user: root
          ansible_ssh_private_key_file: ~/.ssh/writefreely-vps
```

## Run

```sh
ansible-playbook -i ansible/inventory.yml ansible/site.yml
```

Or:

```sh
make ansible-setup
```

The role keeps root SSH available for key-based login by setting
`PermitRootLogin prohibit-password`. It disables password authentication, so
confirm SSH key login works before running it.

On Ubuntu, Docker is installed from Docker's official apt repository rather
than the distro `docker.io` package.

If the host already has an older Docker apt source, the role removes common
legacy source files before writing the managed `docker.sources` file. This
cleanup runs before the first apt cache update to avoid `Signed-By` conflicts.

## Main Variables

```yaml
server_setup_deploy_user: root
server_setup_deploy_path: /opt/writefreely-platform
server_setup_swap_size: 2G
server_setup_enable_firewall: true
server_setup_enable_ssh_hardening: true
server_setup_enable_sysctl_hardening: true
```

After the playbook succeeds, run the normal deploy command:

```sh
DEPLOY_HOST=<vm-public-ip> \
SSH="ssh -i ~/.ssh/<key>" \
WRITEFREELY_IMAGE=ghcr.io/ykabbaj/writefreely-platform:v0.1.1 \
make deploy
```
