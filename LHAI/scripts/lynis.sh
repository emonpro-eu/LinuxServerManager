#!/bin/bash

# ========================================
# LYNIS INSTALLATION MODULE
# ========================================

REPORT_DIR="/var/log/lynis"
LYNIS_BIN="/usr/bin/lynis"

apply() {

  if check; then
    echo "[INFO] Lynis este deja instalat."
    return 0
  fi

  echo "[INFO] Instalare Lynis..."

  apt-get update -y >/dev/null 2>&1
  apt-get install -y lynis >/dev/null 2>&1

  echo "[INFO] Creez director pentru rapoarte..."
  mkdir -p "$REPORT_DIR"
  chmod 700 "$REPORT_DIR"

  echo "[INFO] Instalare finalizata."
  echo ""
  echo "Pentru a rula un audit manual:"
  echo "  lynis audit system"
  echo ""
  echo "Pentru audit cu raport salvat:"
  echo "  lynis audit system --report-file $REPORT_DIR/lynis-report.dat"
}

check() {

  if ! command -v lynis >/dev/null 2>&1; then
    return 1
  fi

  if ! lynis --version >/dev/null 2>&1; then
    return 1
  fi

  return 0
}