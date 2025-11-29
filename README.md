# Setup Tools

Utility scripts for setting up development tools and services. The current scope is limited to Docker installation helpers; legacy Minecraft server tooling has been removed.

## Docker installation

Install Docker with a single command on Ubuntu:

```bash
curl -fsSL https://raw.githubusercontent.com/tanetakumi/setup-tools/main/docker/install.sh | sudo bash
```

After installation, activate the Docker group membership by running **one** of the following:
- Log out and log back in (recommended)
- Run: `newgrp docker`
- Run: `sudo -u $USER -i`

You can then run Docker commands without `sudo`.

### What the installer does

- Installs Docker CE, CLI, containerd, Buildx, and Compose from Docker's official repository.
- Enables and starts the Docker daemon.
- Adds the invoking non-root user to the `docker` group so you can run Docker commands without `sudo`.

### Notes

- The script must be run as `root` (e.g., via `sudo`).
- Tested on Ubuntu; other distributions are not supported by this helper.
- If you previously installed Docker from another source, remove it before running this script to avoid conflicts.
