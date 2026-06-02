# -------------------------------------------
# Bond Setup Tool
# -------------------------------------------
cat << 'BONDEOF' > /root/bond_setup.sh
#!/bin/bash

# ============================================
# BOND SETUP TOOL
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

validate_iface() {
    local IFACE=$1
    if ! ip link show "$IFACE" &>/dev/null; then
        echo -e "${RED}ERROR: Interface '$IFACE' not found on system.${NC}"
        return 1
    fi
    return 0
}

create_bond() {
    local BOND_NAME=$1
    local BOND_LABEL=$2
    local REQUIRE_GW=$3

    echo -e "\n${CYAN}--- ${BOND_NAME} (${BOND_LABEL}) Setup ---${NC}"

    if nmcli con show "$BOND_NAME" &>/dev/null; then
        echo -e "${RED}ERROR: Connection '$BOND_NAME' already exists.${NC}"
        echo -e "${YELLOW}To remove: nmcli con delete ${BOND_NAME}${NC}"
        return
    fi

    read -p "Select mode [lacp/active-backup]: " MODE
    while [[ "$MODE" != "lacp" && "$MODE" != "active-backup" ]]; do
        echo -e "${RED}Invalid mode. Enter 'lacp' or 'active-backup'.${NC}"
        read -p "Select mode [lacp/active-backup]: " MODE
    done

    read -p "Interface 1: " IF1
    validate_iface "$IF1" || return

    read -p "Interface 2: " IF2
    validate_iface "$IF2" || return

    if [[ "$IF1" == "$IF2" ]]; then
        echo -e "${RED}ERROR: Interface 1 and Interface 2 cannot be the same.${NC}"
        return
    fi

    read -p "IP/Prefix [e.g. xx.xx.xx.xx/subnet]: " IP

    if [[ "$REQUIRE_GW" == "yes" ]]; then
        read -p "Gateway [e.g. xx.xx.xx.xx]: " GW
        while [[ -z "$GW" ]]; do
            echo -e "${RED}Gateway is required for ${BOND_NAME}.${NC}"
            read -p "Gateway: " GW
        done
    else
        read -p "Gateway [leave empty=none]: " GW
    fi

    echo -e "\n${YELLOW}--- Summary ---${NC}"
    echo "  Bond     : $BOND_NAME"
    echo "  Mode     : $MODE"
    echo "  Slave 1  : $IF1"
    echo "  Slave 2  : $IF2"
    echo "  IP/Prefix: $IP"
    echo "  Gateway  : ${GW:-none}"
    echo ""
    read -p "Continue? [y/n]: " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        return
    fi

    echo -e "\n${YELLOW}Applying...${NC}"

    if [[ "$MODE" == "lacp" ]]; then
        if ! nmcli con add type bond con-name "$BOND_NAME" ifname "$BOND_NAME" \
            bond.options "mode=802.3ad,miimon=100,lacp_rate=fast,xmit_hash_policy=layer2+3"; then
            echo -e "${RED}ERROR: Failed to create bond.${NC}"; return
        fi
    else
        if ! nmcli con add type bond con-name "$BOND_NAME" ifname "$BOND_NAME" \
            bond.options "mode=active-backup,miimon=100,primary=$IF1"; then
            echo -e "${RED}ERROR: Failed to create bond.${NC}"; return
        fi
    fi

    if [[ -n "$GW" ]]; then
        if ! nmcli con modify "$BOND_NAME" ipv4.addresses "$IP" ipv4.gateway "$GW" \
            ipv4.method manual connection.autoconnect yes; then
            echo -e "${RED}ERROR: Failed to configure IP.${NC}"; return
        fi
    else
        if ! nmcli con modify "$BOND_NAME" ipv4.addresses "$IP" \
            ipv4.method manual connection.autoconnect yes; then
            echo -e "${RED}ERROR: Failed to configure IP.${NC}"; return
        fi
    fi

    if ! nmcli con add type ethernet con-name "${BOND_NAME}-slave1" ifname "$IF1" master "$BOND_NAME"; then
        echo -e "${RED}ERROR: Failed to add Slave1.${NC}"; return
    fi
    if ! nmcli con add type ethernet con-name "${BOND_NAME}-slave2" ifname "$IF2" master "$BOND_NAME"; then
        echo -e "${RED}ERROR: Failed to add Slave2.${NC}"; return
    fi

    if ! nmcli con up "$BOND_NAME"; then
        echo -e "${RED}ERROR: Failed to bring up bond.${NC}"; return
    fi

    echo -e "${GREEN}[OK] ${BOND_NAME} configured.${NC}"
    echo -e "\n${CYAN}--- Bond Status ---${NC}"
    ip addr show "$BOND_NAME"
}

main_menu() {
    while true; do
        echo -e "\n${CYAN}=========================================================="
        echo "         BOND SETUP TOOL"
        echo -e "==========================================================${NC}"
        echo "Which bond do you want to configure?"
        echo ""
        echo "  1) bond-data0  (DATA0)"
        echo "  2) bond-data1  (DATA1)"
        echo "  3) bond-bck    (BACKUP)"
        echo "  4) bond-rep    (REPLICATION)"
        echo "  5) bond-nas    (NAS)"
        echo "  6) bond-hb     (HEARTBEAT)"
        echo "  q) Exit"
        echo ""
        read -p "Your choice: " CHOICE

        case "$CHOICE" in
            1) create_bond "bond-data0" "DATA0"       "yes" ;;
            2) create_bond "bond-data1" "DATA1"       "yes" ;;
            3) create_bond "bond-bck"   "BACKUP"      "no"  ;;
            4) create_bond "bond-rep"   "REPLICATION" "no"  ;;
            5) create_bond "bond-nas"   "NAS"         "no"  ;;
            6) create_bond "bond-hb"    "HEARTBEAT"   "no"  ;;
            q|Q)
                echo -e "\n${GREEN}Exiting. Bond configuration complete.${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid selection.${NC}"
                ;;
        esac
    done
}

main_menu
BONDEOF

sed -i 's/\r$//' /root/bond_setup.sh
chmod +x /root/bond_setup.sh
