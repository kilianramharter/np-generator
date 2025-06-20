#!/bin/bash

MAILNAME="example.com"
MAILTYPE="Internet Site"  # Options: No configuration, Internet Site, Internet with smarthost, Satellite system, Local only

echo "postfix postfix/mailname string $MAILNAME" | debconf-set-selections
echo "postfix postfix/main_mailer_type select $MAILTYPE" | debconf-set-selections

export DEBIAN_FRONTEND=noninteractive

apt install -y postfix