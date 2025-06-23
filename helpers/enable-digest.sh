#!/bin/bash

# CONFIGURATION
AUTH_USER="student"
AUTH_PASS="student"
AUTH_REALM="Secure Area"
TARGET_DIR="/var/www/secure-site"  # Adjust this!
HTACCESS_FILE="$TARGET_DIR/.htaccess"
AUTH_FILE="$TARGET_DIR/.htdigest"

# Create .htdigest file (non-interactive)
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

# Reload Apache
systemctl reload apache2

echo "✅ Digest authentication setup complete for $TARGET_DIR"
