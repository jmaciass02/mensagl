#!/bin/bash
#cambiar dominios
wordpress=nginx-equipo4
openfire=openfire-equipo4
#cambiar token
token=7dc394d7-8282-438d-8358-643ed6b1145d
#cambiar alumno
alumno=jmaciass02

chmod 600 clave.pem

mkdir -p "/home/ubuntu/duckdns/"
cd "/home/ubuntu/duckdns/"

sudo apt update && sudo  DEBIAN_FRONTEND=noninteractive apt install nginx -y

# Crear scripts de duckdns
echo "
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
#Restart Nginx
sudo systemctl stop nginx

while [ ! -e /etc/letsencrypt/live/nginx-equipo4	.duckdns.org ]; do
    
    sudo certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$email" \
        --preferred-challenges dns \
        --authenticator dns-duckdns \
        --dns-duckdns-token "$token" \
        --dns-duckdns-propagation-seconds 60 \
        -d "$wordpress.duckdns.org"

done
while [ ! -e /etc/letsencrypt/live/openfire-equipo4.duckdns.org ]; do
    
    sudo certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$email" \
        --preferred-challenges dns \
        --authenticator dns-duckdns \
        --dns-duckdns-token "$token" \
        --dns-duckdns-propagation-seconds 60 \
        -d "$openfire.duckdns.org"

done
while [ ! -e /etc/letsencrypt/live/openfire-equipo4.duckdns.org-0001 ]; do
    
sudo certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$email" \
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
# Check Nginx status on the remote server
ssh -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_secundario 'sudo systemctl is-active nginx' > remote_status.txt

# Check Nginx status on the local server
local_status=\$(sudo systemctl is-active nginx)

# Read the remote status
if [[ -f remote_status.txt ]]; then
    remote_status=\$(cat remote_status.txt)
fi

# If Nginx is inactive on both servers, start it locally
if [[ \"\$remote_status\" != \"active\" && \"\$local_status\" != \"active\" ]]; then
    sudo systemctl start nginx
else
    exit 1
fi
" > /home/ubuntu/fallback.sh
chmod +x /home/ubuntu/fallback.sh


# Add a cron job to run the fallback script every minute
(crontab -l 2>/dev/null; echo "*/1 * * * * /home/ubuntu/fallback.sh") | crontab -