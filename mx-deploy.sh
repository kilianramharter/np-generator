#!/bin/bash

# Preparation - Set IP before running:
IPV4_SERVER_IP=180.1.10.1
IPV4_SERVER_SUBNETMASK=24
IPV4_SERVER_GATEWAY=180.1.10.254
IPV4_SERVER_NAMESERVER=180.1.10.5

IPV6_SERVER_IP=fd00::1
IPV6_SERVER_SUBNETMASK=64
IPV6_SERVER_NAMESERVER=fd00::5
IPV6_SERVER_GATEWAY=fd00::254

SERVER_INTERFACE=ens33
SERVER_HOSTNAME=ROOT-MX

DOMAIN="example.com"
HOSTNAME="mail.example.com"
MAILTYPE="Internet Site"  # Options: No configuration, Internet Site, Internet with smarthost, Satellite system, Local only
MAIL_USERS=("user1")
DEFAULT_USER_PASS="student"
    
###########################################
# Script for Ubuntu Postfix Preparation #
# by Kilian, Chris, Michael               #
###########################################

# HINT! Run Script only as "sudo su"!
if [ "$EUID" -ne 0 ]
  then echo -e "\033[1mPlease run as root\033[0m"
  exit
fi

echo -e "\033[1mThe following settings will be applied:\033[0m"
echo -e "============ SERVER ============"
echo -e "IPv4 ADDRESS:   \t${IPV4_SERVER_IP}/${IPV4_SERVER_SUBNETMASK}"
echo -e "IPv4 GATEWAY:   \t${IPV4_SERVER_GATEWAY}"
echo -e "IPv4 NAMESERVER:\t${IPV4_SERVER_NAMESERVER}"
echo -e "IPv6 ADDRESS:   \t${IPV6_SERVER_IP}/${IPV6_SERVER_SUBNETMASK}"
echo -e "IPv6 GATEWAY:   \t${IPV6_SERVER_GATEWAY}"
echo -e "IPv6 NAMESERVER:\t${IPV6_SERVER_NAMESERVER}"
echo -e "IP IFACE:       \t${SERVER_INTERFACE}"
echo -e "HOSTNAME:       \t${SERVER_HOSTNAME}"

echo -e "============ POSTFIX ==========="
echo -e "DOMAIN:        \t${DOMAIN}"
echo -e "HOSTNAME:      \t${HOSTNAME}"
echo -e "MAILTYPE:      \t${MAILTYPE}"
echo -en "USERS:        \t"
for item in "${MAIL_USERS[@]}"; do
  echo -n "$item, "
done
echo ""

echo -en "\n\033[1;31mPRESS ENTER TO CONFIRM...\033[0m"
read

################# Hostname #################
echo -n "Setting hostname... "
sed -i "s/\(127\.0\.1\.1\s*\)$(hostname)/\1$SERVER_HOSTNAME/" /etc/hosts
hostnamectl set-hostname "$SERVER_HOSTNAME"
echo -e "\e[1;32mdone\e[0m"

################# Packages #################
if dpkg -l | grep -q "^ii  postfix "; then
    echo "postfix is already installed, skipping apt..."
else
    echo -n "Updating system... "
    apt -qq update -y > apt-update.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Upgrading system... "
    apt -qq upgrade -y > apt-upgrade.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Installing package postfix... "    
    echo "postfix postfix/mailname string $DOMAIN" | debconf-set-selections
    echo "postfix postfix/main_mailer_type select $MAILTYPE" | debconf-set-selections
    export DEBIAN_FRONTEND=noninteractive
    apt -qq install -y postfix > apt-install-postfix.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Installing package dovecot... "
    apt -qq install -y dovecot-imapd dovecot-pop3d > apt-install-dovecot.log 2>&1
    echo -e "\e[1;32mdone\e[0m"
fi

############## Configuration ##############
echo -n "Configuring postfix... "
postconf -e "myhostname=$HOSTNAME"
echo -e "\e[1;32mdone\e[0m"

for MAILUSER in "${MAIL_USERS[@]}"; do
    echo -n "Creating users $MAILUSER... "
    useradd -M -s /usr/sbin/nologin $MAILUSER
    echo "$MAILUSER:$DEFAULT_USER_PASS" | chpasswd
    echo -e "\e[1;32mdone\e[0m"
done

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
            - $IPV4_SERVER_NAMESERVER
            - $IPV6_SERVER_NAMESERVER
EOF

netplan apply
echo -e "\e[1;32mdone\e[0m"

############### Reboot ################
echo "Rebooting system in 5 seconds..."
sleep 5
reboot