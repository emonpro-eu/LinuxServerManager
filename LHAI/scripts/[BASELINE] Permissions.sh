#!/bin/bash

apply() {

  if check; then
    echo "[INFO] Permissions already compliant."
    return 0
  fi

  chmod 600 /etc/shadow
  chmod 644 /etc/passwd
  chmod 644 /etc/group
  chmod 600 /etc/gshadow

  chmod -R go-rwx /var/log

  echo "[INFO] Permissions hardened."
}

check() {

  [ "$(stat -c %a /etc/shadow)" = "600" ] || return 1
  [ "$(stat -c %a /etc/passwd)" = "644" ] || return 1
  [ "$(stat -c %a /etc/group)" = "644" ] || return 1
  [ "$(stat -c %a /etc/gshadow)" = "600" ] || return 1

  return 0
}