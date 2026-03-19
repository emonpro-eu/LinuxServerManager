#!/bin/bash

CHRONY_CONF="/etc/chrony/chrony.conf"

apply() {

  if check; then
    echo "[INFO] Chrony already compliant."
    return 0
  fi

  echo "[INFO] Installing chrony..."
  apt-get update -y
  apt-get install -y chrony

  echo "[INFO] Setting timezone to Europe/Bucharest..."
  timedatectl set-timezone Europe/Bucharest

  echo "[INFO] Configuring chrony..."

  cat > "$CHRONY_CONF" <<EOF
# Chrony CIS Hardening Configuration

server 0.ro.pool.ntp.org iburst
server 1.ro.pool.ntp.org iburst
server 2.ro.pool.ntp.org iburst
server 3.ro.pool.ntp.org iburst

driftfile /var/lib/chrony/chrony.drift
rtcsync
makestep 1.0 3

# Client only mode (disable NTP server functionality)
port 0
EOF

  echo "[INFO] Restarting chrony..."

  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable chrony
    systemctl restart chrony
  else
    service chrony restart
  fi

  echo "[INFO] Forcing immediate time sync..."
  chronyc -a makestep || true

  echo "[INFO] Chrony configuration completed."
}

check() {

  # 1️⃣ chrony installed?
  dpkg -l | grep -q "^ii  chrony" || return 1

  # 2️⃣ service active?
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active --quiet chrony || return 1
  fi

  # 3️⃣ timezone correct?
  timedatectl | grep -q "Time zone: Europe/Bucharest" || return 1

  # 4️⃣ config file exists?
  [ -f "$CHRONY_CONF" ] || return 1

  # 5️⃣ verify pool.ro servers
  grep -q "0.ro.pool.ntp.org" "$CHRONY_CONF" || return 1
  grep -q "port 0" "$CHRONY_CONF" || return 1

  return 0
}