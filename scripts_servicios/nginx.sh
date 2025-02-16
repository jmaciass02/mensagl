#!/bin/bash
#cambiar dominios
wordpress=nginx-equipofinal-217
openfire=openfire-equipofinal-217
#cambiar token
token=7dc394d7-8282-438d-8358-643ed6b1145d
#cambiar alumno
alumno=jmaciass02
#cambiar ips de los servidores
nginx_principal="10.217.1.10"
nginx_secundario="10.217.1.20"

chmod 600 clave.pem
mkdir -p "/home/ubuntu/duckdns/"
cd "/home/ubuntu/duckdns/"

sudo apt update && sudo  DEBIAN_FRONTEND=noninteractive apt install nginx -y
echo "url=https://www.duckdns.org/update?domains=$wordpress&token=$token&ip=" | curl -k -o /home/ubuntu/duckdns/duck.log -K -
echo "url=https://www.duckdns.org/update?domains=$openfire&token=$token&ip=" | curl -k -o /home/ubuntu/duckdns/duck.log -K -


# Crear scripts de duckdns
echo "
#!/bin/bash
wordpress=$wordpress
openfire=$openfire
token=$token
alumno=$alumno
# Check Nginx status on the remote server
remote_status=\$(ssh -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_secundario \"sudo systemctl is-active nginx\")

# Check Nginx status on the local server
local_status=\$(sudo systemctl is-active nginx)

# Only execute DuckDNS update if Nginx is running locally and not remotely
if [[ \"\$local_status\" == \"active\" && \"\$remote_status\" != \"active\" ]]; then
    echo url=\"https://www.duckdns.org/update?domains=$wordpress&token=$token&ip=\" | curl -k -o /home/ubuntu/duckdns/duck.log -K -
else
    exit 1
fi
" > /home/ubuntu/duckdns/duck.sh
chmod 700 /home/ubuntu/duckdns/duck.sh

echo "
#!bin/bash
wordpress=$wordpress
openfire=$openfire
token=$token
alumno=$alumno
# Check Nginx status on the remote server
remote_status=\$(ssh -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_secundario \"sudo systemctl is-active nginx\")

# Check Nginx status on the local server
local_status=\$(sudo systemctl is-active nginx)

# Only execute DuckDNS update if Nginx is running locally and not remotely
if [[ \"\$local_status\" == \"active\" && \"\$remote_status\" != \"active\" ]]; then
        echo url=\"https://www.duckdns.org/update?domains=$openfire&token=$token&ip=\" | curl -k -o /home/ubuntu/duckdns/duck.log -K -
        echo url=\"https://www.duckdns.org/update?domains=nginxlocal218&token=$token&ip=10.217.1.10\" | curl -k -o /home/ubuntu/duckdns/duck.log -K -
else
    exit 1
fi
" > /home/ubuntu/duckdns/duck2.sh
chmod 700 /home/ubuntu/duckdns/duck2.sh

    # Add cron jobs for dynamic DNS updates
    (crontab -l 2>/dev/null; echo "*/1 * * * * /home/ubuntu/duckdns/duck.sh >/dev/null 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "*/1 * * * * /home/ubuntu/duckdns/duck2.sh >/dev/null 2>&1") | crontab -

sleep 120

#Instalación de Nginx
sudo apt update && sudo  DEBIAN_FRONTEND=noninteractive apt install nginx-full python3-pip -y
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
pip install certbot-dns-duckdns
snap install certbot-dns-duckdns

sudo snap set certbot trust-plugin-with-root=ok
sudo snap connect certbot:plugin certbot-dns-duckdns

#mover configuraciones
sudo mv /home/ubuntu/default /etc/nginx/sites-available/default
sudo mv /home/ubuntu/nginx.conf /etc/nginx/nginx.conf
#parar Nginx
sudo systemctl stop nginx
while [ ! -e /etc/letsencrypt/live/$wordpress.duckdns.org ]; do
    sudo certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$alumno@educantabria.es" \
        --preferred-challenges dns \
        --authenticator dns-duckdns \
        --dns-duckdns-token "$token" \
        --dns-duckdns-propagation-seconds 60 \
        -d "$wordpress.duckdns.org"
done
while [ ! -e /etc/letsencrypt/live/$openfire.duckdns.org ]; do
    sudo certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$alumno@educantabria.es" \
        --preferred-challenges dns \
        --authenticator dns-duckdns \
        --dns-duckdns-token "$token" \
        --dns-duckdns-propagation-seconds 60 \
        -d "$openfire.duckdns.org"
done
while [ ! -e /etc/letsencrypt/live/$openfire.duckdns.org-0001 ]; do
sudo certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$alumno@educantabria.es" \
        --preferred-challenges dns \
        --authenticator dns-duckdns \
        --dns-duckdns-token "$token" \
        --dns-duckdns-propagation-seconds 60 \
        -d "*.$openfire.duckdns.org"
done
mkdir /home/ubuntu/certwordpress
mkdir -p /home/ubuntu/certopenfire/wildcard

sudo cp /etc/letsencrypt/live/$wordpress.duckdns.org/* /home/ubuntu/certwordpress/
sudo cp /etc/letsencrypt/live/$openfire.duckdns.org/* /home/ubuntu/certopenfire/
sudo cp /etc/letsencrypt/live/$openfire.duckdns.org-0001/* /home/ubuntu/certopenfire/wildcard/

sudo chown -R ubuntu:ubuntu /home/ubuntu
sudo chmod -R 770 /home/ubuntu

sudo systemctl start nginx

echo "
#!/bin/bash
# Comprobar estado de nginx en el servidor remoto
ssh -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_secundario 'sudo systemctl is-active nginx' > remote_status.txt

# Comprobar estado de nginx en el servidor local
local_status=\$(sudo systemctl is-active nginx)

# leer el estado remoto
if [[ -f remote_status.txt ]]; then
    remote_status=\$(cat remote_status.txt)
fi

# si esta inactivo en ambos, lo inicia localmente
if [[ \"\$remote_status\" != \"active\" && \"\$local_status\" != \"active\" ]]; then
    sudo systemctl start nginx
else
    exit 1
fi
" > /home/ubuntu/fallback.sh
chmod +x /home/ubuntu/fallback.sh


# Add a cron job to run the fallback script every minute
(crontab -l 2>/dev/null; echo "*/1 * * * * /home/ubuntu/fallback.sh") | crontab -


#Instalación de COTURN
sudo DEBIAN_FRONTEND=noninteractive apt install coturn -y
sudo chown -R www-data:turnserver /etc/letsencrypt/archive/
sudo chmod -R 770 /etc/letsencrypt/archive/
sudo echo "syslog
realm=llamadas.$openfire.duckdns.org
listening-port=3478
tls-listening-port=5349
relay-threads=0
min-port=50000
max-port=50010
no-tcp
no-tcp-relay
cert="/etc/letsencrypt/live/$openfire.duckdns.org-0001/fullchain.pem"
pkey="/etc/letsencrypt/live/$openfire.duckdns.org-0001/privkey.pem"
use-auth-secret
static-auth-secret=_Admin123
" > /etc/turnserver.conf
sudo systemctl restart coturn  
sudo systemctl enable coturn  