#!/bin/bash
set -e

echo "=== COMPLETE SWAY KIOSK: CHROMIUM 1920x1080 scale=1 ==="

# 1. Install Sway (ARM optimized)
echo "Installing sway"
sudo apt update
sudo apt install --no-install-recommends \
  sway \
  wl-clipboard \
  grim \
  unclutter \
  xdg-utils

# 2. Kiosk user (reuse existing)
sudo adduser kiosk --disabled-password --gecos "" || true
sudo usermod -aG video,audio,dialout kiosk

# 3. COMPLETE sway config (Chromium fullscreen kiosk)
sudo mkdir -p /home/kiosk/.config/sway
sudo tee /home/kiosk/.config/sway/config > /dev/null <<'EOF'
# Sway Kiosk: 1920x1080 scale 1.0, Chromium fullscreen kiosk
output * {
    resolution 1920x1080
    scale 1
    position 0,0
}

# Wayland native + HW accel flags
exec_always {
    export CHROMIUM_FLAGS="--ozone-platform=wayland --enable-gpu-rasterization --ignore-gpu-blocklist --enable-features=VaapiVideoDecoder,VaapiVideoDecodeLinuxGL --use-gl=egl"
}

# No borders, fullscreen everything
default_border none
for_window [class=".*"] fullscreen enable
for_window [class="Chromium"] fullscreen enable

# Hide cursor
exec unclutter -idle 0.1 -root

# Chromium kiosk mode (smooth YouTube)
exec chromium --kiosk --no-first-run --disable-infobars --disable-background-timer-throttling --disable-backgrounding-occluded-windows --mute-audio $CHROMIUM_FLAGS "https://www.youtube.com"

# No status bar
bar {
    mode hide
}

# Touch input
input * {
    xkb_layout "us"
}
EOF
sudo chown -R kiosk:kiosk /home/kiosk/.config

# 4. Sway kiosk session
sudo tee /usr/share/wayland-sessions/sway-kiosk.desktop > /dev/null <<'EOF'
[Desktop Entry]
Name=Sway Kiosk
Comment=Firefox kiosk on Sway (1920x1080)
Exec=env SWAY_CONFIG=/home/kiosk/.config/sway/config sway
Type=Application
EOF

# 5. LightDM auto-login
sudo tee /etc/lightdm/lightdm.conf > /dev/null <<'EOF'
[Seat:*]
autologin-user=kiosk
autologin-session=sway-kiosk
EOF

# 6. Disable screen blanking
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/kiosk.conf > /dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
LidSwitchIgnoreInhibited=yes
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
EOF
sudo systemctl restart systemd-logind



echo "=== CHROMIUM KIOSK READY ==="
echo "Reboot: sudo reboot"
echo "Verify HW accel: In Chromium, chrome://gpu → 'Video Decode: Hardware'"
