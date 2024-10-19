#!/bin/bash

# ==================================================
#      ----- Variables Definitions -----           #
# ==================================================
if [ -d "/home/dtu_training" ]
then
  USER="dtu_training"
else
  USER="ubuntu"
fi 

export NEWUSER=""
export NEWPWD="performHOT2024"

echo "whoami:" $(whoami)
echo "var-user:" $USER
echo "var-newuser:" $NEWUSER
echo "var-newpwd:" $NEWPWD

# ==================================================
#      ----- Install utilities -----               #
# ==================================================
echo "--Install openjdk-21-jdk openjdk-21-jre-headless openjdk-21-source jq nginx maven python3-pip--"
apt update && apt -qy upgrade
apt -y install openjdk-21-jdk openjdk-21-jre-headless openjdk-21-source jq nginx maven python3-pip
echo "--end--"

# ==================================================
#      ----- Create $NEWUSER user -----            #
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
     proxy_pass http://localhost:8080/;
     proxy_redirect off;
     proxy_set_header Host \$host;
     proxy_set_header Upgrade \$http_upgrade;
     proxy_set_header Connection upgrade;
     proxy_set_header Accept-Encoding gzip;
   }
   location /app {
     proxy_pass http://localhost:8090/calc;
     proxy_redirect off;
   }
   location /instructor {
     proxy_pass http://localhost:53333/;
     proxy_redirect off;
   }
}" >/etc/nginx/sites-available/code-server
ln -s /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/code-server
echo "removing ngnix default"
rm /etc/nginx/sites-enabled/default
service nginx restart
echo "--end--"

# ==================================================
#     ----- Configure reboot service -----         #
# ==================================================
echo "--Config reboot service--"
export HOME=/home/$NEWUSER
cd $HOME
pwd
wget -O $HOME/goreboot https://github.com/Dynatrace-Reinhard-Pilz/otel-hot-day/raw/main/.vscode/13cd536f-59e2-419f-ba06-e70ab98f0af5
chmod +x $HOME/goreboot
echo "[Unit]
Description=Reboots the System triggered by HTTP request

[Service]
User=root
WorkingDirectory=/root
ExecStart=$HOME/goreboot
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/reboot.service
systemctl daemon-reload
systemctl enable reboot.service
systemctl start reboot.service
systemctl status reboot.service
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
sleep 60
if [ -z "$NEWPWD" ];then
  echo "your password can be found in $HOME/.config/code-server/config.yaml"
  cat $HOME/.config/code-server/config.yaml | grep password
else
  sed -i "s/password: .*$/password: $NEWPWD/g" $HOME/.config/code-server/config.yaml
fi
chown -R $NEWUSER:$NEWUSER $HOME/.cache
systemctl restart code-server@$NEWUSER
echo " --installing code-server extensions--"
/usr/lib/code-server/bin/code-server --install-extension vscjava.vscode-java-pack
/usr/lib/code-server/bin/code-server --install-extension vscjava.vscode-java-debug
/usr/lib/code-server/bin/code-server --install-extension vscjava.vscode-maven
/usr/lib/code-server/bin/code-server --install-extension vscjava.vscode-java-dependency
/usr/lib/code-server/bin/code-server --install-extension vscjava.vscode-java-test
/usr/lib/code-server/bin/code-server --install-extension redhat.java
/usr/lib/code-server/bin/code-server --install-extension DotJoshJohnson.xml

mkdir -p /home/$NEWUSER/.local/share/code-server
rm -f /home/$NEWUSER/.local/share/code-server/coder.json
echo "{
  \"query\": {
    \"folder\": \"/home/$NEWUSER/otel-hot-day\"
  },
  \"update\": {
    \"checked\": 1697194765744,
    \"version\": \"4.20.0\"
  }
}" >/home/$NEWUSER/.local/share/code-server/coder.json

mkdir -p /home/$NEWUSER/.local/share/code-server/User
rm -f /home/$NEWUSER/.local/share/code-server/User/settings.json
echo "{
    \"workbench.colorTheme\": \"Visual Studio Dark\",
    \"redhat.telemetry.enabled\": true
}" > /home/$NEWUSER/.local/share/code-server/User/settings.json
echo "--end--"

# ==================================================
#        ----- Setup Collector -----               #
# ==================================================
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.87.0/otelcol_0.87.0_linux_amd64.deb
dpkg -i otelcol_0.87.0_linux_amd64.deb
rm -f otelcol_0.87.0_linux_amd64.deb
rm -f /etc/otelcol/config.yaml
echo "receivers:
  otlp:
    protocols:
      http:
        endpoint: localhost:4318
      grpc:
        endpoint: localhost:4317

processors:
  batch:
  filter:
    metrics:
      exclude:
        match_type: regexp
        metric_names:
          - process.runtime.jvm.system.*

exporters:
  debug:
    verbosity: normal
  otlphttp:
    endpoint: https://########.sprint.dynatracelabs.com/api/v2/otlp
    # --- for standard environments ---
    # endpoint: https://########.live.dynatrace.com/api/v2/otlp
    headers:
      Authorization: "Api-Token dt0c01.########################.################################################################"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug, otlphttp]
    #logs:
    #  receivers: [otlp]
    #  processors: [batch]
    #  exporters: [debug, otlphttp]
    metrics:
      receivers: [otlp]
      processors: [batch, filter]
      exporters: [debug, otlphttp]
  #telemetry:
  #  logs:
  #    level: debug" >/etc/otelcol/config.yaml
chown root:$NEWUSER /etc/otelcol/config.yaml
chmod g+w /etc/otelcol/config.yaml
echo "--end--"

# ==================================================
#            ----- Clone repo -----                #
# ==================================================
echo "--clone repo--"

chown -R $NEWUSER:$NEWUSER $HOME/.cache
chown -R $NEWUSER:$NEWUSER $HOME/.local
#chown -R $NEWUSER:$NEWUSER $HOME/.m2

cd $HOME
pwd
git clone https://github.com/Dynatrace-Reinhard-Pilz/otel-hot-day
chown -R $NEWUSER:$NEWUSER $HOME/otel-hot-day
sudo -H -u $NEWUSER bash -c "whoami;java -version;cd otel-hot-day;pwd;ln -s /etc/otelcol otelcol;pip3 install -r pysvc/requirements.txt"
echo "--end--"

chown -R $NEWUSER:$NEWUSER $HOME/.cache
chown -R $NEWUSER:$NEWUSER $HOME/.local
#chown -R $NEWUSER:$NEWUSER $HOME/.m2

echo "~=~= setup completed ~=~="
