#!/bin/bash

# ========================================
# HOME DIRECTORY PERMISSIONS HARDENING
# Set 750 on user home directories
# ========================================

apply() {

  if check; then
    echo "[INFO] Home directory permissions already compliant."
    return 0
  fi

  echo "[INFO] Fixing home directory permissions..."

  awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// {print $1":"$6}' /etc/passwd | while IFS=: read -r user home; do
    if [ -d "$home" ]; then
      echo "[INFO] Setting 750 on $home"
      chmod 750 "$home"
      chown "$user":"$user" "$home"
    fi
  done

  echo "[INFO] Home directory permissions updated."
}

check() {

  awk -F: '$3 >= 1000 && $3 < 65534 && $6 ~ /^\/home\// {print $6}' /etc/passwd | while read -r home; do
    if [ -d "$home" ]; then
      PERM=$(stat -c "%a" "$home")
      if [ "$PERM" -gt 750 ]; then
        return 1
      fi
    fi
  done

  return 0
}