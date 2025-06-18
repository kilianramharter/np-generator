#!/bin/bash

# Preparation - Set IP before running:
IPv4_SERVER_IP=180.1.10.1
IPV4_SERVER_SUBNETMASK=24
IPV4_SERVER_GATEWAY=180.1.10.254
SERVER_INTERFACE=ens33
SERVER_HOSTNAME=ROOT-DNS
#SERVER_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep ens | head -n1)
    
###########################################
# Script for Ubuntu Bind9-DNS Preparation #
# by Kilian, Chris, Michael               #
###########################################

# HINT! Run Script only as "sudo su"!
if [ "$EUID" -ne 0 ]
  then echo -e "\033[1mPlease run as root\033[0m"
  exit
fi

echo -e "\033[1mThe following settings will be applied:\033[0m"
echo "IP ADDRESS:\t${IPV4_SERVER_IP}/${IPV4_SERVER_SUBNETMASK}"
echo "IP GATEWAY:\t${IPV4_SERVER_GATEWAY}"
echo "IP IFACE:  \t${SERVER_INTERFACE}"
echo "HOSTNAME:  \t${SERVER_HOSTNAME}"

echo -en "\033[1;31mPRESS ENTER TO CONFIRM...\033[0m"
read

################# Hostname #################
echo -n "Setting hostname... "
sed -i "s/\(127\.0\.1\.1\s*\)$(hostname)/\1$SERVER_HOSTNAME/" /etc/hosts
hostnamectl set-hostname "$SERVER_HOSTNAME"
echo -e "\e[1;32mdone\e[0m"

################# Packages #################
echo -n "Updating system... "
apt -qq update -y > apt-update.log 2>&1
echo -e "\e[1;32mdone\e[0m"

echo -n "Upgrading system... "
apt -qq upgrade -y > apt-upgrade.log 2>&1
echo -e "\e[1;32mdone\e[0m"

echo -n "Installing packages... "
apt -qq install -y bind9 > apt-install.log 2>&1
echo -e "\e[1;32mdone\e[0m"
 
############### Networking ################
echo -n "Setting up networking... "

cat > /etc/netplan/50-cloud-init.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $SERVER_INTERFACE:
      addresses:
        - $IPV4_SERVER_IP/$IPV4_SERVER_SUBNETMASK
      routes:
        - to: default
          via: $IPV4_SERVER_GATEWAY
      nameservers:
          addresses: [127.0.0.1]
EOF

netplan apply
echo -e "\e[1;32mdone\e[0m"

############### Reboot ################
echo "Rebooting system in 5 seconds..."
sleep 5
reboot