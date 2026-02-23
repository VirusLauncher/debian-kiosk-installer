#!/usr/bin/env bash

# Read arguments
ARG_EARLY=false
ARG_UPDATE=false
for arg in "$@"; do
  case "$arg" in
    early) ARG_EARLY=true ;;
    update) ARG_UPDATE=true ;;
  esac
done

# Determine system architecture
echo -e "Determining system architecture..."

BITS=$(getconf LONG_BIT)
case "$(uname -m)" in
    x86_64) ARCH="x64" ;;
    aarch64) ARCH="arm64" ;;
    *) { echo "Architecture $(uname -m) running $BITS-bit operating system is not supported."; exit 1; } ;;
esac

[ "$BITS" -eq 64 ] || { echo "Architecture $ARCH running $BITS-bit operating system is not supported."; exit 1; }
echo "Architecture $ARCH running $BITS-bit operating system is supported."

# Download the latest .deb package
echo -e "\nDownloading the latest release..."

TMP_DIR=$(mktemp -d)
chmod 755 "$TMP_DIR"

JSON=$(wget -qO- "https://api.github.com/repos/leukipp/touchkio/releases" | tr -d '\r\n')
if $ARG_EARLY; then
  DEB_REG='"prerelease":\s*(true|false).*?"browser_download_url":\s*"\K[^\"]*_'$ARCH'\.deb'
else
  DEB_REG='"prerelease":\s*false.*?"browser_download_url":\s*"\K[^\"]*_'$ARCH'\.deb'
fi

DEB_URL=$(echo "$JSON" | grep -oP "$DEB_REG" | head -n 1)
DEB_PATH="${TMP_DIR}/$(basename "$DEB_URL")"

[ -z "$DEB_URL" ] && { echo "Download url for .deb file not found."; exit 1; }
wget --show-progress -q -O "$DEB_PATH" "$DEB_URL" || { echo "Failed to download the .deb file."; exit 1; }

# Install the latest .deb package
echo -e "\nInstalling the latest release..."

command -v apt &> /dev/null || { echo "Package manager apt was not found."; exit 1; }
sudo apt install -y "$DEB_PATH" || { echo "Installation of .deb file failed."; exit 1; }

# **KIOSK AUTOSETUP: Create kiosk user + lightdm autologin**
echo -e "\nConfiguring kiosk autologin..."

# Create kiosk user (no password)
if ! id "kiosk" &>/dev/null; then
  sudo useradd -m -G sudo,video,input -s /bin/bash kiosk || { echo "Failed to create kiosk user."; exit 1; }
  echo "kiosk:!" | sudo chpasswd  # Locked password (no login)
  echo "*;kiosk;*:Result1:Result2:Result3:Result4" | sudo chpasswd -e  # NOPASSWD sudo
  echo "kiosk ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/kiosk
  echo "Session created for kiosk user."
else
  echo "kiosk user already exists."
fi

# Install/configure lightdm for autologin
sudo apt install -y lightdm || { echo "Failed to install lightdm."; exit 1; }

# lightdm autologin config
sudo tee /etc/lightdm/lightdm.conf > /dev/null << 'EOF'
[Seat:*]
autologin-user=kiosk
autologin-session=lightdm
greeter-session=lightdm-gtk-greeter
user-session=sway
EOF

# Disable other display managers
sudo systemctl disable gdm3 plymouth 2>/dev/null || true
sudo systemctl enable lightdm

# Kiosk sway config (auto-start touchkio)
mkdir -p /home/kiosk/.config/sway
sudo tee /home/kiosk/.config/sway/config > /dev/null << 'EOF'
output * {
    resolution 1920x1080
    scale 1
}
exec /usr/bin/touchkio
EOF
sudo chown -R kiosk:kiosk /home/kiosk/.config

echo "LightDM kiosk autologin configured."

# Create the systemd user service (unchanged)
echo -e "\nCreating systemd user service..."

SERVICE_NAME="touchkio.service"
SERVICE_FILE="/home/kiosk/.config/systemd/user/$SERVICE_NAME"
mkdir -p "$(dirname "$SERVICE_FILE")"

SERVICE_CONTENT="[Unit]
Description=TouchKio
After=graphical.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/touchkio
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target"

echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE"
sudo chown kiosk:kiosk "$SERVICE_FILE"
sudo -u kiosk systemctl --user enable "$(basename "$SERVICE_FILE")"
echo "Kiosk touchkio service enabled."

# Export display variables (unchanged)
echo -e "\nExporting display variables..."
export DISPLAY="${DISPLAY-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY-wayland-0}"
echo "DISPLAY=\"$DISPLAY\", WAYLAND_DISPLAY=\"$WAYLAND_DISPLAY\"."

if $ARG_UPDATE; then
  echo "Setup complete. Reboot for kiosk autologin."
  exit 0
fi

echo -e "\n✅ KIOSK READY! Reboot → lightdm autologins kiosk → touchkio kiosk mode."
echo "Run as sudo ./script.sh update  (future updates)"
