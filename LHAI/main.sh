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

    # ✅ Add Fix All option at top
    OPTIONS+=("Fix_All" "Run all scripts" OFF)

    for script in "$SCRIPTS_DIR"/*.sh; do
        [ -f "$script" ] || continue

        NAME=$(basename "$script")

        # Run check in isolated subshell
        if bash -c "source \"$script\" 2>/dev/null && declare -f check >/dev/null && check"; then
            STATUS="[FIXED]"
        else
            STATUS="[NOT FIXED]"
        fi

        OPTIONS+=("$NAME" "$STATUS" OFF)
    done
}

run_all() {
    echo "Running ALL hardening scripts..."
    for script in "$SCRIPTS_DIR"/*.sh; do
        [ -f "$script" ] || continue
        echo "Running $(basename "$script")..."
        bash -c "source \"$script\" && declare -f apply >/dev/null && apply"
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
            bash -c "source \"$SCRIPT_PATH\" && declare -f apply >/dev/null && apply"
        else
            echo "Script $choice not found."
        fi
    done
}

while true; do

    build_menu

    CHOICES=$(whiptail --title "CIS Hardening Control Panel" \
        --checklist "Select scripts to run:" 20 70 15 \
        "${OPTIONS[@]}" \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        clear
        exit 0
    fi

    SELECTED=()
    for item in $CHOICES; do
        SELECTED+=("${item//\"/}")
    done

    clear
    run_selected

    echo ""
    read -p "Press Enter to refresh menu..."
done