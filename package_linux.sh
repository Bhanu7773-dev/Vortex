#!/usr/bin/env bash
set -euo pipefail

# Builds the Linux release and packages it into a zip that anyone can
# extract and run:  sudo ./install.sh

APP_NAME="vortex"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${CYAN}▸${NC} $*"; }
ok()   { echo -e "${GREEN}✔${NC} $*"; }

info "Building Linux release..."
flutter build linux --release

BUNDLE="$SCRIPT_DIR/build/linux/x64/release/bundle"
STAGING="/tmp/${APP_NAME}_package"

rm -rf "$STAGING"
mkdir -p "$STAGING/bundle"

# Copy bundle
cp -r "$BUNDLE/." "$STAGING/bundle/"

# Copy install script
cp "$SCRIPT_DIR/install.sh" "$STAGING/install.sh"
chmod +x "$STAGING/install.sh"

# Copy icon
if [[ -f "$SCRIPT_DIR/assets/app_logo.png" ]]; then
  cp "$SCRIPT_DIR/assets/app_logo.png" "$STAGING/vortex.png"
fi

# Create the tar.gz
OUT="$SCRIPT_DIR/Vortex-linux-x64.tar.gz"
rm -f "$OUT"
cd /tmp && tar czf "$OUT" "${APP_NAME}_package/"

rm -rf "$STAGING"

echo ""
ok "Package ready: $OUT"
echo -e "  Your friend extracts and runs:"
echo -e "  ${CYAN}tar xzf Vortex-linux-x64.tar.gz${NC}"
echo -e "  ${CYAN}cd vortex_package && sudo ./install.sh${NC}"
echo ""
