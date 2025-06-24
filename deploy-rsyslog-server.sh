#!/bin/bash

# Configuration Variables
RSYSLOG_PROTOCOL="both"    # Options: "tcp", "udp", "both"
LOG_DIR_BASE="/var/log/hosts"

###########################################
# Script for Ubuntu Rsyslog Configuration #
# (Centralized Logging Server Setup)      #
###########################################

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then 
  echo -e "\033[1mPlease run as root\033[0m"
  exit
fi

echo -e "\033[1mThe following settings will be applied:\033[0m"
echo -e "============ RSYSLOG ============"
echo -e "Protocols:       \t${RSYSLOG_PROTOCOL^^}"   # e.g. BOTH / TCP / UDP
echo -e "Log Directory:   \t${LOG_DIR_BASE}/<HOSTNAME>"
echo -e "Severity Filter: \tErrors and above only"
echo -e "Firewall (UFW):  \tdisabled"
echo -en "\n\033[1;31mPRESS ENTER TO CONFIRM...\033[0m"
read  # Wait for user confirmation
echo ""

################## Installation ##################
if dpkg -l | grep -q "^ii  rsyslog "; then
    echo "rsyslog is already installed, skipping installation..."
else
    echo -n "Installing package rsyslog... "
    apt -qq install -y rsyslog > apt-install-rsyslog.log 2>&1
    echo -e "\e[1;32mdone\e[0m"
fi

################## Configuration #################
echo -n "Configuring rsyslog for remote logging... "
# Create log directory base (if not exists) for remote hosts
mkdir -p "$LOG_DIR_BASE"
chmod 755 "$LOG_DIR_BASE"
chown syslog:adm "$LOG_DIR_BASE"

# Prepare rsyslog config to enable UDP/TCP reception and template
CONFIG_FILE="/etc/rsyslog.d/90-remote.conf"
rm -f "$CONFIG_FILE"
{
    # Enable UDP/TCP reception based on selected protocol(s)
    if [[ "$RSYSLOG_PROTOCOL" == "udp" || "$RSYSLOG_PROTOCOL" == "both" ]]; then
        echo 'module(load="imudp")'
        echo 'input(type="imudp" port="514")'   # UDP port 514:contentReference[oaicite:6]{index=6}
    fi
    if [[ "$RSYSLOG_PROTOCOL" == "tcp" || "$RSYSLOG_PROTOCOL" == "both" ]]; then
        echo 'module(load="imtcp")'
        echo 'input(type="imtcp" port="514")'   # TCP port 514:contentReference[oaicite:7]{index=7}
    fi
    # Template for remote host logs (directory per host)
    echo "\$template RemoteLogs,\"${LOG_DIR_BASE}/%HOSTNAME%/%PROGRAMNAME%.log\""
    # Log only messages with priority error or higher from any host
    echo "*.err;*.crit;*.alert;*.emerg ?RemoteLogs"
    # Stop processing these messages in default rules to avoid duplication
    echo "& ~"
} > "$CONFIG_FILE"

# Restart and enable rsyslog service to apply changes
systemctl restart rsyslog
systemctl enable rsyslog > /dev/null 2>&1
echo -e "\e[1;32mdone\e[0m"

################### Firewall #####################
if command -v ufw > /dev/null; then
    if ufw status | grep -qw "active"; then
        echo -n "Disabling UFW firewall... "
        ufw disable > /dev/null 2>&1
        echo -e "\e[1;32mdone\e[0m"
    fi
fi

echo -e "\033[1;32mRsyslog server setup is complete.\033[0m"
