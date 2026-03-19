#!/bin/bash

# ========================================
# KERNEL HARDENING MODULE (ROBUST)
# Safe for production + no false negatives
# ========================================

SYSCTL_FILE="/etc/sysctl.d/99-z-kernel-hardening.conf"

apply() {

  if check; then
    echo "[INFO] Kernel hardening already compliant."
    return 0
  fi

  echo "[INFO] Writing kernel hardening configuration..."

  cat > "$SYSCTL_FILE" <<EOF
# Kernel Hardening (Safe Set)

dev.tty.ldisc_autoload = 0
fs.protected_fifos = 2
kernel.core_uses_pid = 1
kernel.kptr_restrict = 2
kernel.perf_event_paranoid = 3
kernel.sysrq = 0
kernel.unprivileged_bpf_disabled = 1
EOF

  echo "[INFO] Applying sysctl settings..."
  sysctl --system >/dev/null 2>&1

  echo "[INFO] Kernel hardening applied."
}

check_param() {
  local key="$1"
  local expected="$2"

  # Verifica daca parametrul exista
  if sysctl -a 2>/dev/null | grep -q "^$key"; then
    current=$(sysctl -n "$key" 2>/dev/null)
    [ "$current" = "$expected" ] || return 1
  fi
}

check() {

  check_param "dev.tty.ldisc_autoload" "0" || return 1
  check_param "fs.protected_fifos" "2" || return 1
  check_param "kernel.core_uses_pid" "1" || return 1
  check_param "kernel.kptr_restrict" "2" || return 1
  check_param "kernel.perf_event_paranoid" "3" || return 1
  check_param "kernel.sysrq" "0" || return 1
  check_param "kernel.unprivileged_bpf_disabled" "1" || return 1

  return 0
}