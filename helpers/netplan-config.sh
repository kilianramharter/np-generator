#!/bin/bash

# ./netplan-config.sh 180.1.10.0/24 180.1.10.1 180.1.10.5 fd00::0/64 fd00::1 fd00::5
# ./netplan-config.sh {IPV4-CIDR} {IPV4-ADDRESS} {IPV4-NAMESERVER} [IPV6-CIDR] [IPV6-ADDRESS] [IPV6-NAMESERVER]

# HINT! Run Script only as "sudo su"!
if [ "$EUID" -ne 0 ]
  then echo -e "\033[1mPlease run as root\033[0m"
  exit
fi

# Check if at least 3 arguments are passed
if [ $# -lt 3 ]; then
    echo -e "\033[1;31mMissing arguments.\033[0m"
    echo -e "\033[1;31mUsage: $0 {IPV4-CIDR-ADDRESS} {IPV4-GATEWAY} {IPV4-NAMESERVER} [IPV6-CIDR-ADDRESS] [IPV6-GATEWAY] [IPV6-NAMESERVER]\033[0m"
    exit 1
fi



IPV4_CIDR_ADDRESS="$1" 
IPV4_GATEWAY="$2"
IPV4_NAMESERVER="$3"

IPV6_CIDR_ADDRESS="$4"
IPV6_GATEWAY="$5"
IPV6_NAMESERVER="$6"

SERVER_INTERFACE=ens33
NETPLAN_DIR="/etc/netplan/"
NETPLAN_FILE="${NETPLAN_DIR}50-cloud-init.yaml"

#IPV4_SERVER_IP=180.1.10.1
#IPV4_SERVER_SUBNETMASK=24
#IPV4_SERVER_GATEWAY=180.1.10.254
#IPV4_SERVER_NAMESERVER=180.1.10.5

#IPV6_SERVER_IP=fd00::1
#IPV6_SERVER_SUBNETMASK=64
#IPV6_SERVER_NAMESERVER=fd00::5
#IPV6_SERVER_GATEWAY=fd00::254


# SERVER_HOSTNAME=ROOT-MX

echo -n "Setting up networking... "

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

echo -e "network:" > $NETPLAN_FILE
echo -e "\tversion: 2"; >> $NETPLAN_FILE
echo -e "\trenderer: networkd"; >> $NETPLAN_FILE
echo -e "\tethernets:" >> $NETPLAN_FILE
echo -e "\t\t$SERVER_INTERFACE:" >> $NETPLAN_FILE
echo -e "\t\t\taddresses:" >> $NETPLAN_FILE
echo -e "\t\t\t- $IPV4_CIDR_ADDRESS" >> $NETPLAN_FILE
if [ -n "$IPV6_CIDR_ADDRESS" ]; then
    echo -e "\t\t\t- $IPV6_CIDR_ADDRESS" >> $NETPLAN_FILE
fi
echo -e "\t\t\troutes:" >> $NETPLAN_FILE
echo -e "\t\t\t - to: default" >> $NETPLAN_FILE
echo -e "\t\t\t   via: $IPV4_GATEWAY" >> $
if [ -n "$IPV6_GATEWAY" ]; then
    echo -e "\t\t\t - to: default" >> $NETPLAN_FILE
    echo -e "\t\t\t   via: $IPV6_GATEWAY" >> $NETPLAN_FILE
fi
echo -e "\t\t\tnameservers:" >> $NETPLAN_FILE
echo -e "\t\t\t\taddresses:" >> $NETPLAN_FILE
echo -e "\t\t\t\t- $IPV4_NAMESERVER" >> $NETPLAN_FILE
if [ -n "$IPV6_NAMESERVER" ]; then
    echo -e "\t\t\t\t- $IPV6_NAMESERVER" >> $NETPLAN_FILE
fi

netplan apply
echo -e "\e[1;32mdone\e[0m"