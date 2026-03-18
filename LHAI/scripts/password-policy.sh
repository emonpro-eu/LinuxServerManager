#!/bin/bash

PWQUALITY="/etc/security/pwquality.conf"
LOGIN_DEFS="/etc/login.defs"

apply() {

  if check; then
    echo "[INFO] Password policy already compliant."
    return 0
  fi

  apt-get install -y libpam-pwquality

  # Configure pwquality
  sed -i '/^minlen/d' "$PWQUALITY"
  sed -i '/^minclass/d' "$PWQUALITY"

  echo "minlen = 14" >> "$PWQUALITY"
  echo "minclass = 4" >> "$PWQUALITY"

  # Configure password aging
  sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 99999/' "$LOGIN_DEFS"
  sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 7/' "$LOGIN_DEFS"
  sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' "$LOGIN_DEFS"

  echo "[INFO] Password policy applied."
}

check() {

  grep -q "^minlen = 14" "$PWQUALITY" || return 1
  grep -q "^minclass = 4" "$PWQUALITY" || return 1
  grep -q "^PASS_MAX_DAYS 99999" "$LOGIN_DEFS" || return 1
  grep -q "^PASS_MIN_DAYS 7" "$LOGIN_DEFS" || return 1
  grep -q "^PASS_WARN_AGE 7" "$LOGIN_DEFS" || return 1

  return 0
}