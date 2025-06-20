#!/bin/bash

# https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-on-ubuntu-20-04
# http://www.postfix.org/STANDARD_CONFIGURATION_README.html
# https://blog.stueber.de/posts/setup-postfix/

DOMAIN="example.com"
HOSTNAME="mail.example.com"
MAILTYPE="Internet Site"  # Options: No configuration, Internet Site, Internet with smarthost, Satellite system, Local only
MAIL_USERS=("apple" "banana" "cherry")

############# INSTALL POSTFIX #############
echo "postfix postfix/mailname string $DOMAIN" | debconf-set-selections
echo "postfix postfix/main_mailer_type select $MAILTYPE" | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive
apt install -y postfix
postconf -e "myhostname=$HOSTNAME"

############# SETUP USERS #############
for item in "${MAIL_USERS[@]}"; do
    useradd -m -s /bin/bash $item
done



# edit /etc/postfix/main.cf (OR USE POSTCONF COMMAND INSTEAD)
    # change: myhostname=mail.example.com ($HOSTNAME)


# postconf -e 'home_mailbox= Maildir/'
# postconf -e 'virtual_alias_maps= hash:/etc/postfix/virtual'
