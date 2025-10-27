#! /bin/bash

# root ユーザでの実行を確認
echo "Checking if script is run as root..."
if [ "$(whoami)" != "root" ]; then
  echo "Permission denied. Please run as root."
  exit 1
fi
echo "Root check passed."

# Update apt and install prerequisite packages
echo "Updating package lists and installing prerequisites (ca-certificates, curl, gnupg)..."
apt-get update
apt-get install -y ca-certificates curl gnupg
echo "Prerequisites installed."

# Create keyrings directory for Docker GPG key
echo "Creating /etc/apt/keyrings directory..."
install -m 0755 -d /etc/apt/keyrings
echo "Directory created."

# Download and add Docker's GPG key
echo "Downloading Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "Docker GPG key added."

# Add Docker repository to apt sources
echo "Adding Docker repository to apt sources..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
echo "Docker repository added and package lists updated."

# Install Docker packages
echo "Installing Docker packages (docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin)..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
echo "Docker installation completed."

# Enable and start Docker service
echo "Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker
echo "Docker service started."

# Give it a moment
sleep 1

# Determine the non-root user who invoked sudo
USER=$(logname)
if [ -z "$USER" ]; then
  echo "Cannot detect login user. Exiting."
  exit 1
fi
echo "Detected login user: $USER"

# Add user to docker group
echo "Adding $USER to the docker group..."
usermod -aG docker "$USER"
echo "$USER has been added to the docker group."

# Activate new group in current shell
echo "Activating docker group in current shell..."
exec newgrp docker
