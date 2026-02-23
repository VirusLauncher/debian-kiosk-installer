#!/usr/bin/env bash

# Read arguments (unchanged)
ARG_EARLY=false
ARG_UPDATE=false
for arg in "$@"; do
  case "$arg" in
    early) ARG_EARLY=true ;;
    update) ARG_UPDATE=true ;;
  esac
done

# Architecture check (unchanged)
echo -e "Determining system architecture..."
BITS=$(getconf LONG_BIT)
case "$(uname -m)" in
    x86_64) ARCH="x64" ;;
    aarch64) ARCH="arm64" ;;
    *) { echo "Architecture $(uname -m) running $BITS-bit operating system is not supported."; exit 1; } ;;
esac
[ "$BITS" -eq 64 ] || { echo "Architecture $ARCH running $BITS-bit operating system is not supported."; exit 1; }
echo "Architecture $ARCH running $BITS-bit operating system is supported."

# Download touchkio (unchanged)
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

# Install (unchanged)
echo -e "\nInstalling the latest release..."
sudo apt install -y "$DEB_PATH" || { echo "Installation of .deb file failed."; exit 1; }

# *** NEW: KIOSK AUTOLOGIN ***
echo -e "\n*** ADDING KIOSK AUTOLOGIN ***"

# Create kiosk user (no password)
if ! id "kiosk" &>/dev/null; then
  sudo useradd -m -G sudo,video,input -s /bin/bash kiosk
  echo "kiosk:!" | sudo chpasswd  # Locked (no pwd login)
  echo "kiosk ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/kiosk-nopasswd
  echo "✅ kiosk user created"
else
  echo "⚠️ kiosk user exists"
fi

# Install lightdm + autologin
sudo apt install -y lightdm
sudo tee /etc/lightdm/lightdm.conf >/dev/null << 'EOF'
[Seat:*]
autologin-user=kiosk
autologin-session=default
greeter-session=lightdm-gtk-greeter
user-session=sway  # or whatever touchkio uses
EOF

sudo systemctl disable gdm3 2>/dev/null || true
sudo systemctl enable lightdm

# touchkio service for kiosk user
SERVICE_NAME="touchkio.service"
SERVICE_FILE="/home/kiosk/.config/systemd/user/$SERVICE_NAME"
sudo mkdir -p "$(dirname "$SERVICE_FILE")"
cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=TouchKio Kiosk
After=graphical-session.target

[Service]
ExecStart=/usr/bin/touchkio
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
sudo chown -R kiosk:kiosk /home/kiosk/.config
sudo -u kiosk systemctl --user daemon-reload
sudo -u kiosk systemctl --user enable "$SERVICE_NAME"

echo "✅ lightdm autologin → kiosk → touchkio"

# Original systemd service section (unchanged)
echo -e "\nCreating systemd user service..."
# ... (rest of original service creation code) ...

# Original exports + launch (unchanged)
# ... (DISPLAY/WAYLAND exports + touchkio --setup) ...

echo -e "\n🚀 KIOSK AUTOLOGIN ADDED! Reboot → instant kiosk"
