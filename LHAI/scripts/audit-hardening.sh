#!/bin/bash

AIDE_CONF="/etc/aide/aide.conf"
FINALIZE_RULE="/etc/audit/rules.d/99-finalize.rules"

AUDIT_TOOLS=(
  auditctl
  auditd
  ausearch
  aureport
  autrace
  augenrules
)

get_tool_path() {
  readlink -f "$(command -v "$1" 2>/dev/null)"
}

apply() {

  if check; then
    echo "[INFO] Audit hardening already compliant."
    return 0
  fi

  echo "[INFO] Fixing audit tool permissions..."

  for tool in "${AUDIT_TOOLS[@]}"; do
    path=$(get_tool_path "$tool")
    [ -x "$path" ] && chmod go-w "$path"
  done

  echo "[INFO] Protecting audit tools in AIDE..."

  if [ -f "$AIDE_CONF" ]; then
    for tool in "${AUDIT_TOOLS[@]}"; do
      path=$(get_tool_path "$tool")
      if [ -x "$path" ] && ! grep -q "$path" "$AIDE_CONF"; then
        echo "$path p+i+n+u+g+s+b+acl+xattrs+sha512" >> "$AIDE_CONF"
      fi
    done
  fi

  echo "[INFO] Setting audit immutable rule..."

  mkdir -p /etc/audit/rules.d

  if ! grep -q "^-e 2" "$FINALIZE_RULE" 2>/dev/null; then
    echo "-e 2" >> "$FINALIZE_RULE"
  fi

  echo "[INFO] Loading audit rules..."
  augenrules --load 2>/dev/null

  echo
  echo "[WARNING] If audit is now immutable, reboot is required."
  echo
}

check() {

  # Check immutable rule present
  grep -q "^-e 2" "$FINALIZE_RULE" 2>/dev/null || return 1

  # Check audit tools permissions
  for tool in "${AUDIT_TOOLS[@]}"; do
    path=$(get_tool_path "$tool")
    [ -x "$path" ] || continue
    perms=$(stat -c "%a" "$path")
    case "$perms" in
      *2|*3|*6|*7) return 1 ;; # group/world write
    esac
  done

  # Check AIDE config entries
  if [ -f "$AIDE_CONF" ]; then
    for tool in "${AUDIT_TOOLS[@]}"; do
      path=$(get_tool_path "$tool")
      [ -x "$path" ] || continue
      grep -q "$path" "$AIDE_CONF" || return 1
    done
  fi

  return 0
}