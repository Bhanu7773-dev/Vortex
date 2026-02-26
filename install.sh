#!/usr/bin/env bash
set -euo pipefail

APP_NAME="vortex"
APP_LABEL="Vortex"
INSTALL_DIR="/opt/$APP_NAME"
DESKTOP_FILE="/usr/share/applications/$APP_NAME.desktop"
BIN_LINK="/usr/local/bin/$APP_NAME"
ICON_DIR="/usr/share/icons/hicolor/256x256/apps"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}▸${NC} $*"; }
ok()    { echo -e "${GREEN}✔${NC} $*"; }
err()   { echo -e "${RED}✖ $*${NC}" >&2; }

# ── Uninstall mode ───────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  if [[ $EUID -ne 0 ]]; then err "Run with sudo: sudo ./install.sh --uninstall"; exit 1; fi
  info "Uninstalling $APP_LABEL ..."
  rm -rf "$INSTALL_DIR"
  rm -f "$BIN_LINK"
  rm -f "$DESKTOP_FILE"
  rm -f "$ICON_DIR/$APP_NAME.png"
  update-desktop-database /usr/share/applications/ 2>/dev/null || true
  ok "$APP_LABEL uninstalled."
  exit 0
fi

# ── Root check ───────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  err "Run with sudo:  sudo ./install.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The bundle lives right next to this script
if [[ ! -f "$SCRIPT_DIR/bundle/$APP_NAME" ]]; then
  err "Cannot find bundle/$APP_NAME next to this script."
  err "Make sure you extracted the zip correctly."
  exit 1
fi

# ── Install ──────────────────────────────────────────────────────────────
info "Installing $APP_LABEL to $INSTALL_DIR ..."

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/bundle/." "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$APP_NAME"
ok "Application files copied"

# ── Symlink ──────────────────────────────────────────────────────────────
ln -sf "$INSTALL_DIR/$APP_NAME" "$BIN_LINK"
ok "Command 'vortex' available in terminal"

# ── Icon ─────────────────────────────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/vortex.png" ]]; then
  mkdir -p "$ICON_DIR"
  cp "$SCRIPT_DIR/vortex.png" "$ICON_DIR/$APP_NAME.png"
  ok "Icon installed"
fi

# ── Desktop entry ────────────────────────────────────────────────────────
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_LABEL
Comment=Fast cross-platform file transfer
Exec=$INSTALL_DIR/$APP_NAME
Icon=$APP_NAME
Terminal=false
Categories=Utility;Network;FileTransfer;
StartupWMClass=$APP_NAME
EOF
chmod 644 "$DESKTOP_FILE"
update-desktop-database /usr/share/applications/ 2>/dev/null || true
gtk-update-icon-cache -f -t /usr/share/icons/hicolor/ 2>/dev/null || true
ok "Desktop entry created"

# ── Firewall ─────────────────────────────────────────────────────────────
info "Opening firewall ports (46465-46467) ..."
if command -v firewall-cmd &>/dev/null; then
  firewall-cmd --permanent --add-port=46465/udp  2>/dev/null || true
  firewall-cmd --permanent --add-port=46466/tcp  2>/dev/null || true
  firewall-cmd --permanent --add-port=46467/tcp  2>/dev/null || true
  firewall-cmd --reload 2>/dev/null || true
  ok "firewalld rules added"
elif command -v ufw &>/dev/null; then
  ufw allow 46465/udp 2>/dev/null || true
  ufw allow 46466/tcp 2>/dev/null || true
  ufw allow 46467/tcp 2>/dev/null || true
  ok "ufw rules added"
else
  info "No firewall manager detected — manually open ports 46465-46467"
fi

echo ""
echo -e "${BOLD}${GREEN}  ✅ $APP_LABEL installed successfully!${NC}"
echo ""
echo -e "  Launch:      ${CYAN}vortex${NC}  (or find it in your app menu)"
echo -e "  Uninstall:   ${CYAN}sudo ./install.sh --uninstall${NC}"
echo ""
