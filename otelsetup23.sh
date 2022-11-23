#!/bin/bash

# ==================================================
#      ----- Variables Definitions -----           #
# ==================================================
USER="ubuntu"
echo "whoami:" $(whoami)
echo "var-user:" $USER
echo "var-newuser:" $NEWUSER
echo "var-newpwd:" $NEWPWD

# ==================================================
#      ----- Install utilities -----           #
# ==================================================
echo "--Install J Query nginx openjdk-17-jdk, maven--"
apt install -y jq nginx openjdk-17-jdk maven python3-pip
echo "--end--"

# ==================================================
#      ----- Create $NEWUSER user -----           #
# ==================================================

if [ -z "$NEWUSER" ];then
  NEWUSER=$USER
  echo "NEWUSER not set, using default $USER as var-newuser:" $NEWUSER
else
  echo "--Creating Workshop User from user($USER) into($NEWUSER)--"
  useradd -s /bin/bash -m -G sudo -p $(openssl passwd -1 $NEWPWD) $NEWUSER
  usermod -aG sudo $NEWUSER
fi
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
#chown -R $NEWUSER:$NEWUSER $HOME/.config
sleep 60
if [ -z "$NEWPWD" ];then
  echo "your password can be found in $HOME/.config/code-server/config.yaml"
  cat $HOME/.config/code-server/config.yaml | grep password
else
  sed -i "s/password: .*$/password: $NEWPWD/g" $HOME/.config/code-server/config.yaml
fi
sed -i 's/8080/9000/' $HOME/.config/code-server/config.yaml
systemctl restart code-server@$NEWUSER
echo "--end--"

# ==================================================
#            ----- Clone repo -----                #
# ==================================================
echo "--clone repo--"
cd $HOME
pwd
#git clone -b 2.17.0 https://github.com/shopizer-ecommerce/shopizer.git
git clone https://github.com/Dynatrace-Reinhard-Pilz/shopizer
chown -R $NEWUSER:$NEWUSER $HOME/shopizer
sudo -H -u $NEWUSER bash -c "whoami;java -verion;pip3 install -r shopizer/pysrvc/requirements.txt;cd shopizer;pwd;mvn clean install"
echo "--end--"

echo "~=~= setup completed ~=~="
