#!/bin/bash

# ==================================================
#      ----- Variables Definitions -----           #
# ==================================================
USER="ubuntu"
NEWUSER="dynatrace"
NEWPWD="dynatrace"

echo "whoami:"
echo $(whoami)
echo "uservar:"
echo $USER
echo "newuservar:"
echo $NEWUSER
echo "newpwd:"
echo $NEWPWD

# ==================================================
#      ----- Install utilities -----           #
# ==================================================
echo "--Install J Query nginx default-jdk, maven--"
apt install -y -qq jq nginx default-jdk maven
echo "--end--"

# ==================================================
#      ----- Create $NEWUSER user -----           #
# ==================================================
echo "--Creating Workshop User from user($USER) into($NEWUSER)--"
useradd -s /bin/bash -m -G sudo -p $(openssl passwd -1 $NEWPWD) $NEWUSER
usermod -aG sudo $NEWUSER
echo "--end--"

# ==================================================
#     ----- Setting up magic Domain -----          #
# ==================================================
echo "--Setting up magic domain--"
PUBLIC_IP=$(curl -s ifconfig.me)
PUBLIC_IP_AS_DOM=$(echo $PUBLIC_IP | sed 's~\.~-~g')
export DOMAIN="${PUBLIC_IP_AS_DOM}.nip.io"
echo "Magic Domain: $DOMAIN"
echo "--end--"

# ==================================================
#     ----- Configure reverse proxy -----          #
# ==================================================
echo "--Config reverseproxy--"
echo "server {
   listen 80;
   listen [::]:80;
   server_name $DOMAIN;

   location / {
     proxy_pass http://localhost:9000/;
     proxy_set_header Host \$host;
     proxy_set_header Upgrade \$http_upgrade;
     proxy_set_header Connection upgrade;
     proxy_set_header Accept-Encoding gzip;
   }
}" >/etc/nginx/sites-available/code-server
ln -s /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/code-server
echo "removing ngnix default"
rm /etc/nginx/sites-enabled/default
service nginx restart
echo "--end--"

# ==================================================
#        ----- Setup code server -----             #
# ==================================================
echo "--setup code-server--"
export HOME=/home/$NEWUSER
cd $HOME
pwd
curl -fsSL https://code-server.dev/install.sh | sh
systemctl enable --now code-server@$NEWUSER
chown -R $NEWUSER:$NEWUSER $HOME/.config
sleep 120
sed -i 's/password: .*$/password: $NEWPWD/g' $HOME/.config/code-server/config.yaml
sed -i 's/8080/9000/' $HOME/.config/code-server/config.yaml
systemctl restart code-server@$NEWUSER
echo "--end--"

# ==================================================
#            ----- Clone repo -----                #
# ==================================================
echo "--clone repo--"
cd $HOME
pwd
git clone https://github.com/shopizer-ecommerce/shopizer.git
chown -R $NEWUSER:$NEWUSER $HOME/shopizer
sudo -H -u $NEWUSER bash -c "whoami;echo;./mvnw clean install"
echo "--end--"

echo "~=~= setup completed ~=~="
