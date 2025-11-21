# Setup Tools

## Docker Installation

Install Docker with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/tanetakumi/setup-tools/main/docker/install.sh | sudo bash
```

**After installation**, you need to activate the docker group membership by running ONE of the following:
- Log out and log back in (recommended)
- Run: `newgrp docker`
- Run: `sudo -u $USER -i`

Then you can use Docker commands without sudo

## Minecraft Server Management

Install Minecraft server management tools with systemd services:

```bash
curl -fsSL https://raw.githubusercontent.com/tanetakumi/setup-tools/main/minecraft-server/install.sh -o install.sh && chmod +x install.sh && sudo ./install.sh
```

The installer will automatically download required files from GitHub and guide you through the interactive setup process.
