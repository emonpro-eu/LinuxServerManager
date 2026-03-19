#!/bin/bash

apply() {

  if check; then
    echo "[INFO] Wazuh agent already installed and running."
    return 0
  fi

  echo "[INFO] Installing Wazuh agent..."

  wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.2-1_amd64.deb -O /tmp/wazuh-agent.deb && \
  WAZUH_MANAGER='172.64.32.190' \
  WAZUH_REGISTRATION_PASSWORD='Altceva.123' \
  WAZUH_AGENT_GROUP='Servere_Linux' \
  dpkg -i /tmp/wazuh-agent.deb

  systemctl enable wazuh-agent
  systemctl restart wazuh-agent

  echo "[INFO] Wazuh agent installation completed."
}

check() {

  dpkg -l | grep -q "^ii  wazuh-agent" || return 1
  systemctl is-active --quiet wazuh-agent || return 1

  return 0
}