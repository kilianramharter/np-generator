#!/bin/bash

# Configuration Variables
PROXY_SITES=(
    # "public_domain backend_ip"
    "example.com 10.0.0.5"
)
SSL_CERT_DAYS=365   # validity of self-signed certs

###############################################
# Script for Nginx Reverse Proxy Setup (SSL)  #
###############################################

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then 
  echo -e "\033[1mPlease run as root\033[0m"
  exit
fi

echo -e "\033[1mThe following settings will be applied:\033[0m"
echo -e "======= NGINX REVERSE PROXY ======="
echo -e "Domains:        \t${PROXY_SITES[*]}"
echo -e "SSL Certs:      \tSelf-signed (${SSL_CERT_DAYS} days)"
echo -e "HTTPS Backend:  \tdisabled (proxy uses HTTP to backend)"
echo -en "\n\033[1;31mPRESS ENTER TO CONFIRM...\033[0m"
read
echo ""

################## Installation ##################
if dpkg -l | grep -q "^ii  nginx "; then
    echo "nginx is already installed, skipping installation..."
else
    echo -n "Installing package nginx... "
    apt -qq install -y nginx > apt-install-nginx.log 2>&1
    echo -e "\e[1;32mdone\e[0m"
fi
# Ensure openssl is available for certificate generation
if ! command -v openssl > /dev/null; then
    echo -n "Installing package openssl... "
    apt -qq install -y openssl >> apt-install-nginx.log 2>&1
    echo -e "\e[1;32mdone\e[0m"
fi

################## Configuration #################
echo -n "Configuring Nginx reverse proxy... "
# Disable default site to avoid conflicts
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

# Loop through each domain/IP pair and set up config
for SITE in "${PROXY_SITES[@]}"; do
    read -r DOMAIN BACKEND <<< "$SITE"
    echo -n "Setting up $DOMAIN -> $BACKEND ... "
    # Generate self-signed SSL certificate and key for the domain
    CERT_FILE="/etc/ssl/certs/${DOMAIN}.crt"
    KEY_FILE="/etc/ssl/private/${DOMAIN}.key"
    s > /dev/null 2>&1

    # Create Nginx site config for the domain (HTTP -> HTTPS and HTTPS proxy)
    CONFIG_PATH="/etc/nginx/sites-available/${DOMAIN}.conf"
    cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate ${CERT_FILE};
    ssl_certificate_key ${KEY_FILE};

    location / {
        proxy_pass http://${BACKEND};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        # Rewrite redirects from backend to correct scheme
        proxy_redirect http:// \$scheme://;
    }
}
EOF

    # Enable the site by creating symlink in sites-enabled
    ln -sf "$CONFIG_PATH" /etc/nginx/sites-enabled/${DOMAIN}.conf
    echo -e "\e[1;32mdone\e[0m"
done

# Test Nginx configuration and restart service
nginx -t > /dev/null 2>&1 && systemctl restart nginx
systemctl enable nginx > /dev/null 2>&1
echo -e "\e[1;32mdone\e[0m"
