#!/bin/bash

ZONES_DIR="/etc/bind/zones"
CACHE_DIR="/var/cache/bind"
NAMED_CONF_LOCAL="/etc/bind/named.conf.local"
NAMED_CONF_OPTIONS="/etc/bind/named.conf.options"
ZONE="medientechnik.org"
REMOTE_ROLE="MASTER" # MASTER or SLAVE OR NONE
ALLOW_RECURSION="yes" # yes or no
MASTERS_IP=""
TRANSFER_IP=""
DNSSEC_VALIDATION="no" # yes or no or auto
NAMESERVER_IP=""
EMAIL="admin@${ZONE}" # Default email for SOA record
NOTIFY="yes" # Default notify setting

# Function to ask for input if not provided
 
ask_input() {
    read -p "Zone name (e.g., example.com or root or none: " ZONE
    read -p "What is the Domain Role (master/slave/none): " REMOTE_ROLE
    if [[ "$REMOTE_ROLE" == "SLAVE" ]]; then
        read -p "Master IP for zone transfers: " MASTERS_IP
    elif [[ "$REMOTE_ROLE" == "MASTER" ]]; then
        read -p "Allow Transfer from IP for this zone: " TRANSFER_IP
    fi
    read -p "Allow recursion? (yes/no): " ALLOW_RECURSION
    read -p "DNSSEC VALIDATION? (yes/no/auto): " DNSSEC_VALIDATION
    read -p "What is the IP of the nameserver for $ZONE?: " NAMESERVER_IP
    read -p "What is the postmaster mail?: " EMAIL
    read -p "Notify on changes? (yes/no): " NOTIFY
}

# # Function to parse JSON input file
# parse_json() {
#     ZONE=$(jq -r '.zone' "$1")
#     IS_REMOTE=$(jq -r '.is_remote // "no"' "$1")
#     MASTERS=$(jq -r '.masters // empty' "$1")
#     ALLOW_RECURSION=$(jq -r '.allow_recursion // "no"' "$1")
# }

# Function to update named.conf.options

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
old_update_named_conf_local() {
    if [[ "$REMOTE_ROLE" == "SLAVE" ]]; then
        cat >> "$NAMED_CONF_LOCAL" <<EOF

zone "${ZONE}" {
    type slave;
    file "${ZONES_DIR}/db.${ZONE}.zone";
    masters { ${MASTERS}; };
};
EOF
    elif [[ "$REMOTE_ROLE" == "MASTER" ]]; then
        cat >> "$NAMED_CONF_LOCAL" <<EOF

zone "${ZONE}" {
    type master;
    file "${ZONES_DIR}/db.${ZONE}.zone";
    allow-transfer { ${TRANSFER_IP}; };
EOF
        if [[ "$NOTIFY" == "yes" ]]; then
            echo "  also-notify { ${TRANSFER_IP}; };" >> "$NAMED_CONF_LOCAL"
        fi
        echo "};" >> "$NAMED_CONF_LOCAL"

    else
        cat >> "$NAMED_CONF_LOCAL" <<EOF
zone "${ZONE}" {
    type master;
    file "${ZONES_DIR}/db.${ZONE}.zone";
};
EOF
    fi
    echo "Updated $NAMED_CONF_LOCAL"
}

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
# Main
if [[ "$1" == *.json && -f "$1" ]]; then
    parse_json "$1"
elif [[ -n "$1" ]]; then
    ZONE="$1"
    IS_REMOTE="${2:-no}"
    MASTERS="${3:-}"
    ALLOW_RECURSION="${4:-no}"
else
    ask_input
fi

if [[ "$ZONE" != "none"  ]]; then
    create_zone_file
    update_named_conf_local
fi
update_named_conf_options
