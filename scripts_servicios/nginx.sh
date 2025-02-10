#!/bin/bash
#preparar dns dinamico
# crear directorio
wordpress=nginxequipo4
openfire=openfire-equipo4
token=7dc394d7-8282-438d-8358-643ed6b1145d
alumno=jmaciass02
mkdir -p "/home/ubuntu/duckdns/"
cd "/home/ubuntu/duckdns/"

sudo apt update && sudo  DEBIAN_FRONTEND=noninteractive apt install nginx -y

# Crear script para actualizar la ip dinamicamente
echo "echo url=\"https://www.duckdns.org/update?domains=$wordpress&token=$token&ip=\" | curl -k -o /home/ubuntu/duckdns/duck.log -K -" > "/home/ubuntu/duckdns/duck.sh"
chmod 700 "/home/ubuntu/duckdns/duck.sh"

echo "echo url=\"https://www.duckdns.org/update?domains=$openfire&token=$token&ip=\" | curl -k -o /home/ubuntu/duckdns/duck.log -K -" > "/home/ubuntu/duckdns/duck2.sh"
chmod 700 "/home/ubuntu/duckdns/duck2.sh"
# Añadir al crontab
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

#clonar git
sudo git clone https://github.com/$alumno/mensagl

#mover configuraciones
sudo mv mensagl/configuraciones_servicios/nginx/default /etc/nginx/sites-available/
sudo mv mensagl/configuraciones_servicios/nginx/nginx.conf /etc/nginx/nginx.conf
#Restart Nginx
sudo systemctl stop nginx

sudo certbot certonly  --non-interactive --agree-tos --email $alumno@educantabria.es --preferred-challenges dns --authenticator dns-duckdns --dns-duckdns-token $token --dns-duckdns-propagation-seconds 120 -d "$wordpress.duckdns.org"
sudo certbot certonly  --non-interactive --agree-tos --email $alumno@educantabria.es --preferred-challenges dns --authenticator dns-duckdns --dns-duckdns-token $token --dns-duckdns-propagation-seconds 120 -d "$wordpress.duckdns.org"
sudo certbot certonly  --non-interactive --agree-tos --email $alumno@educantabria.es --preferred-challenges dns --authenticator dns-duckdns --dns-duckdns-token $token --dns-duckdns-propagation-seconds 120 -d "$openfire.duckdns.org"
sudo certbot certonly  --non-interactive --agree-tos --email $alumno@educantabria.es --preferred-challenges dns --authenticator dns-duckdns --dns-duckdns-token $token --dns-duckdns-propagation-seconds 120 -d "$openfire.duckdns.org"
sudo certbot certonly --non-interactive --agree-tos --email $alumno@educantabria.es --preferred-challenges dns --authenticator dns-duckdns --dns-duckdns-token $token --dns-duckdns-propagation-seconds 120 -d "*.$openfire.duckdns.org"
sudo certbot certonly --non-interactive --agree-tos --email $alumno@educantabria.es --preferred-challenges dns --authenticator dns-duckdns --dns-duckdns-token $token --dns-duckdns-propagation-seconds 120 -d "*.$openfire.duckdns.org"

mkdir /home/ubuntu/certwordpress
mkdir -p /home/ubuntu/certopenfire/wildcard

sudo cp /etc/letsencrypt/live/$wordpress.duckdns.org/* /home/ubuntu/certwordpress/

sudo cp /etc/letsencrypt/live/$openfire.duckdns.org/* /home/ubuntu/certopenfire/

sudo cp /etc/letsencrypt/live/$openfire.duckdns.org-0001/* /home/ubuntu/certopenfire/wildcard/

sudo chown -R ubuntu:ubuntu /home/ubuntu

sudo chown -R ubuntu:ubuntu /home/ubuntu
sudo chmod -R 770 /home/ubuntu

sudo scp -i clave.pem /home/ubuntu/certwordpress/* ubuntu@10.218.3.100:/home/ubuntu/

sudo systemctl start nginx

#Borrar
rm -rf mensagl