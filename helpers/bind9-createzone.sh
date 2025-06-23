#!/bin/bash

# Paths
ZONES_DIR="/etc/bind/zones"
NAMED_CONF_LOCAL="/etc/bind/named.conf.local"
NAMED_CONF_OPTIONS="/etc/bind/named.conf.options"

# ---------- Helper Functions ----------

log() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

ensure_dir() {
    [[ ! -d "$1" ]] && mkdir -p "$1"
}

# ---------- Configuration Writers ----------

write_named_conf_options() {
    cat > "$NAMED_CONF_OPTIONS" <<EOF
options {
    directory "/var/cache/bind";
    dnssec-validation no;
    recursion yes;
    allow-query { any; };
    empty-zones-enable no;
    notify yes;
};
EOF
    log "Updated: $NAMED_CONF_OPTIONS"
}

write_zone_file() {
    local zone="$1"
    local nameserver_ip="$2"
    local email="$3"

    local zone_file="$ZONES_DIR/db.${zone}.zone"
    ensure_dir "$ZONES_DIR"

    cat > "$zone_file" <<EOF
\$TTL    86400
@       IN      SOA     ns1.${zone}. ${email}. (
                        $(date +%Y%m%d)01 ; Serial
                        3600       ; Refresh
                        1800       ; Retry
                        1209600    ; Expire
                        86400 )    ; Minimum TTL

        IN      NS      ns1.${zone}.
ns1     IN      A       ${nameserver_ip}
EOF

    log "Created zone file: $zone_file"
}

append_named_conf_local() {
    local zone="$1"
    local role="$2"
    local file="$3"
    local masters="$4"
    local transfer_ip="$5"
    local notify="$6"

    {
        echo
        echo "zone \"${zone}\" {"

        case "$role" in
            SLAVE)
                echo "    type slave;"
                echo "    file \"${file}\";"
                echo "    masters { ${masters}; };"
                ;;
            MASTER)
                echo "    type master;"
                echo "    file \"${file}\";"
                [[ -n "$transfer_ip" ]] && echo "    allow-transfer { ${transfer_ip}; };"
                [[ "$notify" == "yes" && -n "$transfer_ip" ]] && echo "    also-notify { ${transfer_ip}; };"
                ;;
            *)
                echo "    type master;"
                echo "    file \"${file}\";"
                ;;
        esac

        echo "};"
    } >> "$NAMED_CONF_LOCAL"

    log "Appended to named.conf.local: zone $zone"
}

# ---------- JSON Zone Processor ----------

process_zone_from_json() {
    local zone_json="$1"

    local zone role masters_ip transfer_ip recursion dnssec ns_ip email notify
    zone=$(echo "$zone_json" | jq -r '.zone')
    role=$(echo "$zone_json" | jq -r '.remote_role // "MASTER"' | tr '[:lower:]' '[:upper:]')
    masters_ip=$(echo "$zone_json" | jq -r '.masters_ip // empty')
    transfer_ip=$(echo "$zone_json" | jq -r '.transfer_ip // empty')
    recursion=$(echo "$zone_json" | jq -r '.allow_recursion // "yes"')
    dnssec=$(echo "$zone_json" | jq -r '.dnssec_validation // "no"')
    ns_ip=$(echo "$zone_json" | jq -r '.nameserver_ip // empty')
    email=$(echo "$zone_json" | jq -r '.email // "admin@'"$zone"'"')
    notify=$(echo "$zone_json" | jq -r '.notify // "yes"')

    [[ -z "$zone" || -z "$ns_ip" ]] && error "Zone name or nameserver_ip missing in input."

    local zone_file="$ZONES_DIR/db.${zone}.zone"

    [[ "$role" != "SLAVE" ]] && write_zone_file "$zone" "$ns_ip" "$email"
    append_named_conf_local "$zone" "$role" "$zone_file" "$masters_ip" "$transfer_ip" "$notify"
}

# ---------- Main Entry Point ----------

main() {
    if [[ "$1" == *.json && -f "$1" ]]; then
        log "Processing JSON file: $1"
        local json_file="$1"
        local zone_count
        zone_count=$(jq '.zones | length' "$json_file")

        [[ $zone_count -eq 0 ]] && error "No zones found in $json_file"

        # Clear local config before processing
        : > "$NAMED_CONF_LOCAL"

        for i in $(seq 0 $((zone_count - 1))); do
            local zone_json
            zone_json=$(jq -c ".zones[$i]" "$json_file")
            process_zone_from_json "$zone_json"
        done

        write_named_conf_options

    else
        error "Usage: $0 path_to_zones.json"
    fi
}

main "$@"
