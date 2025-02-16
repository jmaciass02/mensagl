#!/bin/bash

# Variables (Make sure to replace with actual values)
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

chmod 600 /home/ubuntu/clave.pem
    # crear el directorio de duckdns
    mkdir -p "/home/ubuntu/duckdns/"
    cd "/home/ubuntu/duckdns/"

    # Instalar paquetes
    sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt install nginx-full coturn python3-pip -y
    sudo snap install --classic certbot
    sudo ln -s /snap/bin/certbot /usr/bin/certbot
    pip install certbot-dns-duckdns
    snap install certbot-dns-duckdns
    
    # parar nginx para evitar que actualize la direccion ip en duckdns mientras el servidor maestro esta activo
    systemctl stop nginx

    # Configurar certbot
    sudo snap set certbot trust-plugin-with-root=ok
    sudo snap connect certbot:plugin certbot-dns-duckdns

# Crear scripts de duckdns
echo "
#!/bin/bash
wordpress=$wordpress
openfire=$openfire
token=$token
alumno=$alumno
# Check Nginx status on the remote server
remote_status=\$(ssh -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_principal \"sudo systemctl is-active nginx\")

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
#!/bin/bash
wordpress=$wordpress
openfire=$openfire
token=$token
alumno=$alumno
# Check Nginx status on the remote server
remote_status=\$(ssh -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_principal \"sudo systemctl is-active nginx\")

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

    # Mover ficheros de configuracion de nginx
    sudo mv /home/ubuntu/default /etc/nginx/sites-available/default
    sudo mv /home/ubuntu/nginx.conf /etc/nginx/nginx.conf

    # Crear directorios para los certificados
    mkdir -p /home/ubuntu/certwordpress
    mkdir -p /home/ubuntu/certopenfire/wildcard

    # SCP los certificados desde el servidor principal
    scp -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_principal:/home/ubuntu/certwordpress/* /home/ubuntu/certwordpress/
    scp -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_principal:/home/ubuntu/certopenfire/* /home/ubuntu/certopenfire/
    scp -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_principal:/home/ubuntu/certopenfire/wildcard/* /home/ubuntu/certopenfire/wildcard/

    # Set correct ownership and permissions
    sudo chown -R ubuntu:ubuntu /home/ubuntu
    sudo chmod -R 770 /home/ubuntu

    # Copiar los certificados a los directorios de letsencrypt
    sudo mkdir -p /etc/letsencrypt/live/$wordpress.duckdns.org
    sudo mkdir -p /etc/letsencrypt/live/$openfire.duckdns.org
    sudo mkdir -p /etc/letsencrypt/live/$openfire.duckdns.org-0001

    sudo cp /home/ubuntu/certwordpress/*.pem /etc/letsencrypt/live/$wordpress.duckdns.org/
    sudo cp /home/ubuntu/certopenfire/*.pem /etc/letsencrypt/live/$openfire.duckdns.org/
    sudo cp /home/ubuntu/certopenfire/wildcard/*.pem /etc/letsencrypt/live/$openfire.duckdns.org-0001/

# añade un cronjob para comprobar si el servicio nginx en el servidor principal esta activo e iniciar el servicio en este si no lo esta

echo "
#!/bin/bash
# Check Nginx status on the remote server
ssh -o StrictHostKeyChecking=no -i /home/ubuntu/clave.pem ubuntu@$nginx_principal 'sudo systemctl is-active nginx' > remote_status.txt

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
sudo systemctl stop nginx
sudo systemctl disable nginx


sudo chown -R www-data:turnserver /etc/letsencrypt/live/
sudo chmod -R 770 /etc/letsencrypt/live/
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
" > /etc/turnserver.conf
sudo systemctl restart coturn  
sudo systemctl enable coturn  