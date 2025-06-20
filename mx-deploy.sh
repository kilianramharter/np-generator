#!/bin/bash

# Preparation - Set IP before running:
IPV4_SERVER_IP=180.1.10.1
IPV4_SERVER_SUBNETMASK=24
IPV4_SERVER_GATEWAY=180.1.10.254

IPV6_SERVER_IP=fd00::1
IPV6_SERVER_SUBNETMASK=64
IPV6_SERVER_GATEWAY=fd00::254

SERVER_INTERFACE=ens33
SERVER_HOSTNAME=ROOT-MX
BIND_SETUP_ROOT_HINTS=1
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
echo -e "============ SERVER ============"
echo -e "IPv4 ADDRESS:\t${IPV4_SERVER_IP}/${IPV4_SERVER_SUBNETMASK}"
echo -e "IPv4 GATEWAY:\t${IPV4_SERVER_GATEWAY}"
echo -e "IPv6 ADDRESS:\t${IPV6_SERVER_IP}/${IPV6_SERVER_SUBNETMASK}"
echo -e "IPv6 GATEWAY:\t${IPV6_SERVER_GATEWAY}"
echo -e "IP IFACE:    \t${SERVER_INTERFACE}"
echo -e "HOSTNAME:    \t${SERVER_HOSTNAME}"

echo -e "\n============ BIND9 ============="
echo -e "BIND9 ROOT.HINTS: \t${BIND_SETUP_ROOT_HINTS}";

echo -en "\n\033[1;31mPRESS ENTER TO CONFIRM...\033[0m"
read

################# Hostname #################
echo -n "Setting hostname... "
sed -i "s/\(127\.0\.1\.1\s*\)$(hostname)/\1$SERVER_HOSTNAME/" /etc/hosts
hostnamectl set-hostname "$SERVER_HOSTNAME"
echo -e "\e[1;32mdone\e[0m"

################# Packages #################
if dpkg -l | grep -q "^ii  bind9 "; then
    echo "bind9 is already installed, skipping apt..."
else
    echo -n "Updating system... "
    apt -qq update -y > apt-update.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Upgrading system... "
    apt -qq upgrade -y > apt-upgrade.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Installing packages... "
    apt -qq install -y postfix > apt-install.log 2>&1
    echo -e "\e[1;32mdone\e[0m"
fi
 
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
        - $IPV6_SERVER_IP/$IPV6_SERVER_SUBNETMASK
      routes:
        - to: default
          via: $IPV4_SERVER_GATEWAY
        - to: default
          via: $IPV6_SERVER_GATEWAY
      nameservers:
          addresses:
            - 127.0.0.1
            - ::1
EOF

netplan apply
echo -e "\e[1;32mdone\e[0m"

############# BIND9-Setup #############
if [ "$BIND_SETUP_ROOT_HINTS" -eq "1" ]; then
    echo -n "Configuring root.hints... "
    cat > /etc/bind/root.hints <<EOF
.               3600000      NS    nsroot.
nsroot.         3600000      A     180.1.10.1
nsroot.         3600000      AAAA  fd00::1
EOF
    sed -i 's#/usr/share/dns/root.hints#/etc/bind/root.hints#' /etc/bind/named.conf.default-zones
    echo -e "\e[1;32mdone\e[0m"
else
    echo "Skipping root.hints setup..."
fi

############### Reboot ################
echo "Rebooting system in 5 seconds..."
sleep 5
reboot