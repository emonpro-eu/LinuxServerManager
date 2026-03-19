#!/bin/bash

# ========================================
# APPARMOR HARDENING MODULE (FULL)
# Install + Kernel Enable + Enforce + Real Check
# ========================================

GRUB_FILE="/etc/default/grub"

apply() {

  echo "[INFO] Installing AppArmor packages..."
  apt-get update -y >/dev/null 2>&1
  apt-get install -y apparmor apparmor-utils >/dev/null 2>&1

  echo "[INFO] Enabling AppArmor service..."
  systemctl enable apparmor >/dev/null 2>&1
  systemctl start apparmor >/dev/null 2>&1

  # =========================
  # Kernel parameter check
  # =========================
  if ! grep -q "apparmor=1" /proc/cmdline; then
    echo "[INFO] AppArmor not enabled in kernel. Updating GRUB..."

    if ! grep -q "apparmor=1" "$GRUB_FILE"; then
      sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor /' "$GRUB_FILE"
      update-grub >/dev/null 2>&1
    fi

    echo "[WARNING] Reboot required to activate AppArmor kernel module."
  fi

  # =========================
  # Enforce profiles
  # =========================
  if [ -d /etc/apparmor.d ]; then
    echo "[INFO] Setting all profiles to enforce mode..."
    aa-enforce /etc/apparmor.d/* >/dev/null 2>&1
  fi

  systemctl restart apparmor >/dev/null 2>&1

  echo "[INFO] AppArmor configuration complete."
}

check() {

  # 1️⃣ Packages installed
  dpkg -l | grep -q "^ii  apparmor " || return 1
  dpkg -l | grep -q "^ii  apparmor-utils" || return 1

  # 2️⃣ Service active
  systemctl is-active --quiet apparmor || return 1

  # 3️⃣ Kernel AppArmor enabled
  if [ -f /sys/module/apparmor/parameters/enabled ]; then
    grep -q "Y" /sys/module/apparmor/parameters/enabled || return 1
  else
    return 1
  fi

  STATUS_OUTPUT=$(apparmor_status 2>/dev/null)

  # 4️⃣ Profiles loaded
  echo "$STATUS_OUTPUT" | grep -q "profiles are loaded" || return 1

  # 5️⃣ Complain mode must be 0
  COMPLAIN=$(echo "$STATUS_OUTPUT" | grep "profiles are in complain mode" | awk '{print $1}')
  [ "$COMPLAIN" = "0" ] || return 1

  # 6️⃣ Unconfined processes must be 0
  UNCONFINED=$(echo "$STATUS_OUTPUT" | grep "processes are unconfined" | awk '{print $1}')
  [ "$UNCONFINED" = "0" ] || return 1

  return 0
}