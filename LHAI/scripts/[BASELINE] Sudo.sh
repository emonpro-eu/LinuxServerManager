#!/bin/bash

SUDOERS="/etc/sudoers"

apply() {

  if check; then
    echo "[INFO] Sudo already hardened."
    return 0
  fi

  if ! grep -q "Defaults use_pty" "$SUDOERS"; then
    echo "Defaults use_pty" >> "$SUDOERS"
  fi

  if ! grep -q 'Defaults logfile="/var/log/sudo.log"' "$SUDOERS"; then
    echo 'Defaults logfile="/var/log/sudo.log"' >> "$SUDOERS"
  fi

  touch /var/log/sudo.log
  chmod 600 /var/log/sudo.log

  echo "[INFO] Sudo hardened."
}

check() {

  grep -q "Defaults use_pty" "$SUDOERS" || return 1
  grep -q 'Defaults logfile="/var/log/sudo.log"' "$SUDOERS" || return 1

  return 0
}