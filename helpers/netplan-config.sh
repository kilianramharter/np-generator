#!/bin/bash

#########################################
############### FUNCTIONS ###############
#########################################

############### Static IP configuration
static_netplan_config() {
cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $SERVER_INTERFACE:
      addresses:
        - $IPV4_CIDR_ADDRESS
EOF
[ -n "$IPV6_CIDR_ADDRESS" ] && echo "        - $IPV6_CIDR_ADDRESS" >> "$NETPLAN_FILE"
cat >> "$NETPLAN_FILE" <<EOF
      routes:
        - to: default
          via: $IPV4_GATEWAY
EOF
[ -n "$IPV6_GATEWAY" ] && {
    echo "        - to: default" >> "$NETPLAN_FILE"
    echo "          via: $IPV6_GATEWAY" >> "$NETPLAN_FILE"
}
cat >> "$NETPLAN_FILE" <<EOF
      nameservers:
        addresses:
          - $IPV4_NAMESERVER
EOF
[ -n "$IPV6_NAMESERVER" ] && echo "          - $IPV6_NAMESERVER" >> "$NETPLAN_FILE"
}

############### Dynamic IP configuration
dynamic_netplan_config() {
cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $SERVER_INTERFACE:
      dhcp4: true
      dhcp6: true
      dhcp-identifier: mac
EOF
}


#########################################
################ PROGRAM ################
#########################################

# superuser check
if [ "$EUID" -ne 0 ]
  then echo -e "\033[1mPlease run as root\033[0m"
  exit 1
fi

# Check if at least 3 arguments are passed
DHCP_ENABLED=false
if [ $# -eq 0 ]; then
    echo -e "\033[1;31mNo arguments provided.\033[0m\n"
    echo -e "#### DHCP configuration ####"
    echo -e "Usage: $0 {INTERFACE-NAME}\n"
    echo -e "#### Static IP configuration ####"
    echo -e "Usage: $0 {INTERFACE-NAME} {IPV4-CIDR-ADDRESS} {IPV4-GATEWAY} {IPV4-NAMESERVER} [IPV6-CIDR-ADDRESS] [IPV6-GATEWAY] [IPV6-NAMESERVER]\n"
    exit 1
elif [ $# -eq 1 ]; then
    DHCP_ENABLED=true
elif [ $# -lt 4 ]; then
    # ./netplan-config.sh ens33 180.1.10.1/24 180.1.10.254 180.1.10.5 fd00::0/64 fd00::1 fd00::5
    echo -e "\033[1;31mMissing arguments.\033[0m"
    echo -e "Usage: $0 {INTERFACE-NAME} {IPV4-CIDR-ADDRESS} {IPV4-GATEWAY} {IPV4-NAMESERVER} [IPV6-CIDR-ADDRESS] [IPV6-GATEWAY] [IPV6-NAMESERVER]\n"
    exit 1
fi

SERVER_INTERFACE=$1
NETPLAN_DIR="/etc/netplan/"
NETPLAN_FILENAME="100-$SERVER_INTERFACE-config.yaml"
NETPLAN_FILE="$NETPLAN_DIR$NETPLAN_FILENAME"

IPV4_CIDR_ADDRESS="$2" 
IPV4_GATEWAY="$3"
IPV4_NAMESERVER="$4"

IPV6_CIDR_ADDRESS="$5"
IPV6_GATEWAY="$6"
IPV6_NAMESERVER="$7"


# Check if interface exists
if ! ip link show "$SERVER_INTERFACE" > /dev/null 2>&1; then
    echo -e "\033[1;31mError:\033[0m Interface '$SERVER_INTERFACE' does not exist."
    exit 1
fi

# Generate netplan config file and set correct permissions
echo -n "Generating netplan config file for $SERVER_INTERFACE... "
$DHCP_ENABLED && dynamic_netplan_config || static_netplan_config
chown root:root "$NETPLAN_FILE" && chmod 600 "$NETPLAN_FILE"
echo -e "\e[1;32mdone\e[0m"

# Validate configuration
echo -n "Validating netplan configuration... "
if netplan generate 2>/dev/null; then
    echo -e "\e[1;32mvalid\e[0m"
else
    echo -e "\e[1;31mfailed\e[0m"
    echo -e "\e[1;31mError:\033[0m Invalid netplan configuration. Not applying."
    rm "$NETPLAN_FILE"
    exit 1
fi

# Apply configuration
echo -n "Applying new netplan configuration... "
netplan apply
echo -e "\e[1;32mdone\e[0m"
exit 0