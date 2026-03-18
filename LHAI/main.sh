#!/bin/bash

set -e

SCRIPTS_DIR="$(dirname "$0")/scripts"

# Install whiptail if missing
if ! command -v whiptail &>/dev/null; then
    echo "whiptail not installed. Installing..."
    apt update && apt install -y whiptail
fi

# Require root
if [ "$EUID" -ne 0 ]; then
    echo "Run as root."
    exit 1
fi

build_menu() {
    OPTIONS=()

    for script in "$SCRIPTS_DIR"/*.sh; do
        [ -f "$script" ] || continue

        NAME=$(basename "$script")

        # Rulăm check în subshell izolat
        if bash -c "source \"$script\" 2>/dev/null && declare -f check >/dev/null && check"; then
            STATUS="[FIXED]"
        else
            STATUS="[NOT FIXED]"
        fi

        OPTIONS+=("$NAME" "$STATUS" OFF)
    done
}

run_selected() {

    for choice in "${SELECTED[@]}"; do
        SCRIPT_PATH="$SCRIPTS_DIR/$choice"

        if [[ -f "$SCRIPT_PATH" ]]; then
            echo "Running $choice..."
            bash -c "source \"$SCRIPT_PATH\" && declare -f apply >/dev/null && apply"
        else
            echo "Script $choice not found."
        fi
    done
}

while true; do

    build_menu

    CHOICES=$(whiptail --title "CIS Hardening Control Panel" \
        --checklist "Select scripts to run:" 20 70 10 \
        "${OPTIONS[@]}" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        clear
        exit 0
    fi

    # Transformăm output în array sigur
    SELECTED=()
    for item in $CHOICES; do
        SELECTED+=("${item//\"/}")
    done

    clear
    run_selected

    echo ""
    read -p "Press Enter to refresh menu..."
done