#!/bin/bash

# ./netplan-config.sh 180.1.10.0/24 180.1.10.1 180.1.10.5 fd00::0/64 fd00::1 fd00::5
# ./netplan-config.sh {IPV4-CIDR} {IPV4-ADDRESS} {IPV4-NAMESERVER} [IPV6-CIDR] [IPV6-ADDRESS] [IPV6-NAMESERVER]

# HINT! Run Script only as "sudo su"!
if [ "$EUID" -ne 0 ]
  then echo -e "\033[1mPlease run as root\033[0m"
  exit
fi

echo "Usage: $0 {IPV4-CIDR} {IPV4-ADDRESS} {IPV4-NAMESERVER} [IPV6-CIDR] [IPV6-ADDRESS] [IPV6-NAMESERVER]"

IPV4_SERVER_IP=180.1.10.1
IPV4_SERVER_SUBNETMASK=24
IPV4_SERVER_GATEWAY=180.1.10.254
IPV4_SERVER_NAMESERVER=180.1.10.5

IPV6_SERVER_IP=fd00::1
IPV6_SERVER_SUBNETMASK=64
IPV6_SERVER_NAMESERVER=fd00::5
IPV6_SERVER_GATEWAY=fd00::254

SERVER_INTERFACE=ens33
# SERVER_HOSTNAME=ROOT-MX

echo -n "Setting up networking... "

cat > /etc/netplan/50-cloud-init.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $SERVER_INTERFACE:
      addresses:
        - $IPV4_SERVER_IP/$IPV4_SERVER_SUBNETMASK
        - $IPV6_SERVER_IP/$IPV6_SERVER_SUBNETMASK
      routes:
        - to: default
          via: $IPV4_SERVER_GATEWAY
        - to: default
          via: $IPV6_SERVER_GATEWAY
      nameservers:
          addresses:
            - $IPV4_SERVER_NAMESERVER
            - $IPV6_SERVER_NAMESERVER
EOF

netplan apply
echo -e "\e[1;32mdone\e[0m"