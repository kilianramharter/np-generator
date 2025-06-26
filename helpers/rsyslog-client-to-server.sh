#!/bin/bash

# HINT! Run Script only as "sudo su"!
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1mPlease run as root\033[0m"
    exit 1
fi

# Check if 3 arguments are passed
if [ $# -ne 3 ]; then
    echo -e "\033[1;31mUsage: $0 <rsyslog-server-ip> <udp|tcp> <emerg|alert|crit|err|warning|notice|info|debug>\033[0m"
    exit 1
fi

RSYSLOG_SERVER_IP="$1"
RSYSLOG_UDP_TCP="$2"
RSYSLOG_LOG_LEVEL="$3"
RSYSLOG_CONFIG_FILE="/etc/rsyslog.d/90-remote.conf"

# Set a single "@" for UDP or "@@" for TCP
if [[ "$RSYSLOG_UDP_TCP" == "udp" ]]; then
    RSYSLOG_SERVER_IP="@${RSYSLOG_SERVER_IP}"
elif [[ "$RSYSLOG_UDP_TCP" == "tcp" ]]; then
    RSYSLOG_SERVER_IP="@@${RSYSLOG_SERVER_IP}"
else
    echo -e "\033[1;31mInvalid protocol. Use 'udp' or 'tcp'.\033[0m"
    exit 1
fi

# Validate log level
case "$RSYSLOG_LOG_LEVEL" in
    emerg|alert|crit|err|warning|notice|info|debug)
        ;;
    *)
        echo -e "\033[1;31mInvalid log level. Use 'emerg', 'alert', 'crit', 'err', 'warning', 'notice', 'info', or 'debug'.\033[0m"
        exit 1
        ;;
esac

echo -n "Configuring syslog... "
cat >> $RSYSLOG_CONFIG_FILE <<EOF
*.$RSYSLOG_LOG_LEVEL $RSYSLOG_SERVER_IP
EOF
echo -e "\e[1;32mdone\e[0m"