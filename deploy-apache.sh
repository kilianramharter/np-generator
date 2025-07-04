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
SERVER_HOSTNAME=WWW

VHOSTS=(
#   "yourdomain.com http|https|both wordpress|basic"
    "medientechnik.org both wordpress"
    "totallysecure.net http basic"
)

# WordPress settings
WP_ADMIN_USER="admin"
WP_ADMIN_PASS="admin"
WP_ADMIN_EMAIL="admin@example.com"

# Certificate metadata variables
SSL_CERT_CN="myserver.local"
SSL_CERT_COUNTRY="AT"
SSL_CERT_STATE="St. Poelten"
SSL_CERT_LOCALITY="St. Poelten"
SSL_CERT_ORG="FH St. Poelten"
SSL_CERT_ORG_UNIT="IT"
SSL_CERT_EMAIL="admin@example.com"
SSL_CERT_PATH="/etc/ssl/certs/apache-san-cert.pem"
SSL_KEY_PATH="/etc/ssl/private/apache-san-key.pem"
SSL_CONF_PATH="/etc/ssl/certs/apache-san-openssl.cnf"
    
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

echo -e "\n============ APACHE2 ==========="
echo -en "VHOSTS:         \t"
for vhost in "${VHOSTS[@]}"; do
  echo -n "$vhost, "
done
echo -e "\n"

echo -en "\n\033[1;31mPRESS ENTER TO CONFIRM...\033[0m"
read
echo ""

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
    apt -qq install -y php libapache2-mod-php php-mysql php-cli php-common php-curl php-fpm php-gd php-json php-intl php-imap php-bcmath php-opcache php-apcu php-mbstring php-fileinfo php-xml php-snmp php-soap php-tokenizer php-zip > apt-install-php.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    echo -n "Installing package mariadb... "
    apt -qq install -y mariadb-server mariadb-client > apt-install-mariadb.log 2>&1
    echo -e "\e[1;32mdone\e[0m"

    # echo -n "Installing acme.sh... "
    # wget -q https://get.acme.sh/ | sh -s email=my@example.com
    # echo -e "\e[1;32mdone\e[0m"

    echo -n "Installing wp-cli... "
    wget -qO /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x /usr/local/bin/wp
    echo -e "\e[1;32mdone\e[0m"
fi

############## Configuration ##############
echo -n "Configuring apache2... "
a2enmod php$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;') > /dev/null
a2enmod rewrite > /dev/null
a2enmod ssl > /dev/null
a2enmod auth_digest > /dev/null
systemctl enable apache2 > /dev/null 2>&1
echo -e "\e[1;32mdone\e[0m"

echo -n "Configuring php... "
PHP_INI=$(php -i | grep 'Loaded Configuration File' | awk '{print $5}')
sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 256M/' "$PHP_INI"
sed -i 's/^post_max_size = .*/post_max_size = 256M/' "$PHP_INI"
sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
sed -i 's/^max_input_time = .*/max_input_time = 300/' "$PHP_INI"
echo -e "\e[1;32mdone\e[0m"

# echo -n "Configuring mariadb... "
# run hardening script
# echo -e "\e[1;32mdone\e[0m"

############## Generate SAN Certificate ##############
# Collect all domains that require HTTPS
HTTPS_DOMAINS=()
for VHOST in "${VHOSTS[@]}"; do
    read -r DOMAIN TYPE MODE <<< "$VHOST"
    if [[ "$TYPE" == "https" || "$TYPE" == "both" ]]; then
        HTTPS_DOMAINS+=("$DOMAIN")
    fi
done

