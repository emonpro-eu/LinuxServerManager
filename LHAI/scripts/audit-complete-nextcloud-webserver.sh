#!/bin/bash

GRUB_FILE="/etc/default/grub"
AUDIT_CONF="/etc/audit/auditd.conf"
RULE_FILE="/etc/audit/rules.d/50-essential.rules"

UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

apply() {

  if check; then
    echo "[INFO] Audit configuration already compliant."
    return 0
  fi

  echo "[INFO] Installing audit packages..."
  apt-get update -y >/dev/null 2>&1
  apt-get install -y auditd audispd-plugins >/dev/null 2>&1

  echo "[INFO] Configuring GRUB audit parameters..."
  if ! grep -q "audit=1" "$GRUB_FILE"; then
    sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="audit=1 audit_backlog_limit=8192 /' "$GRUB_FILE"
    update-grub >/dev/null 2>&1
  fi

  echo "[INFO] Configuring auditd.conf..."
  sed -i 's/^max_log_file_action.*/max_log_file_action = keep_logs/' "$AUDIT_CONF"
  sed -i 's/^disk_full_action.*/disk_full_action = single/' "$AUDIT_CONF"
  sed -i 's/^disk_error_action.*/disk_error_action = single/' "$AUDIT_CONF"

  echo "[INFO] Creating essential audit rules..."
  mkdir -p /etc/audit/rules.d

  cat > "$RULE_FILE" <<EOF

## USER EMULATION
-a always,exit -F arch=b64 -C euid!=uid -F auid>=${UID_MIN} -F auid!=unset -S execve -k user_emulation
-a always,exit -F arch=b32 -C euid!=uid -F auid>=${UID_MIN} -F auid!=unset -S execve -k user_emulation

## PERMISSION MODIFICATION
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat,chown,fchown,lchown,fchownat,setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=${UID_MIN} -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat,chown,fchown,lchown,fchownat,setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=${UID_MIN} -F auid!=unset -k perm_mod

## IDENTITY FILES
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k identity

## DELETE EVENTS
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=${UID_MIN} -F auid!=unset -k delete
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=${UID_MIN} -F auid!=unset -k delete

## KERNEL MODULES
-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -F auid>=${UID_MIN} -F auid!=unset -k kernel_modules

## TIME CHANGE
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

## SUDO LOG
-w /var/log/sudo.log -p wa -k sudo_log_file

## SESSION FILES
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

EOF

  echo "[INFO] Fixing permissions..."
  find /etc/audit/ -type f -name "*.rules" -exec chmod 640 {} +
  chown -R root:root /etc/audit

  echo "[INFO] Loading rules..."
  augenrules --load >/dev/null 2>&1
  systemctl enable auditd >/dev/null 2>&1
  systemctl restart auditd >/dev/null 2>&1

  echo "[INFO] Audit configuration applied."
  echo "[NOTICE] Reboot required for audit=1 kernel parameter."
}

check() {

  dpkg -s auditd >/dev/null 2>&1 || return 1
  grep -q "audit=1" "$GRUB_FILE" || return 1
  grep -q "max_log_file_action = keep_logs" "$AUDIT_CONF" || return 1
  grep -q "disk_full_action = single" "$AUDIT_CONF" || return 1
  grep -q "user_emulation" "$RULE_FILE" || return 1
  grep -q "perm_mod" "$RULE_FILE" || return 1
  grep -q "identity" "$RULE_FILE" || return 1
  grep -q "kernel_modules" "$RULE_FILE" || return 1
  grep -q "time-change" "$RULE_FILE" || return 1

  return 0
}