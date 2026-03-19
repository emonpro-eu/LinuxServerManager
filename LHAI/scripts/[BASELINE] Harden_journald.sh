#!/bin/bash
set -e

CONF_DIR="/etc/systemd/journald.conf.d"
CONF_FILE="$CONF_DIR/60-journald.conf"

apply() {

  if check; then
    echo "[INFO] journald already compliant."
    return 0
  fi

  echo "[INFO] Applying journald hardening..."

  mkdir -p "$CONF_DIR"

  cat > "$CONF_FILE" <<EOF
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=2G
SystemKeepFree=1G
RuntimeMaxUse=500M
RuntimeKeepFree=200M
MaxFileSec=2week
EOF

  systemctl reload-or-restart systemd-journald

  echo "[INFO] journald hardened."
}

check() {

  [ -f "$CONF_FILE" ] || return 1

  [ "$(grep -E '^Storage=' "$CONF_FILE")" = "Storage=persistent" ] || return 1
  [ "$(grep -E '^Compress=' "$CONF_FILE")" = "Compress=yes" ] || return 1
  [ "$(grep -E '^SystemMaxUse=' "$CONF_FILE")" = "SystemMaxUse=2G" ] || return 1
  [ "$(grep -E '^SystemKeepFree=' "$CONF_FILE")" = "SystemKeepFree=1G" ] || return 1
  [ "$(grep -E '^RuntimeMaxUse=' "$CONF_FILE")" = "RuntimeMaxUse=500M" ] || return 1
  [ "$(grep -E '^RuntimeKeepFree=' "$CONF_FILE")" = "RuntimeKeepFree=200M" ] || return 1
  [ "$(grep -E '^MaxFileSec=' "$CONF_FILE")" = "MaxFileSec=2week" ] || return 1

  return 0
}