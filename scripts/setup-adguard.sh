#!/usr/bin/env bash
# Installs AdGuard Home on Mac or Linux and loads the LG TV blocklist.
# Run from the repo folder:  sudo bash scripts/setup-adguard.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$REPO_DIR/blocklist/lg-webos-ads.txt"
INSTALL_DIR="/opt/AdGuardHome"
API="http://127.0.0.1:3000"

[ "$(id -u)" -eq 0 ] || { echo "Please run with sudo."; exit 1; }

case "$(uname -s)" in
  Darwin) OS=darwin; EXT=zip; INSTALL_DIR="/Applications/AdGuardHome" ;;
  Linux)  OS=linux;  EXT=tar.gz ;;
  *) echo "Unsupported system. Use setup-adguard.ps1 on Windows."; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  armv7l) ARCH=armv7 ;;
  *) echo "Unsupported CPU: $(uname -m)"; exit 1 ;;
esac

read -rp  "Choose an AdGuard admin username: " ADMIN_USER
read -rsp "Choose an AdGuard admin password (8+ characters): " ADMIN_PASS; echo

# Linux: free up port 53 if systemd-resolved is holding it.
if [ "$OS" = linux ] && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
  echo "Freeing port 53 from systemd-resolved..."
  mkdir -p /etc/systemd/resolved.conf.d
  printf '[Resolve]\nDNS=127.0.0.1\nDNSStubListener=no\n' > /etc/systemd/resolved.conf.d/adguardhome.conf
  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  systemctl reload-or-restart systemd-resolved
fi

if [ ! -x "$INSTALL_DIR/AdGuardHome" ]; then
  echo "Downloading AdGuard Home..."
  TMP="$(mktemp -d)"
  URL="https://static.adguard.com/adguardhome/release/AdGuardHome_${OS}_${ARCH}.${EXT}"
  curl -fsSL "$URL" -o "$TMP/agh.$EXT"
  if [ "$EXT" = zip ]; then unzip -q "$TMP/agh.$EXT" -d "$TMP"; else tar -xzf "$TMP/agh.$EXT" -C "$TMP"; fi
  mkdir -p "$(dirname "$INSTALL_DIR")"
  mv "$TMP/AdGuardHome" "$INSTALL_DIR"
  rm -rf "$TMP"
  "$INSTALL_DIR/AdGuardHome" -s install
  sleep 3
fi

echo "Configuring..."
curl -fsS -X POST "$API/control/install/configure" -H 'Content-Type: application/json' -d "{
  \"web\": {\"ip\": \"0.0.0.0\", \"port\": 3000},
  \"dns\": {\"ip\": \"0.0.0.0\", \"port\": 53},
  \"username\": \"$ADMIN_USER\", \"password\": \"$ADMIN_PASS\"
}" >/dev/null || echo "(Already configured; skipping first-run setup.)"
sleep 2

COOKIES="$(mktemp)"
curl -fsS -c "$COOKIES" -X POST "$API/control/login" -H 'Content-Type: application/json' \
  -d "{\"name\": \"$ADMIN_USER\", \"password\": \"$ADMIN_PASS\"}" >/dev/null

RULES="$(grep -v '^\s*#' "$LIST" | grep -v '^\s*$' | sed 's/.*/"||&^"/' | paste -sd, -)"
curl -fsS -b "$COOKIES" -X POST "$API/control/filtering/set_rules" -H 'Content-Type: application/json' \
  -d "{\"rules\": [$RULES]}" >/dev/null
rm -f "$COOKIES"

if [ "$OS" = darwin ]; then IP="$(ipconfig getifaddr en0 || ipconfig getifaddr en1)"; else IP="$(hostname -I | awk '{print $1}')"; fi
echo
echo "Done. AdGuard Home is running and blocking LG ads."
echo "  Dashboard:  http://$IP:3000"
echo "  On the TV:  Settings > General > Network > (Wired or Wi-Fi) > Edit > DNS = $IP"
