#!/bin/bash

# Manual config
ZONES_DIR="/etc/bind/zones"
CACHE_DIR="/var/cache/bind"
NAMED_CONF_LOCAL="/etc/bind/named.conf.local"

ZONE="medientechnik.org"
REMOTE_ROLE="MASTER" # MASTER or SLAVE OR NONE
MASTERS_IP=""
TRANSFER_IP=""
NAMESERVER_IP=""
EMAIL="postmaster.${ZONE}" # Default email for SOA record

# Include options for bind9
CREATE_OPTIONS="yes" # if yes - bind9-config script will be called
ALLOW_RECURSION="yes" # yes or no
DNSSEC_VALIDATION="no" # yes or no or auto
NOTIFY="yes" # Default notify setting
NAMED_CONF_OPTIONS="/etc/bind/named.conf.options"

# Function to create zone file
create_zone_file() {
    ZONE_FILE="$ZONES_DIR/db.${ZONE}.zone"
    mkdir -p "$ZONES_DIR"

    if [[ "$REMOTE_ROLE" != "SLAVE" ]]; then
        cat > "$ZONE_FILE" <<EOF
\$TTL    86400
@       IN      SOA     ns1.${ZONE}. ${EMAIL}. (
                        2025062301 ; Serial
                        3600       ; Refresh
                        1800       ; Retry
                        1209600    ; Expire
                        86400 )    ; Minimum TTL

        IN      NS      ns1.${ZONE}.
ns1.${ZONE}     IN      A       ${NAMESERVER_IP}
; Example records:
; ns1.${ZONE}     IN      A       180.1.10.2
; www     IN      A       192.0.2.1
; ipv6    IN      AAAA    2001:db8::1
; alias   IN      CNAME   www.${ZONE}.
EOF
        echo "Created zone file: $ZONE_FILE"
    fi
}

# Function to update named.conf.local

update_named_conf_local(){
    echo "" >> "$NAMED_CONF_LOCAL"
    if [[ "$ZONE" == "root" ]]; then
        echo "zone \".\" {" >> "$NAMED_CONF_LOCAL"
    else
        echo "zone \"${ZONE}.\" {" >> "$NAMED_CONF_LOCAL"
    fi
    echo "    type ${REMOTE_ROLE};" >> "$NAMED_CONF_LOCAL"
    if [[ "$REMOTE_ROLE" == "master" || "$REMOTE_ROLE" == "none" ]]; then
        echo "    masters { ${MASTERS_IP}; };" >> "$NAMED_CONF_LOCAL"
        if [[ "$REMOTE_ROLE" == "master" ]]; then
            echo "    allow-transfer { ${TRANSFER_IP}; };" >> "$NAMED_CONF_LOCAL"
        fi
    elif [[ "$REMOTE_ROLE" == "slave" ]]; then
        echo '    file "'${CACHE_DIR}'/db.'${ZONE}'.zone";' >> "$NAMED_CONF_LOCAL"
        echo "    masters { ${MASTERS}; };" >> "$NAMED_CONF_LOCAL"
    fi
    echo "    };" >> "$NAMED_CONF_LOCAL"      
}

showdata() {
    echo "Setting up zone: $ZONE"
    echo "  ZONES_DIR: $ZONES_DIR"
    echo "  CACHE_DIR: $CACHE_DIR"
    echo "  NAMED_CONF_LOCAL: $NAMED_CONF_LOCAL"
    echo "  REMOTE_ROLE: $REMOTE_ROLE"
    echo "  ALLOW_RECURSION: $ALLOW_RECURSION"
    echo "  MASTERS_IP: $MASTERS_IP"
    echo "  TRANSFER_IP: $TRANSFER_IP"
    echo "  NAMESERVER_IP: $NAMESERVER_IP"
    echo "  EMAIL: $EMAIL"
    # Here you can put the actual setup logic
}

verify()

# Main

JSON_FILE="$1"

if [[ $# -eq 1 ]]; then
    echo "Loading configuration from JSON file: $JSON_FILE"
    if ! [[ -f "$JSON_FILE" ]]; then
        echo "File not found: $JSON_FILE"
        exit 1
    fi
    createwithjson
fi

createwithjson() {
    if jq -e '.zones | length > 0' "$JSON_FILE" >/dev/null; then
        echo "JSON file contains zones, proceeding with zone creation..."
    else
        echo "No zones found in JSON file, exiting."
        exit 1
    fi

    zone_count=$(jq '.zones | length' "$JSON_FILE")

    echo "Starting Zone file creation ..."
    for i in $(seq 0 $((zone_count - 1))); do
        ZONE=$(jq -r ".zones[$i].ZONE" "$JSON_FILE")
        REMOTE_ROLE=$(jq -r ".zones[$i].REMOTE_ROLE" "$JSON_FILE")
        MASTERS_IP=$(jq -r ".zones[$i].MASTERS_IP" "$JSON_FILE")
        TRANSFER_IP=$(jq -r ".zones[$i].TRANSFER_IP" "$JSON_FILE")
        NAMESERVER_IP=$(jq -r ".zones[$i].NAMESERVER_IP" "$JSON_FILE")
        EMAIL=$(jq -r ".zones[$i].EMAIL" "$JSON_FILE")
        if jq -e '.options | has("options.NAMED_CONF_LOCAL.")' "$JSON_FILE" >/dev/null; then
            NAMED_CONF_LOCAL=$(jq -r '.options.NAMED_CONF_LOCAL' "$JSON_FILE")
        fi
        if jq -e '.options | has("option")' "$JSON_FILE" >/dev/null; then
            NAMED_CONF_LOCAL=$(jq -r '.options.NAMED_CONF_LOCAL' "$JSON_FILE")

        fi
        create_zone_file
        update_named_conf_local

    done

    if jq -e '.zones[0] | has("option")' "$JSON_FILE" >/dev/null; then
        echo "configuring named.conf.options ..."
        ALLOW_RECURSION=$(jq -r '.zones[0].option.ALLOW_RECURSION' "$JSON_FILE")
        DNSSEC_VALIDATION=$(jq -r '.zones[0].option.DNSSEC_VALIDATION' "$JSON_FILE")
        NOTIFY=$(jq -r '.zones[0].option.NOTIFY' "$JSON_FILE")
        if jq -e '.zones[0] | has("option")' "$JSON_FILE" >/dev/null; then
            NAMED_CONF_OPTIONS=$(jq -r '.zones[0].option.NAMED_CONF_OPTIONS' "$JSON_FILE")
            /bin/bash ./bind9-config.sh $ALLOW_RECURSION $DNSSEC_VALIDATION $NOTIFY $NAMED_CONF_OPTIONS
        else
            /bin/bash ./bind9-config.sh $ALLOW_RECURSION $DNSSEC_VALIDATION $NOTIFY
        fi

        #./bind9-config.sh {ALLOW_RECURSION} {DNSSEC_VALIDATION} {NOTIFY} [NAMED_CONF_OPTIONS]
    fi
}
