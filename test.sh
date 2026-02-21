#!/bin/bash
set -e

echo "=== Setting up Wayland web kiosk (no X11) ==="

# 1. Install minimal Wayland + Chromium
echo "Installing weston and chromium-browser..."
sudo apt update
sudo apt install --no-install-recommends \
  weston \
  xdg-utils \
  xdg-user-dirs

# 2. Create kiosk user
echo "Creating kiosk user..."
sudo adduser kiosk --disabled-password --gecos "" || true
sudo usermod -aG video,audio kiosk

# 3. Create kiosk script
KIOSK_SCRIPT="/usr/local/bin/kiosk-wayland.sh"
echo "Creating kiosk script: $KIOSK_SCRIPT"
sudo tee "$KIOSK_SCRIPT" > /dev/null <<'EOF'
#!/bin/bash
# Wait a bit for the system
sleep 3

# Start weston compositor
weston --tty=1 --fullscreen &

# Wait for weston to be ready
sleep 3

# Start Chromium in kiosk mode
chromium \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-restore-session-state \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-gpu \
  "https://www.youtube.com"
EOF

sudo chmod +x "$KIOSK_SCRIPT"

# 4. Create LightDM session
SESSION_FILE="/usr/share/xsessions/kiosk-wayland.desktop"
echo "Creating LightDM session: $SESSION_FILE"
sudo tee "$SESSION_FILE" > /dev/null <<'EOF'
[Desktop Entry]
Name=Wayland Web Kiosk
Comment=Chromium kiosk on Wayland
Exec=/usr/local/bin/kiosk-wayland.sh
Type=Application
EOF

# 5. Configure LightDM auto-login
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
echo "Configuring LightDM auto-login..."
sudo mkdir -p /etc/lightdm
sudo tee "$LIGHTDM_CONF" > /dev/null <<'EOF'
[Seat:*]
autologin-user=kiosk
autologin-session=kiosk-wayland
EOF

echo "=== Setup complete ==="
echo "Reboot to start the Wayland web kiosk:"
echo "  sudo reboot"
echo ""
echo "To change the URL, edit:"
echo "  sudo nano /usr/local/bin/kiosk-wayland.sh"
