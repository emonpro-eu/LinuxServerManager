#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)/scripts"

# Require root
if [[ $EUID -ne 0 ]]; then
    echo "Run as root."
    exit 1
fi

# Install whiptail if missing
if ! command -v whiptail &>/dev/null; then
    echo "whiptail not installed. Installing..."
    apt update && apt install -y whiptail
fi

# Enable nullglob so *.sh doesn't expand literally
shopt -s nullglob

build_menu() {

    OPTIONS=()

    # Add Fix All option
    OPTIONS+=("Fix_All" "Run all scripts" OFF)

    mapfile -t SCRIPTS < <(ls -1 "$SCRIPTS_DIR"/*.sh 2>/dev/null | sort)

    if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
        whiptail --msgbox "No scripts found in $SCRIPTS_DIR" 10 60
        exit 1
    fi

    for script in "${SCRIPTS[@]}"; do
        NAME="$(basename "$script")"

        # Run check() safely in subshell
        if bash -c "source \"$script\" 2>/dev/null; declare -f check >/dev/null && check" &>/dev/null; then
            STATUS="[FIXED]"
        else
            STATUS="[NOT FIXED]"
        fi

        OPTIONS+=("$NAME" "$STATUS" OFF)
    done
}

run_all() {

    echo "Running ALL hardening scripts..."
    echo ""

    for script in "${SCRIPTS[@]}"; do
        NAME="$(basename "$script")"
        echo "Running $NAME..."

        bash -c "source \"$script\"; declare -f apply >/dev/null && apply" || true
    done
}

run_selected() {

    for choice in "${SELECTED[@]}"; do

        if [[ "$choice" == "Fix_All" ]]; then
            run_all
            continue
        fi

        SCRIPT_PATH="$SCRIPTS_DIR/$choice"

        if [[ -f "$SCRIPT_PATH" ]]; then
            echo "Running $choice..."
            bash -c "source \"$SCRIPT_PATH\"; declare -f apply >/dev/null && apply" || true
        else
            echo "Script $choice not found."
        fi
    done
}

while true; do

    build_menu

    CHOICES=$(whiptail --title "CIS Hardening Control Panel" \
        --checklist "Select scripts to run:" 20 80 15 \
        "${OPTIONS[@]}" \
        3>&1 1>&2 2>&3)

    # Cancel pressed
    if [[ $? -ne 0 ]]; then
        clear
        exit 0
    fi

    # Safe parsing of whiptail output (handles spaces correctly)
    mapfile -t SELECTED < <(echo "$CHOICES" | tr -d '"' )

    clear
    run_selected

    echo ""
    read -rp "Press Enter to refresh menu..."
done