if [[ ${#HTTPS_DOMAINS[@]} -gt 0 ]]; then
    echo -n "Generating self-signed SAN certificate for: ${HTTPS_DOMAINS[*]}... "
    # Create OpenSSL config with SANs
    cat > "$SSL_CONF_PATH" <<EOF
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
x509_extensions    = v3_ca
prompt             = no

[ req_distinguished_name ]
C  = $SSL_CERT_COUNTRY
ST = $SSL_CERT_STATE
L  = $SSL_CERT_LOCALITY
O  = $SSL_CERT_ORG
OU = $SSL_CERT_ORG_UNIT
CN = $SSL_CERT_CN
emailAddress = $SSL_CERT_EMAIL

[ req_ext ]
subjectAltName = @alt_names

[ v3_ca ]
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ alt_names ]
EOF

    i=1
    for d in "${HTTPS_DOMAINS[@]}"; do
        echo "DNS.$i = $d" >> "$SSL_CONF_PATH"
        ((i++))
    done

    # Generate key and cert if not already present
    if [[ ! -f "$SSL_CERT_PATH" || ! -f "$SSL_KEY_PATH" ]]; then
        openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
            -keyout "$SSL_KEY_PATH" \
            -out "$SSL_CERT_PATH" \
            -config "$SSL_CONF_PATH" > /dev/null 2>&1
    fi
    echo -e "\e[1;32mdone\e[0m"
fi

############## VirtualHosts ###############
# wordpress = Installs WP + autoconfiguration (wget + WP-CLI)
# basic = Creates index.html (that contains website name e.g.)

rm -f /etc/apache2/sites-available/*

for VHOST in "${VHOSTS[@]}"; do
    read -r DOMAIN TYPE MODE <<< "$VHOST"
    echo -n "Creating vhost $DOMAIN ($MODE-install)... "

    WEBDIR="/var/www/$DOMAIN"
    PREVPATH=$(pwd)

    mkdir -p $WEBDIR
    chown -R www-data:www-data "$WEBDIR"

    if [[ "$TYPE" == "http" || "$TYPE" == "both" ]]; then
        cat > /etc/apache2/sites-available/$DOMAIN.http.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $WEBDIR
    <Directory $WEBDIR>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF
      a2ensite "$DOMAIN.http.conf" > /dev/null
    fi

    if [[ "$TYPE" == "https" || "$TYPE" == "both" ]]; then
      cat > /etc/apache2/sites-available/$DOMAIN.https.conf <<EOF
<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $WEBDIR
    <Directory $WEBDIR>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
    SSLEngine on
    SSLCertificateFile $SSL_CERT_PATH
    SSLCertificateKeyFile $SSL_KEY_PATH
    <FilesMatch ".(?:cgi|shtml|phtml|php)$">
      SSLOptions +StdEnvVars 
    </FilesMatch>
    <Directory /usr/lib/cgi-bin>
      SSLOptions +StdEnvVars
    </Directory>
</VirtualHost>
EOF
      a2ensite "$DOMAIN.https.conf" > /dev/null
    fi

    if [[ "$MODE" == "wordpress" ]]; then
        # Install WordPress
        WP_TITLE="$(echo $DOMAIN | tr -d '.')"

        # mysql -u root -p"$DB_ROOT_PASS" -e "CREATE DATABASE $WP_TITLE DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        mysql -u root -e "CREATE DATABASE $WP_TITLE DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        mysql -u root -e "CREATE USER '$WP_TITLE'@'localhost' IDENTIFIED BY '$WP_TITLE';"
        mysql -u root -e "GRANT ALL PRIVILEGES ON $WP_TITLE.* TO '$WP_TITLE'@'localhost';"
        mysql -u root -e "FLUSH PRIVILEGES;"

        cd $WEBDIR
        wp core download --allow-root > /dev/null
        wp config create --dbname="$WP_TITLE" --dbuser="$WP_TITLE" --dbpass="$WP_TITLE" --dbhost=localhost --dbprefix="wp_" --skip-check --allow-root > /dev/null
        wp core install --url="http://$DOMAIN" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS" --admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root > /dev/null
        wp option update timezone_string "Europe/Vienna" --allow-root > /dev/null
        wp theme install astra --activate --allow-root > /dev/null
        cd $PREVPATH
    elif [[ "$MODE" == "basic" ]]; then
        # Add Basic settings
        echo "<html><head><title>$DOMAIN</title><style>body {text-align: center; font-family: sans-serif;}</style></head><body><h1>Welcome to $DOMAIN</h1><p>You can edit this file at <strong>$WEBDIR/index.html</strong></p></body></html>" > "$WEBDIR/index.html"
    fi

    echo -e "\e[1;32mdone\e[0m"
done


############### Networking ################
# echo -n "Setting up networking... "

# Run network setup script located in helpers/netplan-config.sh
./helpers/netplan-config.sh "$SERVER_INTERFACE" "$IPV4_SERVER_IP/$IPV4_SERVER_SUBNETMASK" "$IPV4_SERVER_GATEWAY" "$IPV4_SERVER_NAMESERVER" "$IPV6_SERVER_IP/$IPV6_SERVER_SUBNETMASK" "$IPV6_SERVER_GATEWAY" "$IPV6_SERVER_NAMESERVER"

# cat > /etc/netplan/50-cloud-init.yaml <<EOF
# network:
#   version: 2
#   renderer: networkd
#   ethernets:
#     $SERVER_INTERFACE:
#       addresses:
#         - $IPV4_SERVER_IP/$IPV4_SERVER_SUBNETMASK
#         - $IPV6_SERVER_IP/$IPV6_SERVER_SUBNETMASK
#       routes:
#         - to: default
#           via: $IPV4_SERVER_GATEWAY
#         - to: default
#           via: $IPV6_SERVER_GATEWAY
#       nameservers:
#           addresses:
#             - $IPV4_SERVER_NAMESERVER
#             - $IPV6_SERVER_NAMESERVER
# EOF

# netplan apply
# echo -e "\e[1;32mdone\e[0m"

############### Reboot ################
echo "Rebooting system in 5 seconds..."
sleep 5
reboot
