#!/data/data/com.termux/files/usr/bin/bash
# MateShell — локальная установка Debian + XFCE + VNC + VS Code (ARM64)
set -e
export DEBIAN_FRONTEND=noninteractive

MSH="$HOME/mate-shell"
mkdir -p "$MSH"
LOG="$MSH/install.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== MateShell Linux bootstrap $(date) ==="

pkg update -y
pkg install -y proot-distro root-repo x11-repo tur-repo
pkg install -y pulseaudio novnc websockify

if ! proot-distro list | grep -q "debian"; then
  proot-distro install debian
fi

proot-distro login debian <<'DEBIAN'
set -e
export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade -y
apt install -y \
  xfce4 xfce4-terminal tigervnc-standalone-server tigervnc-common \
  dbus-x11 sudo wget curl git ca-certificates \
  firefox-esr menu mesa-utils \
  python3 python3-pip nodejs npm

mkdir -p ~/.vnc
echo "mateshell" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

cat > ~/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
exec startxfce4
EOF
chmod +x ~/.vnc/xstartup

if ! command -v code >/dev/null 2>&1; then
  ARCH=$(dpkg --print-architecture)
  if [ "$ARCH" = "arm64" ]; then
    wget -q -O /tmp/code.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64" || true
    if [ -f /tmp/code.deb ]; then
      apt install -y /tmp/code.deb || apt install -yf
      rm -f /tmp/code.deb
    fi
  fi
fi

cat > /usr/local/bin/mateshell-start-vnc <<'START'
#!/bin/bash
export USER=root
export HOME=/root
vncserver -kill :1 2>/dev/null || true
# -localhost no — порт 5901 доступен из Termux/Android
vncserver :1 -geometry 1920x1080 -depth 24 -localhost no
echo "TigerVNC :5901"
START
chmod +x /usr/local/bin/mateshell-start-vnc

cat > /usr/local/bin/mateshell-stop-vnc <<'STOP'
#!/bin/bash
vncserver -kill :1 2>/dev/null || true
STOP
chmod +x /usr/local/bin/mateshell-stop-vnc

echo "Debian desktop ready"
DEBIAN

cat > "$MSH/start-linux.sh" <<'LOCAL'
#!/data/data/com.termux/files/usr/bin/bash
MSH="$HOME/mate-shell"
pkill -f "websockify.*6080" 2>/dev/null || true
proot-distro login debian -- bash -lc "mateshell-start-vnc"
sleep 2
# noVNC в Termux — WebView MateShell открывает http://127.0.0.1:6080
nohup websockify --web "$PREFIX/share/novnc" 6080 127.0.0.1:5901 >> "$MSH/vnc.log" 2>&1 &
echo "noVNC http://127.0.0.1:6080"
LOCAL
chmod +x "$MSH/start-linux.sh"

cat > "$MSH/stop-linux.sh" <<'LOCAL2'
#!/data/data/com.termux/files/usr/bin/bash
pkill -f "websockify.*6080" 2>/dev/null || true
proot-distro login debian -- bash -lc "mateshell-stop-vnc"
LOCAL2
chmod +x "$MSH/stop-linux.sh"

echo "=== DONE ==="
echo "Run: bash ~/mate-shell/start-linux.sh"
