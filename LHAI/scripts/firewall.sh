#!/bin/bash

# ========================================
# FIREWALL HARDENING MODULE (UFW ONLY)
# Fara configurare loopback
# ========================================

CONFIG_FILE="/etc/hardening/firewall.conf"

apply() {

  mkdir -p /etc/hardening

  local ports_input src_ips port ip

  echo "========================================"
  echo "[INFO] Porturi care asculta pe sistem:"
  echo "========================================"

  if command -v ss >/dev/null 2>&1; then
    ss -tulnp
  else
    netstat -tulnp 2>/dev/null || echo "Nu pot afisa porturile."
  fi

  echo ""
  read -rp "Introdu porturile care trebuie permise (ex: 22,80,443): " ports_input

  read -rp "Vrei sa restrictionezi SSH doar pe IP-uri specifice? (y/N): " restrict_ssh

  if [[ "$restrict_ssh" =~ ^[Yy]$ ]]; then
    read -rp "Introdu IP-urile/CIDR permise pentru SSH: " src_ips
  fi

  # Instaleaza UFW daca lipseste
  if ! command -v ufw >/dev/null 2>&1; then
    echo "[INFO] Instalez UFW..."
    apt-get update -y
    apt-get install -y ufw
  fi

  # Elimina nftables complet (un singur firewall)
  if dpkg -l | grep -q "^ii  nftables"; then
    echo "[INFO] Elimin nftables..."
    systemctl stop nftables 2>/dev/null
    systemctl disable nftables 2>/dev/null
    apt-get purge -y nftables
  fi

  echo "[INFO] Reset UFW..."
  ufw --force reset

  echo "[INFO] Setare politici default..."
  ufw default deny incoming
  ufw default allow outgoing

  # Permitere porturi
  IFS=',' read -ra ports <<< "$ports_input"

  for port in "${ports[@]}"; do
    port="$(echo "$port" | xargs)"

    if [[ "$port" == "22" && -n "${src_ips:-}" ]]; then
      IFS=',' read -ra ips <<< "$src_ips"
      for ip in "${ips[@]}"; do
        ip="$(echo "$ip" | xargs)"
        [[ -n "$ip" ]] && ufw allow from "$ip" to any port 22 proto tcp
      done
    else
      [[ -n "$port" ]] && ufw allow "${port}/tcp"
    fi
  done

  echo "[INFO] Activare firewall..."
  ufw --force enable

  {
    echo "PORTS=$ports_input"
    echo "SSH_RESTRICT=$restrict_ssh"
    echo "SSH_IPS=$src_ips"
  } > "$CONFIG_FILE"

  echo ""
  echo "[INFO] Firewall configurat (UFW only)."
}

check() {

  # UFW activ
  ufw status | grep -q "^Status: active" || return 1

  # nftables nu trebuie sa fie instalat
  if dpkg -l | grep -q "^ii  nftables"; then
    return 1
  fi

  # Politica default incoming
  ufw status verbose | grep -q "Default: deny (incoming)" || return 1

  # Config file existent
  [ -f "$CONFIG_FILE" ] || return 1

  source "$CONFIG_FILE"

  # Verificare porturi
  IFS=',' read -ra ports <<< "$PORTS"

  for port in "${ports[@]}"; do
    port="$(echo "$port" | xargs)"
    ufw status | grep -q "${port}/tcp" || return 1
  done

  return 0
}