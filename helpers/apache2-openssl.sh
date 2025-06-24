#!/bin/bash

# Configuration parameters - customize these values
COUNTRY="AT"                  # 2 letter country code
STATE="#Lower Austria"            # State or province
LOCALITY="Sankt Poelten"      # City
ORGANIZATION="FH St. Poelten"     # Company name
ORGANIZATIONAL_UNIT="itsec"      # Department
COMMON_NAME="medientechnik.org"       # Domain name or IP
EMAIL="admin@example.org"     # Admin email
DAYS_VALID=365                # Certificate validity in days
KEY_LENGTH=4096               # RSA key length (2048 or 4096)

# File locations - standard Debian/Ubuntu Apache paths
CERT_FILE="/etc/ssl/certs/ssl-cert-snakeoil.pem"
KEY_FILE="/etc/ssl/private/ssl-cert-snakeoil.key"

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root. Use sudo." >&2
    exit 1
fi

# Check if OpenSSL is installed
if ! command -v openssl &> /dev/null; then
    echo "ERROR: OpenSSL is not installed. Please install it first." >&2
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Generating self-signed certificate with the following parameters:"
echo "Country: $COUNTRY"
echo "State: $STATE"
echo "Locality: $LOCALITY"
echo "Organization: $ORGANIZATION"
echo "Organizational Unit: $ORGANIZATIONAL_UNIT"
echo "Common Name: $COMMON_NAME"
echo "Email: $EMAIL"
echo "Validity: $DAYS_VALID days"
echo "Key Length: $KEY_LENGTH bits"

# Generate private key and certificate
openssl req -x509 -nodes -days "$DAYS_VALID" -newkey "rsa:$KEY_LENGTH" \
    -keyout "$TEMP_DIR/temp.key" -out "$TEMP_DIR/temp.pem" \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"

# Verify the files were created
if [ ! -f "$TEMP_DIR/temp.key" ] || [ ! -f "$TEMP_DIR/temp.pem" ]; then
    echo "ERROR: Failed to generate certificate files." >&2
    exit 1
fi

# Create target directories if they don't exist
mkdir -p "$(dirname "$CERT_FILE")"
mkdir -p "$(dirname "$KEY_FILE")"

# Move files to their final locations (with force overwrite)
echo "Installing certificate files..."
mv -f "$TEMP_DIR/temp.pem" "$CERT_FILE"
mv -f "$TEMP_DIR/temp.key" "$KEY_FILE"

# Set proper permissions
chmod 644 "$CERT_FILE"
chmod 640 "$KEY_FILE"
chown root:ssl-cert "$KEY_FILE"

echo "Successfully created and installed:"
echo "Certificate: $CERT_FILE"
echo "Private Key: $KEY_FILE"