#!/bin/bash
set -e

echo "=== COMPLETE SWAY KIOSK: Firefox 1920x1080 scale=1 ==="

# 1. Install Sway + Firefox ESR (ARM optimized)
echo "Installing sway + firefox..."
sudo apt update
sudo apt install --no-install-recommends \
  sway \
  firefox-esr \
  wl-clipboard \
  grim \
  unclutter \
  xdg-utils

# 2. Kiosk user (reuse existing)
sudo adduser kiosk --disabled-password --gecos "" || true
sudo usermod -aG video,audio,dialout kiosk

# 3. COMPLETE sway config (1920x1080, scale=1, fullscreen Firefox)
sudo mkdir -p /home/kiosk/.config/sway
sudo tee /home/kiosk/.config/sway/config > /dev/null <<'EOF'
# Sway Kiosk: 1920x1080 scale 1.0, Firefox fullscreen kiosk
output * {
    resolution 1920x1080
    scale 1
    position 0,0
}

# Wayland native
exec_always {
    export MOZ_ENABLE_WAYLAND=1
    export GDK_SCALE=1
    export QT_SCALE_FACTOR=1
}

# No borders, fullscreen everything
default_border none
for_window [class=".*"] fullscreen enable
for_window [class="Firefox"] fullscreen enable

# Hide cursor
exec unclutter -idle 0.1 -root

# Firefox kiosk mode
exec firefox --kiosk --new-window "https://www.youtube.com"

# No status bar
bar {
    mode hide
}

# Touch input
input * {
    xkb_layout "us"
}

# No keybinds (locked kiosk)
bindsym $mod+Return exec swaymsg exec firefox
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
sudo tee /etc/systemd/logind.conf.d/kiosk.conf > /dev/null <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
LidSwitchIgnoreInhibited=yes
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
EOF

echo "=== SWAY KIOSK READY ==="
echo "Reboot: sudo reboot"
echo "Result: Firefox kiosk, 1920x1080, scale=1, single tap"
echo "Exit kiosk: Ctrl+Alt+F1 → login → select XFCE"
