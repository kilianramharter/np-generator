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


createwithjson() {
    if jq -e '.ZONES | length > 0' "$JSON_FILE" >/dev/null; then
        echo "JSON file contains zones, proceeding with zone creation..."
    else
        echo "No zones found in JSON file, exiting."
        exit 1
    fi

    zone_count=$(jq '.ZONES | length' "$JSON_FILE")

    echo "Starting Zone file creation ..."
    for i in $(seq 0 $((zone_count - 1))); do
        ZONE=$(jq -r ".ZONES[$i].ZONE" "$JSON_FILE")
        REMOTE_ROLE=$(jq -r ".ZONES[$i].REMOTE_ROLE" "$JSON_FILE")
        MASTERS_IP=$(jq -r ".ZONES[$i].MASTERS_IP" "$JSON_FILE")
        TRANSFER_IP=$(jq -r ".ZONES[$i].TRANSFER_IP" "$JSON_FILE")
        NAMESERVER_IP=$(jq -r ".ZONES[$i].NAMESERVER_IP" "$JSON_FILE")
        EMAIL=$(jq -r ".ZONES[$i].EMAIL" "$JSON_FILE")
        if jq -e '. | has("NAMED_CONF_LOCAL")' "$JSON_FILE" >/dev/null; then
            NAMED_CONF_LOCAL=$(jq -r '.NAMED_CONF_LOCAL' "$JSON_FILE")
        fi
        if jq -e '. | has("ZONE_DIR")' "$JSON_FILE" >/dev/null; then
            ZONES_DIR=$(jq -r '.ZONE_DIR' "$JSON_FILE")
        fi
        if jq -e '. | has("CACHE_DIR")' "$JSON_FILE" >/dev/null; then
            CACHE_DIR=$(jq -r '.CACHE_DIR' "$JSON_FILE")
        fi
        create_zone_file
        update_named_conf_local

    done

    if jq -e '. | has("OPTIONS")' "$JSON_FILE" >/dev/null; then
        echo "configuring named.conf.options ..."
        ALLOW_RECURSION=$(jq -r '.OPTIONS.ALLOW_RECURSION' "$JSON_FILE")
        DNSSEC_VALIDATION=$(jq -r '.OPTIONS.DNSSEC_VALIDATION' "$JSON_FILE")
        NOTIFY=$(jq -r '.OPTIONS.NOTIFY' "$JSON_FILE")
        if jq -e '.OPTIONS | has("FILE")' "$JSON_FILE" >/dev/null; then
            NAMED_CONF_OPTIONS=$(jq -r '.OPTIONS.FILE' "$JSON_FILE")
            /bin/bash ./bind9-config.sh $ALLOW_RECURSION $DNSSEC_VALIDATION $NOTIFY $NAMED_CONF_OPTIONS
        else
            /bin/bash ./bind9-config.sh $ALLOW_RECURSION $DNSSEC_VALIDATION $NOTIFY
        fi

        #./bind9-config.sh {ALLOW_RECURSION} {DNSSEC_VALIDATION} {NOTIFY} [NAMED_CONF_OPTIONS]
    fi
}

# Main



if [[ $# -eq 1 ]]; then
    JSON_FILE=$1
    echo "Loading configuration from JSON file: $JSON_FILE"
    if ! [[ -f "$JSON_FILE" ]]; then
        echo "File not found: $JSON_FILE"
        exit 1
    fi
    createwithjson
elif [[ $# -eq 0 ]]; then
    echo "Creating zone with default settings..."
    create_zone_file
    update_named_conf_local
    if [[ "$CREATE_OPTIONS" == "yes" ]]; then
        echo "Configuring named.conf.options ..."
        /bin/bash ./bind9-config.sh $ALLOW_RECURSION $DNSSEC_VALIDATION $NOTIFY $NAMED_CONF_OPTIONS
    fi
fi


