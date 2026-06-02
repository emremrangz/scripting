# -------------------------------------------
# Network Port Discovery Tool
# -------------------------------------------
cat << 'SCRIPTEOF' > /root/detect_ports.sh
#!/bin/bash
{
echo "=========================================================="
echo "NETWORK PORT DISCOVERY (LLDP/CDP)"
echo "=========================================================="

UP_INTERFACES=$(ip -br link show | awk '$2 == "UP" {print $1}' | grep -v -E "lo|bond|virbr")

if [ -z "$UP_INTERFACES" ]; then
    echo "ERROR: No physical interface with LINK UP found!"
    exit 1
fi

declare -A PIDS
for IFACE in $UP_INTERFACES; do
    timeout 35 tcpdump -nn -vv -i $IFACE -s 1500 -c 1 \
        '(ether[12:2]=0x88cc or ether[20:2]=0x2000)' 2>/dev/null > /tmp/tcpdump_${IFACE} &
    PIDS[$IFACE]=$!
done

for IFACE in $UP_INTERFACES; do
    wait ${PIDS[$IFACE]}
    echo -e "\nScanning Interface: $IFACE"
    echo "----------------------------------------------------------"
    if [ -s /tmp/tcpdump_${IFACE} ]; then
        echo "SUCCESS: DATA FOUND ON [$IFACE]:"
        cat /tmp/tcpdump_${IFACE}
    else
        echo "WARNING: No LLDP/CDP packet captured on $IFACE. (Check Switch Config)"
    fi
    rm -f /tmp/tcpdump_${IFACE}
done

echo -e "\n=========================================================="
echo "Discovery finished. Master Build is Ready."
} 2>&1 | less -S
SCRIPTEOF

sed -i 's/\r$//' /root/detect_ports.sh
chmod +x /root/detect_ports.sh
