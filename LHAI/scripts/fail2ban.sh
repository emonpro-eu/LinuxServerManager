#!/bin/bash

# ========================================
# FAIL2BAN PRODUCTION-SAFE MODULE
# SSH + NEXTCLOUD + UFW
# ========================================

JAIL_DIR="/etc/fail2ban/jail.d"
SSH_JAIL="$JAIL_DIR/ssh.local"
NC_JAIL="$JAIL_DIR/nextcloud.local"
NC_FILTER="/etc/fail2ban/filter.d/nextcloud.conf"

apply() {

  if check; then
    echo "[INFO] Fail2Ban already configured."
    return 0
  fi

  echo "[INFO] Installing fail2ban..."
  apt-get update -y >/dev/null 2>&1
  apt-get install -y fail2ban >/dev/null 2>&1

  mkdir -p "$JAIL_DIR"

  # ---------------- DEFAULT OVERRIDE ----------------
  if [ ! -f "$JAIL_DIR/defaults.local" ]; then
    cat > "$JAIL_DIR/defaults.local" <<EOF
[DEFAULT]
backend = systemd
bantime = 1h
findtime = 10m
maxretry = 3
banaction = ufw
EOF
  fi

  # ---------------- SSH JAIL ----------------
  if [ ! -f "$SSH_JAIL" ]; then
    cat > "$SSH_JAIL" <<EOF
[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
EOF
  fi

  # ---------------- NEXTCLOUD DETECTION ----------------
  if [ -d "/var/www/nextcloud" ] && [ -f "/var/www/nextcloud/data/nextcloud.log" ]; then
    echo "[INFO] Nextcloud detected - configuring jail..."

    # Filter file
    if [ ! -f "$NC_FILTER" ]; then
      cat > "$NC_FILTER" <<EOF
[Definition]
failregex = Login failed: .* \(Remote IP: '<HOST>'\)
ignoreregex =
EOF
    fi

    # Jail file
    if [ ! -f "$NC_JAIL" ]; then
      cat > "$NC_JAIL" <<EOF
[nextcloud]
enabled = true
port = http,https
filter = nextcloud
logpath = /var/www/nextcloud/data/nextcloud.log
maxretry = 5
EOF
    fi
  fi

  echo "[INFO] Enabling fail2ban..."
  systemctl enable fail2ban >/dev/null 2>&1
  systemctl restart fail2ban >/dev/null 2>&1

  echo "[INFO] Fail2Ban configured (production-safe)."
}

check() {

  # Package installed
  dpkg -l | grep -q "^ii  fail2ban" || return 1

  # Service active
  systemctl is-active --quiet fail2ban || return 1

  # SSH jail active
  fail2ban-client status sshd >/dev/null 2>&1 || return 1

  # If Nextcloud exists, jail must be active
  if [ -d "/var/www/nextcloud" ] && [ -f "/var/www/nextcloud/data/nextcloud.log" ]; then
    fail2ban-client status nextcloud >/dev/null 2>&1 || return 1
  fi

  # Banaction must be ufw
  grep -r "banaction *= *ufw" /etc/fail2ban >/dev/null 2>&1 || return 1
  return 0
}