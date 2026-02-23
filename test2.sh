#!/bin/bash
set -e

echo "=== FIXED Weston kiosk (1920x1080, single tap) ==="

# 1. Install (your existing packages + fixes)
sudo apt update
sudo apt install --no-install-recommends \
  weston \
  chromium \
  xdg-utils \
  xdg-user-dirs \
  xserver-xorg-video-fbdev

# 2. Kiosk user (unchanged)
sudo adduser kiosk --disabled-password --gecos "" || true
sudo usermod -aG video,audio kiosk

# 3. FIXED kiosk script with proper Wayland + resolution
KIOSK_SCRIPT="/usr/local/bin/kiosk-wayland.sh"
echo "Creating FIXED kiosk script..."
sudo tee "$KIOSK_SCRIPT" > /dev/null <<'EOF'
#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/1001
export WAYLAND_DISPLAY=wayland-0

# Weston with FIXED 1920x1080 + scale=1
weston --tty=1 \
  --width=1920 \
  --height=1080 \
  --scale=1 \
  --fullscreen &

sleep 5

# Chromium with Wayland backend + fullscreen
chromium \
  --enable-features=UseOzonePlatform \
  --ozone-platform=wayland \
  --kiosk \
  --start-fullscreen \
  --no-first-run \
  --disable-infobars \
  --disable-restore-session-state \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-gpu-sandbox \
  --window-size=1920,1080 \
  "https://www.youtube.com"
EOF

sudo chmod +x "$KIOSK_SCRIPT"

# 4. Weston config (FIXED scaling)
sudo mkdir -p /etc/xdg/weston
sudo tee /etc/xdg/weston/weston.ini > /dev/null <<'EOF'
[core]
idle-time=0

[shell]
locking=false

[output]
mode=1920x1080@60
scale=1
EOF

# 5. LightDM (unchanged)
SESSION_FILE="/usr/share/xsessions/kiosk-wayland.desktop"
sudo tee "$SESSION_FILE" > /dev/null <<'EOF'
[Desktop Entry]
Name=Wayland Web Kiosk
Comment=Chromium kiosk on Wayland
Exec=/usr/local/bin/kiosk-wayland.sh
Type=Application
EOF

sudo tee /etc/lightdm/lightdm.conf > /dev/null <<'EOF'
[Seat:*]
autologin-user=kiosk
autologin-session=kiosk-wayland
EOF

echo "=== FIXED & READY ==="
echo "Run: sudo reboot"
echo "Result: 1920x1080, scale=1, single tap, YouTube fullscreen"
