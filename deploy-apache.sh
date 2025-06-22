#!/bin/bash

# install apache2
# php latest
# mariadb
# certbot

# wordpress autoinstall (WP-CLI)


# connect apache2 with php
# create vhosts (in a loop)
    # type empty / php / wordpress

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

ALLOWED_NETWORKS="180.1.10.0/24 [fd00::]/64" # VERY IMPORTANT: Enter networks that should be allowed to send here
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
echo -e "DOMAIN:         \t${DOMAIN}"
echo -e "HOSTNAME:       \t${HOSTNAME}"
echo -e "MAILTYPE:       \t${MAILTYPE}"
echo -e "ALLOWED NWS:    \t${ALLOWED_NETWORKS}"
echo -en "USERS:         \t"
for item in "${MAIL_USERS[@]}"; do
  echo -n "$item, "
done
echo -e "DEFAULT PASS:   \t${DEFAULT_USER_PASS}"
echo ""

echo -en "\n\033[1;31mPRESS ENTER TO CONFIRM...\033[0m"
read

################# Hostname #################
echo -n "Setting hostname... "
sed -i "s/\(127\.0\.1\.1\s*\)$(hostname)/\1$SERVER_HOSTNAME/" /etc/hosts
hostnamectl set-hostname "$SERVER_HOSTNAME"
echo -e "\e[1;32mdone\e[0m"

################# Packages #################
if dpkg -l | grep -q "^ii  mariadb-server"; then
    echo "mariadb is already installed, skipping apt..."
else
    echo -n "Updating system... "
    apt -qq update -y > apt-update.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Upgrading system... "
    apt -qq upgrade -y > apt-upgrade.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Installing package apache2... "    
    apt -qq install -y apache2 apache2-utils > apt-install-apache2.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Installing package php... "
    # apt -qq install -y php php-cli php-common php-imap php-fpm php-snmp php-xml php-zip php-mbstring php-curl php-mysqli php-gd php-intl > apt-install-php.log 2>&1
    # apt -qq install -y php libapache2-mod-php php-mysql php-curl php-gd php-json php-intl php-bcmath php-opcache php-apcu php-mbstring php-fileinfo php-xml php-soap php-tokenizer php-zip
    apt -qq install -y php libapache2-mod-php php-mysql php-mysqli php-cli php-common php-curl php-fpm php-gd php-json php-intl php-imap php-bcmath php-opcache php-apcu php-mbstring php-fileinfo php-xml php-snmp php-soap php-tokenizer php-zip > apt-install-php.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Installing package mariadb... "
    apt -qq install -y mariadb-server mariadb-client > apt-install-mariadb.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Installing acme.sh... "
    wget -O -  https://get.acme.sh/ | sh -s email=my@example.com
    echo -e "\e[1;32mdone\e[0m"
fi

############## Configuration ##############
echo -n "Configuring apache2... "
a2enmod php$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
# Enable mod_rewrite for URL rewriting.
echo -e "\e[1;32mdone\e[0m"

echo -n "Configuring php... "
PHP_INI=$(php -i | grep 'Loaded Configuration File' | awk '{print $5}')
sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 256M/' "$PHP_INI"
sed -i 's/^post_max_size = .*/post_max_size = 256M/' "$PHP_INI"
sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
sed -i 's/^max_input_time = .*/max_input_time = 300/' "$PHP_INI"
echo -e "\e[1;32mdone\e[0m"

echo -n "Configuring mariadb... "
# run hardening script
echo -e "\e[1;32mdone\e[0m"

############## VirtualHosts ###############
# wordpress = Installs WP + autoconfiguration (wget + WP-CLI)
# empty = Creates index.html (that contains website name e.g.)
# protected = creates password-protected

vhosts=(
    "medientechnik.org http,https" -> /var/www/medientechnik.org
    "" -> /var/www/medientechnik.org/protected
)


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
