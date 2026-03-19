#!/bin/bash

SYSCTL_FILE="/etc/sysctl.d/99-hardening.conf"

PARAMS=(
"kernel.randomize_va_space=2"
"fs.suid_dumpable=0"
"net.ipv4.ip_forward=1"
"net.ipv6.conf.all.forwarding=0"
"net.ipv4.conf.all.accept_redirects=0"
"net.ipv4.conf.default.accept_redirects=0"
"net.ipv6.conf.all.accept_redirects=0"
"net.ipv6.conf.default.accept_redirects=0"
"net.ipv4.conf.all.secure_redirects=0"
"net.ipv4.conf.default.secure_redirects=0"
"net.ipv4.conf.all.accept_source_route=0"
"net.ipv4.conf.default.accept_source_route=0"
"net.ipv6.conf.all.accept_source_route=0"
"net.ipv6.conf.default.accept_source_route=0"
"net.ipv4.conf.all.log_martians=1"
"net.ipv4.conf.default.log_martians=1"
"net.ipv4.icmp_echo_ignore_broadcasts=1"
"net.ipv4.icmp_ignore_bogus_error_responses=1"
"net.ipv4.conf.all.rp_filter=1"
"net.ipv4.conf.default.rp_filter=1"
"net.ipv4.tcp_syncookies=1"
)

apply() {

  if check; then
    echo "[INFO] Sysctl already compliant."
    return 0
  fi

  echo "[INFO] Applying CIS L1 sysctl hardening..."

  echo "# CIS Level 1 Hardening" > "$SYSCTL_FILE"

  for p in "${PARAMS[@]}"; do
    echo "$p" >> "$SYSCTL_FILE"
  done

  sysctl --system
  echo "[INFO] Sysctl hardening applied."
}

check() {

  # 1️⃣ fișier există?
  [ -f "$SYSCTL_FILE" ] || return 1

  for p in "${PARAMS[@]}"; do

    key="${p%%=*}"
    value="${p##*=}"

    # 2️⃣ verificare în fișier
    grep -q "^$key *= *$value" "$SYSCTL_FILE" || return 1

    # 3️⃣ verificare valoare live
    current=$(sysctl -n "$key" 2>/dev/null)
    [ "$current" = "$value" ] || return 1
  done

  return 0
}