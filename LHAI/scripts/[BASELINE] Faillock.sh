#!/bin/bash

AUTH_FILE="/etc/pam.d/common-auth"
ACCOUNT_FILE="/etc/pam.d/common-account"

DENY=5
UNLOCK=900

apply() {

  if check; then
    echo "[INFO] PAM faillock already configured. Skipping..."
    return 0
  fi

  echo "[INFO] Configuring PAM faillock..."

  # Backup
  cp "$AUTH_FILE" "${AUTH_FILE}.bak.$(date +%F-%T)"
  cp "$ACCOUNT_FILE" "${ACCOUNT_FILE}.bak.$(date +%F-%T)"

  # Remove any existing faillock lines
  sed -i '/pam_faillock.so/d' "$AUTH_FILE"
  sed -i '/pam_faillock.so/d' "$ACCOUNT_FILE"

  # Replace pam_unix line with correct ordered block
  sed -i "/pam_unix.so/c\
auth required pam_faillock.so preauth silent audit deny=${DENY} unlock_time=${UNLOCK}\n\
auth [success=1 default=bad] pam_unix.so\n\
auth [default=die] pam_faillock.so authfail audit deny=${DENY} unlock_time=${UNLOCK}\n\
auth sufficient pam_faillock.so authsucc audit deny=${DENY} unlock_time=${UNLOCK}" \
  "$AUTH_FILE"

  # Ensure account section contains faillock
  if ! grep -q "account required pam_faillock.so" "$ACCOUNT_FILE"; then
    echo "account required pam_faillock.so" >> "$ACCOUNT_FILE"
  fi

  echo ""
  echo "✅ PAM faillock configured."
  echo "⚠️  IMPORTANT: Open a NEW SSH session and test login before closing this one."
  echo ""
}

check() {

  grep -q "pam_faillock.so preauth" "$AUTH_FILE" || return 1
  grep -q "pam_faillock.so authfail" "$AUTH_FILE" || return 1
  grep -q "pam_faillock.so authsucc" "$AUTH_FILE" || return 1
  grep -q "account required pam_faillock.so" "$ACCOUNT_FILE" || return 1

  return 0
}