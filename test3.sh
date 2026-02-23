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

# Download + install touchkio ONLY
echo -e "\nDownloading touchkio..."

TMP_DIR=$(mktemp -d)
chmod 755 "$TMP_DIR"

JSON=$(wget -qO- "https://api.github.com/repos/leukipp/touchkio/releases" | tr -d '\r\n')
DEB_REG='"prerelease":\s*false.*?"browser_download_url":\s*"\K[^"]*_'$ARCH'\.deb'
DEB_URL=$(echo "$JSON" | grep -oP "$DEB_REG" | head -n 1)
DEB_PATH="${TMP_DIR}/$(basename "$DEB_URL")"

wget --show-progress -q -O "$DEB_PATH" "$DEB_URL"
sudo apt install -y "$DEB_PATH"

# **PURE TOUCHKIO KIOSK + lightdm/openbox**
echo -e "\nConfiguring TOUCHKIO-ONLY kiosk..."

apt-get update
apt-get install -y lightdm openbox unclutter locales xorg

# Kiosk user
groupadd -f kiosk
if ! id "kiosk" &>/dev/null; then
  useradd -m kiosk -g kiosk -G sudo,video,input -s /bin/bash
  echo "kiosk:!" | chpasswd
  echo "kiosk ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/kiosk
  chown -R kiosk:kiosk /home/kiosk
fi

# Xorg: no VTs/cursor
cat > /etc/X11/xorg.conf << 'EOF'
Section "ServerFlags"
    Option "DontVTSwitch" "true"
EndSection
EOF

# lightdm: TOUCHKIO kiosk
cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
xserver-command=X -nocursor -nolisten tcp
autologin-user=kiosk
autologin-session=openbox
greeter-session=lightdm-gtk-greeter
autologin-user-timeout=0
EOF

# Openbox: TOUCHKIO ONLY (NO chromium)
mkdir -p /home/kiosk/.config/openbox
cat > /home/kiosk/.config/openbox/autostart << 'EOF'
#!/bin/bash
unclutter -idle 0.1 -grab -root &

# TOUCHKIO ONLY - auto restart forever
while :; do
  touchkio
  sleep 3
done
EOF

chmod +x /home/kiosk/.config/openbox/autostart
chown -R kiosk:kiosk /home/kiosk/.config

# Disable others
systemctl disable gdm3 plymouth 2>/dev/null || true
systemctl enable lightdm

# touchkio systemd backup
mkdir -p /home/kiosk/.config/systemd/user
cat > /home/kiosk/.config/systemd/user/touchkio.service << 'EOF'
[Unit]
Description=TouchKio Kiosk
After=graphical.target network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/touchkio
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
chown kiosk:kiosk /home/kiosk/.config/systemd/user/touchkio.service
sudo -u kiosk systemctl --user daemon-reload
sudo -u kiosk systemctl --user enable touchkio.service

echo "✅ TOUCHKIO-ONLY KIOSK!"
echo "lightdm → openbox → touchkio (loop) → dispenser ready"
echo "NO chromium, NO bloat"

if $ARG_UPDATE; then exit 0; fi
echo "Reboot: sudo reboot"
