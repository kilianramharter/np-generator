#!/bin/bash

DOMAIN="example.com"
HOSTNAME="mail.example.com"
MAILTYPE="Internet Site"  # Options: No configuration, Internet Site, Internet with smarthost, Satellite system, Local only

echo "postfix postfix/mailname string $DOMAIN" | debconf-set-selections
echo "postfix postfix/main_mailer_type select $MAILTYPE" | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive

apt install -y postfix

# edit /etc/postfix/main.cf (OR USE POSTCONF COMMAND INSTEAD)
    # change: myhostname=mail.example.com ($HOSTNAME)


# postconf -e 'home_mailbox= Maildir/'
# postconf -e 'virtual_alias_maps= hash:/etc/postfix/virtual'
