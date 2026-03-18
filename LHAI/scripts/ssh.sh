#!/bin/bash

apply() {
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    systemctl restart ssh
}

check() {
    grep -q "^PermitRootLogin no" /etc/ssh/sshd_config
}