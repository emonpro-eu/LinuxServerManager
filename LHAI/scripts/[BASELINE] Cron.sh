#!/bin/bash

apply() {

  if check; then
    echo "[INFO] Cron already hardened."
    return 0
  fi

  touch /etc/cron.allow
  chmod 600 /etc/cron.allow

  rm -f /etc/cron.deny

  echo "[INFO] Cron hardened."
}

check() {

  [ -f /etc/cron.allow ] || return 1
  [ "$(stat -c %a /etc/cron.allow)" = "600" ] || return 1
  [ ! -f /etc/cron.deny ] || return 1

  return 0
}