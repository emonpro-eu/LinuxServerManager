#!/bin/bash

############################################
# REQUIRE ROOT
############################################

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)."
  exit 1
fi

############################################
# FIND NETPLAN FILE
############################################

NETPLAN_FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -n1)

if [ -z "$NETPLAN_FILE" ]; then
  echo "No netplan YAML file found in /etc/netplan/"
  exit 1
fi

############################################
# DETECT ACTIVE INTERFACE
############################################

INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n1)

if [ -z "$INTERFACE" ]; then
  echo "No active network interface detected."
  exit 1
fi

############################################
# GET CURRENT NETWORK DATA
############################################

CURRENT_ADDR=$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}')
CURRENT_IP=$(echo "$CURRENT_ADDR" | cut -d/ -f1)
CURRENT_PREFIX=$(echo "$CURRENT_ADDR" | cut -d/ -f2)
CURRENT_GW=$(ip route | awk '/default/ {print $3}')

############################################
# PREFIX → NETMASK
############################################

prefix2mask() {
  local prefix=$1
  local mask=""
  local full=$((prefix/8))
  local part=$((prefix%8))

  for ((i=0;i<4;i++)); do
    if [ $i -lt $full ]; then
      mask+="255"
    elif [ $i -eq $full ]; then
      mask+=$((256 - 2**(8-part)))
    else
      mask+="0"
    fi
    [ $i -lt 3 ] && mask+="."
  done
  echo "$mask"
}

############################################
# NETMASK → PREFIX
############################################

mask2prefix() {
  local mask=$1
  local prefix=0
  IFS=.
  for octet in $mask; do
    case $octet in
      255) ((prefix+=8));;
      254) ((prefix+=7));;
      252) ((prefix+=6));;
      248) ((prefix+=5));;
      240) ((prefix+=4));;
      224) ((prefix+=3));;
      192) ((prefix+=2));;
      128) ((prefix+=1));;
      0) ;;
      *) return 1;;
    esac
  done
  echo $prefix
}

############################################
# IP VALIDATION
############################################

valid_ip() {
  local ip=$1
  [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=.
  for octet in $ip; do
    ((octet >= 0 && octet <= 255)) || return 1
  done
}

############################################
# GET CURRENT DNS (best effort)
############################################

CURRENT_DNS=$(grep -A3 "nameservers:" "$NETPLAN_FILE" 2>/dev/null | \
              grep "-" | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')

############################################
# DISPLAY CURRENT CONFIG
############################################

CURRENT_MASK=$(prefix2mask "$CURRENT_PREFIX")

echo "--------------------------------------"
echo "Netplan file : $NETPLAN_FILE"
echo "Interface    : $INTERFACE"
echo "Current IP   : $CURRENT_IP"
echo "Netmask      : $CURRENT_MASK"
echo "Gateway      : $CURRENT_GW"
echo "DNS          : ${CURRENT_DNS:-Not set}"
echo "--------------------------------------"
echo ""

############################################
# USER INPUT
############################################

read -p "Enter new IP [$CURRENT_IP]: " NEW_IP
NEW_IP=${NEW_IP:-$CURRENT_IP}

read -p "Enter new Netmask [$CURRENT_MASK]: " NEW_MASK
NEW_MASK=${NEW_MASK:-$CURRENT_MASK}

read -p "Enter new Gateway [$CURRENT_GW]: " NEW_GW
NEW_GW=${NEW_GW:-$CURRENT_GW}

read -p "Enter DNS servers comma-separated [$CURRENT_DNS]: " NEW_DNS
NEW_DNS=${NEW_DNS:-$CURRENT_DNS}

############################################
# VALIDATION
############################################

valid_ip "$NEW_IP" || { echo "Invalid IP."; exit 1; }
valid_ip "$NEW_GW" || { echo "Invalid Gateway."; exit 1; }

NEW_PREFIX=$(mask2prefix "$NEW_MASK") || {
  echo "Invalid netmask."
  exit 1
}

IFS=',' read -ra DNS_ARRAY <<< "$NEW_DNS"
for dns in "${DNS_ARRAY[@]}"; do
  valid_ip "$dns" || { echo "Invalid DNS: $dns"; exit 1; }
done

############################################
# CONFIRMATION
############################################

echo ""
echo "New configuration:"
echo "IP      : $NEW_IP/$NEW_PREFIX"
echo "Gateway : $NEW_GW"
echo "DNS     : $NEW_DNS"
echo ""

read -p "Apply changes using netplan try (safe mode)? (y/n): " CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy]$ ]] && { echo "Cancelled."; exit 0; }

############################################
# BACKUP
############################################

BACKUP="${NETPLAN_FILE}.bak.$(date +%F-%H%M%S)"
cp "$NETPLAN_FILE" "$BACKUP"
echo "Backup created: $BACKUP"

############################################
# FORMAT DNS FOR YAML
############################################

DNS_YAML=""
for dns in "${DNS_ARRAY[@]}"; do
  DNS_YAML+="          - $dns"$'\n'
done

############################################
# WRITE MODERN NETPLAN CONFIG
############################################

cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $NEW_IP/$NEW_PREFIX
      routes:
        - to: default
          via: $NEW_GW
      nameservers:
        addresses:
$DNS_YAML
EOF

############################################
# APPLY SAFELY
############################################

echo ""
echo "Applying configuration using netplan try..."
echo "If connection fails, it will auto-revert."

if netplan try; then
  echo ""
  echo "✅ Static IP and DNS configured successfully."
else
  echo ""
  echo "❌ Configuration failed. Restoring backup..."
  cp "$BACKUP" "$NETPLAN_FILE"
  netplan apply
  exit 1
fi

exit 0
