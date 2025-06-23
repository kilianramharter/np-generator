#!/bin/bash

# HINT! Run Script only as "sudo su"!
if [ "$EUID" -ne 0 ]
    then echo -e "\033[1mPlease run as root\033[0m"
    exit 1
fi

# HINT! Check if at least 1 argument is passed
if [ $# -eq 0 ]; then
    echo -en "\n\033[1;31mMissing arguments. \033[0m"
    echo "Usage: $0 <path-to-web-directory> ..."
    exit 1
fi

# HINT! Check if given path exists
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

# Create .htdigest file
printf "%s:%s:%s\n" "$AUTH_USER" "$AUTH_REALM" "$(printf "%s:%s:%s" "$AUTH_USER" "$AUTH_REALM" "$AUTH_PASS" | md5sum | awk '{print $1}')" > "$AUTH_FILE"

# Create .htaccess file
cat > "$HTACCESS_FILE" <<EOF
AuthType Digest
AuthName "$AUTH_REALM"
AuthDigestDomain /
AuthUserFile $AUTH_FILE
Require valid-user
EOF

# Set permissions
chown www-data:www-data "$AUTH_FILE"
chmod 640 "$AUTH_FILE"

systemctl reload apache2

echo -e "\e[1;32mDigest authentication enabled for $TARGET_DIR.\e[0m User: $AUTH_USER, Password: $AUTH_PASS"