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

echo -e "\e[1;32mNamed configuration options updated successfully.\e[0m"
}

validate_options(){
    echo -n "Validating Bind9 Options... "
case "$ALLOW_RECURSION" in
    yes|no) 
    echo -e "\e Allow recursion  [1;32mvalid\e[0m"
    ;;
    *) 
    echo -e "\e[1;31mfailed\e[0m"
    echo -e "\e[1;31mError:\033[0m Invalid recursion option. Use 'yes' or 'no'." 
    exit 1 ;;
    esac
case "$DNSSEC_VALIDATION" in
    yes|no|auto)
    echo -e "DNSSEC validation [1;32mvalid\e[0m"
    ;;
    *)
    echo -e "\e[1;31mfailed\e[0m"
    echo -e "\e[1;31mError:\033[0m Invalid recursion option. Use 'yes' , 'no' or 'auto'." 
    exit 1 ;;
esac
case "$NOTIFY" in
    yes|no)
    echo -e "Notify on changes [1;32mvalid\e[0m"
    ;;
    *)
    echo -e "\e[1;31mfailed\e[0m"
    echo -e "\e[1;31mError:\033[0m Invalid notify option. Use 'yes' or 'no'." 
    exit 1 ;;
esac
}

if [[ $# -gt 0 ]]; then
    ALLOW_RECURSION=$1
    DNSSEC_VALIDATION=$2
    NOTIFY=$3
    if [[ $# -gt 3 ]]; then
        NAMED_CONF_OPTIONS=$4
    fi
fi
validate_options
update_named_conf_options