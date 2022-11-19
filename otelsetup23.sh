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
#      ----- Create dynatrace user -----           #
# ==================================================
echo "--Creating Workshop User from user($USER) into($NEWUSER)--"
useradd -s /bin/bash -m -G sudo -p $(openssl passwd -1 $NEWPWD) $NEWUSER
usermod -aG sudo dynatrace
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
mkdir -p $HOME/.config/code-server
touch $HOME/.config/code-server/config.yaml
chown dynatrace:dynatrace $HOME/.cache $HOME/.config
systemctl enable --now code-server@$NEWUSER
sleep 120
sed -i 's/password: .*$/password: dynatrace/g' $HOME/.config/code-server/config.yaml
sed -i 's/8080/9000/' $HOME/.config/code-server/config.yaml
systemctl restart code-server@$NEWUSER
echo "--end--"

# ==================================================
#            ----- Clone repo -----                #
# ==================================================
echo "--clone repo--"
cd /home/$NEWUSER
pwd
git clone git://github.com/shopizer-ecommerce/shopizer.git
chown -R dynatrace:dynatrace /home/$NEWUSER/shopizer
cd /home/$NEWUSER/shopizer
pwd
sudo -H -u dynatrace bash -c "whoami;echo;mvn clean install"
echo "--end--"

echo "~=~= setup completed ~=~="