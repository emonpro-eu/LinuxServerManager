#!/bin/bash

# ========================================
# SUDO PERMISSIONS HARDENING MODULE
# Fix /etc/sudoers.d permissions (CIS/Lynis)
# ========================================

SUDO_DIR="/etc/sudoers.d"

apply() {

  if check; then
    echo "[INFO] Sudo permissions already compliant."
    return 0
  fi

  echo "[INFO] Fixing /etc/sudoers.d permissions..."

  # Set owner root:root
  chown root:root "$SUDO_DIR"

  # Set directory permissions (750)
  chmod 750 "$SUDO_DIR"

  # Fix files inside (if any)
  if ls "$SUDO_DIR"/* >/dev/null 2>&1; then
    chown root:root "$SUDO_DIR"/*
    chmod 440 "$SUDO_DIR"/*
  fi

  # Validate sudo config
  echo "[INFO] Validating sudo configuration..."
  if ! visudo -c >/dev/null 2>&1; then
    echo "[ERROR] visudo validation failed! Check sudo configuration."
    return 1
  fi

  echo "[INFO] Sudo permissions hardened successfully."
}

check() {

  # Directory must exist
  [ -d "$SUDO_DIR" ] || return 1

  # Owner root:root
  OWNER=$(stat -c "%U:%G" "$SUDO_DIR")
  [ "$OWNER" = "root:root" ] || return 1

  # Directory permission must be 750 or stricter
  PERM=$(stat -c "%a" "$SUDO_DIR")
  [ "$PERM" -le 750 ] || return 1

  # Files inside must be 440
  if ls "$SUDO_DIR"/* >/dev/null 2>&1; then
    for file in "$SUDO_DIR"/*; do
      FILE_OWNER=$(stat -c "%U:%G" "$file")
      FILE_PERM=$(stat -c "%a" "$file")

      [ "$FILE_OWNER" = "root:root" ] || return 1
      [ "$FILE_PERM" -le 440 ] || return 1
    done
  fi

  # Validate sudo config
  visudo -c >/dev/null 2>&1 || return 1

  return 0
}