#!/bin/bash

# ========================================
# APPARMOR HARDENING MODULE (DOCKER SAFE)
# Install + Enable + Safe Enforce + Real Check
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
  if ! grep -qw "apparmor=1" /proc/cmdline || ! grep -qw "security=apparmor" /proc/cmdline; then
    echo "[INFO] AppArmor not fully enabled in kernel cmdline. Updating GRUB..."

    if [ -f "$GRUB_FILE" ]; then
      CURRENT_CMDLINE=$(grep '^GRUB_CMDLINE_LINUX=' "$GRUB_FILE" | head -n1)

      if [ -n "$CURRENT_CMDLINE" ]; then
        NEW_CMDLINE="$CURRENT_CMDLINE"

        echo "$NEW_CMDLINE" | grep -qw "apparmor=1" || \
          NEW_CMDLINE=$(echo "$NEW_CMDLINE" | sed 's/"$/ apparmor=1"/')

        echo "$NEW_CMDLINE" | grep -qw "security=apparmor" || \
          NEW_CMDLINE=$(echo "$NEW_CMDLINE" | sed 's/"$/ security=apparmor"/')

        if [ "$NEW_CMDLINE" != "$CURRENT_CMDLINE" ]; then
          sed -i "s|^GRUB_CMDLINE_LINUX=.*|$NEW_CMDLINE|" "$GRUB_FILE"
          update-grub >/dev/null 2>&1
          echo "[WARNING] Reboot required to activate AppArmor kernel module."
        fi
      else
        echo "[WARNING] Could not find GRUB_CMDLINE_LINUX in $GRUB_FILE"
      fi
    else
      echo "[WARNING] GRUB file not found: $GRUB_FILE"
    fi
  fi

  # =========================
  # Safe profile handling
  # =========================
  if [ -d /etc/apparmor.d ]; then
    echo "[INFO] Loading AppArmor profiles..."
    while IFS= read -r profile; do
      apparmor_parser -r "$profile" >/dev/null 2>&1
    done < <(find /etc/apparmor.d -maxdepth 1 -type f ! -name "*.dpkg-*" ! -name "README*")

    echo "[INFO] Enforcing only known-safe base system profiles..."
    SAFE_PROFILES=(
      "/etc/apparmor.d/usr.sbin.ntpd"
      "/etc/apparmor.d/usr.sbin.chronyd"
      "/etc/apparmor.d/usr.bin.man"
    )

    for profile in "${SAFE_PROFILES[@]}"; do
      if [ -f "$profile" ]; then
        aa-enforce "$profile" >/dev/null 2>&1
      fi
    done

    echo "[INFO] Skipping container-related profiles to remain Docker safe."
  fi

  systemctl restart apparmor >/dev/null 2>&1

  echo "[INFO] AppArmor configuration complete."
}

check() {
  dpkg -l | grep -q "^ii  apparmor " || return 1
  dpkg -l | grep -q "^ii  apparmor-utils" || return 1

  systemctl is-active --quiet apparmor || return 1

  [ -f /sys/module/apparmor/parameters/enabled ] || return 1
  grep -q "^Y" /sys/module/apparmor/parameters/enabled || return 1

  STATUS_OUTPUT=$(apparmor_status 2>/dev/null) || return 1

  echo "$STATUS_OUTPUT" | grep -Eq "[0-9]+ profiles are loaded" || return 1
  echo "$STATUS_OUTPUT" | grep -Eq "[0-9]+ profiles are in enforce mode|[0-9]+ profiles are in complain mode" || return 1

  return 0
}