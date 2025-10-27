# Setup Tools

## Docker Installation

Install Docker with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/tanetakumi/setup-tools/main/docker/install.sh | sudo bash
```

## Minecraft Server Management

Install Minecraft server management tools with systemd services:

```bash
curl -fsSL https://raw.githubusercontent.com/tanetakumi/setup-tools/main/minecraft-server/install.sh -o install.sh && chmod +x install.sh && sudo ./install.sh
```

The installer will automatically download required files from GitHub and guide you through the interactive setup process.
