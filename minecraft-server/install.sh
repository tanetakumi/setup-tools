#!/bin/bash

# Server Manager Service Installation Script
# This script installs systemd service files for managing Minecraft servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
SYSTEMD_DIR="/etc/systemd/system"
GITHUB_REPO="tanetakumi/setup-tools"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/${GITHUB_REPO}/main/minecraft-server"

# Variables to be set interactively
CURRENT_USER=""
CURRENT_GROUP=""
WORKING_DIR=""

# Service files
SERVICE_FILES=(
    "server-cgroup.service"
    "server-start.service"
    "server-reboot.service"
    "server-reboot.timer"
)

# Files to download from GitHub
DOWNLOAD_FILES=(
    "server-cgroup.service"
    "server-start.service"
    "server-reboot.service"
    "server-reboot.timer"
    "server-manager-updater"
)

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

ask_yes_no() {
    local prompt="$1"
    local response

    while true; do
        read -p "$(echo -e "${YELLOW}${prompt} (yes/no):${NC} ")" response
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

get_actual_user() {
    # Get the actual user who ran sudo (not root)
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

configure_user_and_group() {
    local detected_user=$(get_actual_user)

    print_info "Detected user: ${detected_user}"

    if ask_yes_no "Use '${detected_user}' as the service user?"; then
        CURRENT_USER="$detected_user"
        CURRENT_GROUP="$detected_user"
        print_info "Using user: ${CURRENT_USER}"
    else
        read -p "$(echo -e "${YELLOW}Enter username:${NC} ")" CURRENT_USER
        read -p "$(echo -e "${YELLOW}Enter group [${CURRENT_USER}]:${NC} ")" CURRENT_GROUP
        CURRENT_GROUP="${CURRENT_GROUP:-$CURRENT_USER}"
        print_info "Using user: ${CURRENT_USER}, group: ${CURRENT_GROUP}"
    fi

    # Verify user exists
    if ! id "$CURRENT_USER" &>/dev/null; then
        print_error "User '${CURRENT_USER}' does not exist"
        exit 1
    fi
}

configure_working_directory() {
    # Get the directory where the script was invoked from (not where it's located)
    local current_dir="${PWD}"

    print_info "Current directory: ${current_dir}"
    print_info "Suggested working directory: ${current_dir}"

    if ask_yes_no "Use '${current_dir}' as the working directory?"; then
        WORKING_DIR="$current_dir"
        print_info "Using working directory: ${WORKING_DIR}"
    else
        read -p "$(echo -e "${YELLOW}Enter working directory (absolute path):${NC} ")" WORKING_DIR
        print_info "Using working directory: ${WORKING_DIR}"
    fi

    # Expand tilde if present
    WORKING_DIR="${WORKING_DIR/#\~/$HOME}"

    # Verify it's an absolute path
    if [[ ! "$WORKING_DIR" = /* ]]; then
        print_error "Working directory must be an absolute path"
        exit 1
    fi
}

download_file_from_github() {
    local filename=$1
    local dest_path="$SCRIPT_DIR/$filename"
    local url="${GITHUB_RAW_BASE}/${filename}"

    print_info "Downloading ${filename} from GitHub..."

    if ! curl -fsSL --connect-timeout 10 --max-time 30 "$url" -o "$dest_path"; then
        print_error "Failed to download ${filename} from ${url}"
        return 1
    fi

    chmod +x "$dest_path"
    print_info "Downloaded ${filename} successfully"
    return 0
}

download_binary_from_github() {
    local binary_name="server-manager"
    local dest_path="$SCRIPT_DIR/${binary_name}"
    local url="${GITHUB_RAW_BASE}/${binary_name}"

    print_info "Downloading ${binary_name} from GitHub..."

    if ! curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$dest_path"; then
        print_error "Failed to download ${binary_name} from ${url}"
        return 1
    fi

    chmod +x "$dest_path"
    print_info "Downloaded ${binary_name} successfully"
    return 0
}

download_required_files() {
    local force_download=${1:-false}

    print_info "Checking required files..."

    # Download service files and scripts
    for file in "${DOWNLOAD_FILES[@]}"; do
        local file_path="$SCRIPT_DIR/$file"

        if [ -f "$file_path" ] && [ "$force_download" = false ]; then
            print_info "${file} already exists, skipping download"
        else
            if ! download_file_from_github "$file"; then
                print_error "Failed to download ${file}"
                exit 1
            fi
        fi
    done

    # Download binary
    local binary_path="$SCRIPT_DIR/server-manager"
    if [ -f "$binary_path" ] && [ "$force_download" = false ]; then
        print_info "server-manager binary already exists, skipping download"
    else
        if ! download_binary_from_github; then
            print_error "Failed to download server-manager binary"
            exit 1
        fi
    fi
}

check_binary() {
    local binary_path="$SCRIPT_DIR/server-manager"
    if [ ! -f "$binary_path" ]; then
        print_error "server-manager binary not found at $binary_path"
        print_info "Attempting to download from GitHub..."
        if ! download_binary_from_github; then
            print_error "Failed to download binary. Please check your internet connection."
            exit 1
        fi
    fi
    print_info "Found server-manager binary at $binary_path"
}

install_binary() {
    local source_binary="$SCRIPT_DIR/server-manager"
    local dest_binary="/usr/local/bin/server-manager"

    print_info "Installing server-manager binary..."

    if [ -f "$dest_binary" ]; then
        print_warn "Binary already exists at $dest_binary, replacing..."
    fi

    cp "$source_binary" "$dest_binary"
    chmod 755 "$dest_binary"
    print_info "Installed server-manager to $dest_binary"
}

install_updater() {
    local source_updater="$SCRIPT_DIR/server-manager-updater"
    local dest_updater="/usr/local/bin/server-manager-updater"

    print_info "Installing server-manager-updater script..."

    if [ ! -f "$source_updater" ]; then
        print_warn "Updater script not found at $source_updater, attempting to download..."
        if ! download_file_from_github "server-manager-updater"; then
            print_warn "Failed to download updater script, skipping..."
            return 0
        fi
    fi

    cp "$source_updater" "$dest_updater"
    chmod 755 "$dest_updater"
    print_info "Installed server-manager-updater to $dest_updater"
}

setup_timezone() {
    print_info "Setting up timezone..."

    if [ "$(date +%Z)" != "JST" ]; then
        timedatectl set-timezone Asia/Tokyo
        print_info "Timezone changed to Asia/Tokyo (JST)"
    else
        print_info "Timezone is already set to Asia/Tokyo (JST)"
    fi
}

setup_sudo_permissions() {
    print_info "Setting up sudo permissions for shutdown/reboot..."

    if ! grep -qE "^${CURRENT_USER}\\s+ALL=\\(ALL\\)\\s+NOPASSWD:\\s+/sbin/shutdown" /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
        echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: /sbin/shutdown, /sbin/reboot" > "/etc/sudoers.d/99-${CURRENT_USER}-shutdown"
        chmod 440 "/etc/sudoers.d/99-${CURRENT_USER}-shutdown"
        print_info "Granted ${CURRENT_USER} permission to use shutdown/reboot without password"
    else
        print_info "${CURRENT_USER} already has shutdown/reboot permissions"
    fi
}

disable_ipv6_ufw() {
    print_info "Checking UFW IPv6 settings..."

    if [ ! -f /etc/default/ufw ]; then
        print_warn "UFW config file not found, skipping IPv6 configuration"
        return 0
    fi

    if grep -q "^IPV6=yes" /etc/default/ufw; then
        print_info "Disabling IPv6 in UFW..."
        sed -i "s/^IPV6=.*$/IPV6=no/" /etc/default/ufw
        print_info "IPv6 has been disabled in UFW"
    else
        print_info "IPv6 is already disabled in UFW"
    fi
}

process_service_file() {
    local service_file=$1
    local source_path="$SCRIPT_DIR/$service_file"
    local dest_path="$SYSTEMD_DIR/$service_file"

    if [ ! -f "$source_path" ]; then
        print_error "Service file not found: $source_path"
        return 1
    fi

    print_info "Processing $service_file..."

    # Replace placeholders
    sed -e "s|<USER>|$CURRENT_USER|g" \
        -e "s|<GROUP>|$CURRENT_GROUP|g" \
        -e "s|<WORKING_DIR>|$WORKING_DIR|g" \
        "$source_path" > "$dest_path"

    chmod 644 "$dest_path"
    print_info "Installed $service_file to $dest_path"
}

install_services() {
    print_info "Installing service files..."

    for service_file in "${SERVICE_FILES[@]}"; do
        process_service_file "$service_file"
    done

    print_info "Reloading systemd daemon..."
    systemctl daemon-reload
}

enable_and_start_services() {
    print_info "Enabling and starting services..."

    # Enable and start cgroup service
    systemctl enable --now server-cgroup.service
    print_info "Enabled and started server-cgroup.service"

    # Enable and start main server manager service
    systemctl enable --now server-start.service
    print_info "Enabled and started server-start.service"

    # Enable reboot timer
    systemctl enable server-reboot.timer
    print_info "Enabled server-reboot.timer"

    # Check status
    sleep 2
    if systemctl is-active --quiet server-start.service; then
        print_info "server-start.service is running successfully"
    else
        print_warn "server-start.service may have failed to start"
        print_info "Check status with: sudo systemctl status server-start.service"
    fi
}

show_status() {
    print_info "Service status:"
    echo
    systemctl status server-cgroup.service --no-pager -l || true
    echo
    systemctl status server-start.service --no-pager -l || true
}

show_usage() {
    echo "Usage: sudo ./install.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -u, --uninstall  Uninstall services"
    echo
    echo "This script installs and configures systemd services for server-manager."
    echo "Required files are automatically downloaded from GitHub: ${GITHUB_REPO}"
}

uninstall_services() {
    print_info "Uninstalling services..."

    # Stop services
    for service_file in "${SERVICE_FILES[@]}"; do
        if systemctl is-active --quiet "${service_file%%.*}"; then
            systemctl stop "$service_file"
            print_info "Stopped $service_file"
        fi

        if systemctl is-enabled --quiet "${service_file%%.*}" 2>/dev/null; then
            systemctl disable "$service_file"
            print_info "Disabled $service_file"
        fi

        if [ -f "$SYSTEMD_DIR/$service_file" ]; then
            rm "$SYSTEMD_DIR/$service_file"
            print_info "Removed $service_file"
        fi
    done

    systemctl daemon-reload

    # Remove binary
    if [ -f "/usr/local/bin/server-manager" ]; then
        rm "/usr/local/bin/server-manager"
        print_info "Removed server-manager binary"
    fi

    # Remove updater
    if [ -f "/usr/local/bin/server-manager-updater" ]; then
        rm "/usr/local/bin/server-manager-updater"
        print_info "Removed server-manager-updater script"
    fi

    print_info "Uninstallation complete"
}

main() {
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -u|--uninstall)
            check_root
            uninstall_services
            exit 0
            ;;
        "")
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac

    check_root

    print_info "Server Manager Service Installation"
    print_info "===================================="
    echo

    # Download required files if not present
    download_required_files false
    echo

    # Interactive configuration
    configure_user_and_group
    configure_working_directory
    echo

    print_info "Configuration Summary"
    print_info "---------------------"
    print_info "User: $CURRENT_USER"
    print_info "Group: $CURRENT_GROUP"
    print_info "Working directory: $WORKING_DIR"
    print_info "Systemd directory: $SYSTEMD_DIR"
    echo

    if ! ask_yes_no "Proceed with installation?"; then
        print_info "Installation cancelled"
        exit 0
    fi
    echo

    check_binary
    install_binary
    install_updater
    setup_timezone
    setup_sudo_permissions
    disable_ipv6_ufw
    install_services
    enable_and_start_services

    echo
    print_info "Installation complete!"
    print_info "Useful commands:"
    print_info "  sudo systemctl status server-start.service  # Check service status"
    print_info "  sudo systemctl restart server-start.service # Restart service"
    print_info "  sudo journalctl -u server-start.service -f  # View logs"
}

main "$@"
