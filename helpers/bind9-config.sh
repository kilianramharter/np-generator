#!/bin/bash

#./bind9-config.sh {ALLOW_RECURSION} {DNSSEC_VALIDATION} {NOTIFY} [NAMED_CONF_OPTIONS]

ALLOW_RECURSION="yes" # yes or no
DNSSEC_VALIDATION="no" # yes or no or auto
NOTIFY="yes" # Default notify setting
NAMED_CONF_OPTIONS="/etc/bind/named.conf.options"


update_named_conf_options() {
cat > "$NAMED_CONF_OPTIONS" <<EOF
options {
  directory "/var/cache/bind";
  dnssec-validation ${DNSSEC_VALIDATION};
  recursion ${ALLOW_RECURSION};
  allow-query { any; };
  empty-zones-enable no;
  notify ${NOTIFY};
};
EOF
}

if [ $# -gt 0 ]; then
    ALLOW_RECURSION=$1
    DNSSEC_VALIDATION=$2
    NOTIFY=$3
    if [ $# -gt 3]; then
        NAMED_CONF_OPTIONS=$4
    fi
fi

update_named_conf_options()