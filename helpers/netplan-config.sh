#!/bin/bash

# ./netplan-config.sh ens33 180.1.10.1/24 180.1.10.254 180.1.10.5 fd00::0/64 fd00::1 fd00::5

# HINT! Run Script only as "sudo su"!
if [ "$EUID" -ne 0 ]
  then echo -e "\033[1mPlease run as root\033[0m"
  exit
fi

# Check if at least 3 arguments are passed
if [ $# -lt 4 ]; then
    echo -e "\033[1;31mMissing arguments.\033[0m"
    echo -e "\033[1;31mUsage: $0 {INTERFACE-NAME} {IPV4-CIDR-ADDRESS} {IPV4-GATEWAY} {IPV4-NAMESERVER} [IPV6-CIDR-ADDRESS] [IPV6-GATEWAY] [IPV6-NAMESERVER]\033[0m"
    exit 1
fi

SERVER_INTERFACE=$1

IPV4_CIDR_ADDRESS="$2" 
IPV4_GATEWAY="$3"
IPV4_NAMESERVER="$4"

IPV6_CIDR_ADDRESS="$5"
IPV6_GATEWAY="$6"
IPV6_NAMESERVER="$7"

NETPLAN_DIR="/etc/netplan/"
NETPLAN_FILENAME="100-$SERVER_INTERFACE-config.yaml"
NETPLAN_FILE="$NETPLAN_DIR$NETPLAN_FILENAME"

# Check if interface exists
if ! ip link show "$SERVER_INTERFACE" > /dev/null 2>&1; then
    echo -e "\033[1;31mError:\033[0m Interface '$SERVER_INTERFACE' does not exist."
    exit 1
fi


echo -n "Generating netplan config for $SERVER_INTERFACE... "

# cat > /etc/netplan/50-cloud-init.yaml <<EOF
# network:
#   version: 2
#   renderer: networkd
#   ethernets:
#     $SERVER_INTERFACE:
#       addresses:
#         - $IPV4_CIDR_ADDRESS
#         - $IPV6_CIDR_ADDRESS
#       routes:
#         - to: default
#           via: $IPV4_GATEWAY
#         - to: default
#           via: $IPV6_GATEWAY
#       nameservers:
#           addresses:
#             - $IPV4_NAMESERVER
#             - $IPV6_NAMESERVER
# EOF

# Build the YAML file
cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $SERVER_INTERFACE:
      addresses:
        - $IPV4_CIDR_ADDRESS
EOF

if [ -n "$IPV6_CIDR_ADDRESS" ]; then
    echo "        - $IPV6_CIDR_ADDRESS" >> "$NETPLAN_FILE"
fi

cat >> "$NETPLAN_FILE" <<EOF
      routes:
        - to: default
          via: $IPV4_GATEWAY
EOF

if [ -n "$IPV6_GATEWAY" ]; then
cat >> "$NETPLAN_FILE" <<EOF
        - to: default
          via: $IPV6_GATEWAY
EOF
fi

cat >> "$NETPLAN_FILE" <<EOF
      nameservers:
        addresses:
          - $IPV4_NAMESERVER
EOF

if [ -n "$IPV6_NAMESERVER" ]; then
    echo "          - $IPV6_NAMESERVER" >> "$NETPLAN_FILE"
fi

echo -e "\e[1;32mdone\e[0m"

echo -n "Applying new configuration... "
netplan apply
echo -e "\e[1;32mdone\e[0m"