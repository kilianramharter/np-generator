#!/bin/bash

printf "admin:MyRealm:$(openssl passwd -apr1 admin)\n" > .htdigest && echo -e 'AuthType Digest\nAuthName "MyRealm"\nAuthUserFile '$(pwd)'/.htdigest\nRequire valid-user' > .htaccess