#!/bin/bash

# HINT! Run Script only as "sudo su"!
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1mPlease run as root\033[0m"
    exit 1
fi

# Check if at least 1 argument is passed
if [ $# -lt 1 ]; then
    echo -en "\n\033[1;31mMissing arguments. \033[0m"
    echo "Usage: $0 <path-to-web-directory> [whitelisted-ip1] [whitelisted-ip2] ..."
    exit 1
fi

# Check if given path exists
if [ ! -d "$1" ]; then
    echo -e "\033[1mDirectory doesn't exist!\033[0m"
    exit 1
fi

# CONFIGURATION
AUTH_USER="student"
AUTH_PASS="student"
AUTH_REALM="Secure Area"
TARGET_DIR="$1" # e.g. /var/www/html
HTACCESS_FILE="$TARGET_DIR/.htaccess"
AUTH_FILE="$TARGET_DIR/.htdigest"
shift
WHITELIST_IPS=("$@") # Remaining arguments as array

# Create .htdigest file
HASH=$(printf "%s:%s:%s" "$AUTH_USER" "$AUTH_REALM" "$AUTH_PASS" | md5sum | awk '{print $1}')
echo "$AUTH_USER:$AUTH_REALM:$HASH" > "$AUTH_FILE"

# Start writing .htaccess
cat > "$HTACCESS_FILE" <<EOF
AuthType Digest
AuthName "$AUTH_REALM"
AuthDigestDomain /
AuthUserFile $AUTH_FILE
EOF

# Add conditional access control
if [ "${#WHITELIST_IPS[@]}" -gt 0 ]; then
    cat >> "$HTACCESS_FILE" <<EOF
<RequireAll>
    Require valid-user
    <RequireAny>
EOF

    for ip in "${WHITELIST_IPS[@]}"; do
        echo "        Require ip $ip" >> "$HTACCESS_FILE"
    done

    cat >> "$HTACCESS_FILE" <<EOF
    </RequireAny>
</RequireAll>
EOF
else
    echo "Require valid-user" >> "$HTACCESS_FILE"
fi

# Set permissions
chown www-data:www-data "$AUTH_FILE"
chmod 640 "$AUTH_FILE"

# Reload Apache
systemctl reload apache2

# Output result
echo -e "\e[1;32mDigest authentication enabled for $TARGET_DIR.\e[0m"
echo -e "\e[1;32mUser: $AUTH_USER, Password: $AUTH_PASS\e[0m"

if [ "${#WHITELIST_IPS[@]}" -gt 0 ]; then
    echo -e "\e[1;34mAccess restricted to IP(s)/CIDRs: ${WHITELIST_IPS[*]}\e[0m"
else
    echo -e "\e[1;33mNo IP restrictions applied. Access allowed from any IP.\e[0m"
fi
