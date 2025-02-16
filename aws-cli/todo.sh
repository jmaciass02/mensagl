#!/bin/bash
set -x # para activar el modo debug y tener mas feedback
# Variables
NOMBRE_ALUMNO="josems"
REGION="us-east-1"
AMI_ID="ami-053b0d53c279acc90"
INSTANCE_TYPE="t2.micro"
KEY_NAME="ssh-mensagl-2025-$NOMBRE_ALUMNO"
PRIVATE_KEY_PATH="./.ssh/ssh-mensagl-2025-$NOMBRE_ALUMNO.pem"
RED="217"

# ============================
# Archivo de log
# ============================
LOG_FILE="laboratorio.log"
exec > "$LOG_FILE" 2>&1


# ============================
# Claves SSH
# ============================
PEM_KEY=$(aws ec2 create-key-pair \
    --key-name "${KEY_NAME}" \
    --query "KeyMaterial" \
    --output text)

# Guardar la clave en un archivo
echo "${PEM_KEY}" > "${KEY_NAME}.pem"
chmod 600 "${KEY_NAME}.pem"
echo "Clave SSH creada y almacenada en: ${KEY_NAME}.pem"
mkdir .ssh/
mv $KEY_NAME.pem $PRIVATE_KEY_PATH
# Usar la variable PEM_KEY en otros comandos
echo "Contenido de la clave SSH almacenada en variable:"
echo "${PEM_KEY}"

# ============================
# VPC
# ============================
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.$RED.0.0/16 --region $REGION --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-vpc"

#  ============================
# Subredes
# ============================
SUBNET_PUBLIC1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.$RED.1.0/24 --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_PUBLIC1_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-subnet-public1-${REGION}a"

SUBNET_PRIVATE1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.$RED.2.0/24 --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_PRIVATE1_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-subnet-private1-${REGION}a"

SUBNET_PRIVATE2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.$RED.3.0/24 --availability-zone ${REGION}b --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_PRIVATE2_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-subnet-private2-${REGION}b"

# ============================
# Gateway de internet
# ============================
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-igw"

# ============================
# Tabla de enrutamiento subnet publica
# ============================
RTB_PUBLIC_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PUBLIC_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 create-tags --resources $RTB_PUBLIC_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-rtb-public"
aws ec2 associate-route-table --subnet-id $SUBNET_PUBLIC1_ID --route-table-id $RTB_PUBLIC_ID

# ============================
# IP Elastica para gateway NAT
# ============================
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
aws ec2 create-tags --resources $EIP_ALLOC_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-eip"

# ============================
# Gateway NAT
# ============================
NAT_GW_ID=$(aws ec2 create-nat-gateway --allocation-id $EIP_ALLOC_ID --subnet-id $SUBNET_PUBLIC1_ID --query 'NatGateway.NatGatewayId' --output text)
aws ec2 create-tags --resources $NAT_GW_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-nat"

# ============================
# Tablas de enrutamiento de las redes privadas
# ============================
RTB_PRIVATE1_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PRIVATE1_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID
aws ec2 create-tags --resources $RTB_PRIVATE1_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-rtb-private1-${REGION}a"
aws ec2 associate-route-table --subnet-id $SUBNET_PRIVATE1_ID --route-table-id $RTB_PRIVATE1_ID

RTB_PRIVATE2_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PRIVATE2_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID
aws ec2 create-tags --resources $RTB_PRIVATE2_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-rtb-private2-${REGION}b"
aws ec2 associate-route-table --subnet-id $SUBNET_PRIVATE2_ID --route-table-id $RTB_PRIVATE2_ID

# ============================
# Grupo de seguridad nginx
# ============================
SG_NGINX_ID=$(aws ec2 create-security-group --group-name sg_nginx --description "Grupo de seguridad para nginx" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_NGINX_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_NGINX_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_NGINX_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_NGINX_ID --protocol tcp --port 3306 --cidr 10.$RED.0.0/16
aws ec2 create-tags --resources $SG_NGINX_ID --tags Key=Name,Value="sg_nginx"
# ============================
# Grupo de seguridad CMS
# ============================
SG_CMS_ID=$(aws ec2 create-security-group --group-name sg_cms --description "Security group for CMS cluster" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_CMS_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_CMS_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_CMS_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 create-tags --resources $SG_CMS_ID --tags Key=Name,Value="sg_cms"
# ============================
# Grupo de seguridad MySQL
# ============================
SG_MYSQL_ID=$(aws ec2 create-security-group --group-name sg_mysql --description "Grupo de seguridad para MySQL" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_MYSQL_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_MYSQL_ID --protocol tcp --port 3306 --cidr 0.0.0.0/0
aws ec2 create-tags --resources $SG_MYSQL_ID --tags Key=Name,Value="sg_mysql"
# ============================
# Grupo de seguridad NAS
# ============================
SG_NAS_ID=$(aws ec2 create-security-group --group-name sg_nas --description "Grupo de seguridad para NAS" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_NAS_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 create-tags --resources $SG_NAS_ID --tags Key=Name,Value="sg_nas"
# ============================
# Grupo de seguridad XMPP
# ============================
SG_XMPP_ID=$(aws ec2 create-security-group --group-name sg_xmpp --description "Grupo de seguridad para XMPP Openfire" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 5222-5223 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 9090-9091 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 7777 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 5262-5263 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 5269-5270 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 7443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 7070 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol udp --port 26001-27000 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol udp --port 50000-50010 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol udp --port 5349 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol udp --port 3478 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 5349 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol tcp --port 3478 --cidr 0.0.0.0/0

aws ec2 create-tags --resources $SG_XMPP_ID --tags Key=Name,Value="sg_xmpp"


# ============================
# Nginx principal
# ============================
NGINX_INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --subnet-id $SUBNET_PUBLIC1_ID --security-group-ids $SG_NGINX_ID $SG_XMPP_ID --associate-public-ip-address --private-ip-address 10.$RED.1.10 --query 'Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources $NGINX_INSTANCE_ID --tags Key=Name,Value="Nginx"

# Wait for the instance to be in running state
aws ec2 wait instance-running --instance-ids $NGINX_INSTANCE_ID
sleep 60
# Get the public IP of the instance
NGINX_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $NGINX_INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# Copy scripts and configuration files to the instance
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ../scripts_servicios/nginx.sh ubuntu@$NGINX_PUBLIC_IP:/home/ubuntu/nginx.sh
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no $PRIVATE_KEY_PATH ubuntu@$NGINX_PUBLIC_IP:/home/ubuntu/clave.pem
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ../configuraciones_servicios/nginx/default ubuntu@$NGINX_PUBLIC_IP:/home/ubuntu/default
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ../configuraciones_servicios/nginx/nginx.conf ubuntu@$NGINX_PUBLIC_IP:/home/ubuntu/nginx.conf

# Execute the script on the instance
ssh -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP "chmod +x /home/ubuntu/nginx.sh && sudo /home/ubuntu/nginx.sh"

# ============================
# Nginx secundario
# ============================
NGINX_FALLBACK_INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --subnet-id $SUBNET_PUBLIC1_ID --security-group-ids $SG_NGINX_ID $SG_XMPP_ID --associate-public-ip-address --private-ip-address 10.$RED.1.20 --query 'Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources $NGINX_FALLBACK_INSTANCE_ID --tags Key=Name,Value="Nginx_Fallback"

# Wait for the instance to be in running state
aws ec2 wait instance-running --instance-ids $NGINX_INSTANCE_ID
aws ec2 wait instance-running --instance-ids $NGINX_FALLBACK_INSTANCE_ID
sleep 60
# Get the public IP of the instance
NGINX_FALLBACK_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $NGINX_FALLBACK_INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# Copy scripts and configuration files to the instance
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ../scripts_servicios/nginxfallback.sh ubuntu@$NGINX_FALLBACK_PUBLIC_IP:/home/ubuntu/nginxfallback.sh
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no $PRIVATE_KEY_PATH ubuntu@$NGINX_FALLBACK_PUBLIC_IP:/home/ubuntu/clave.pem
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ../configuraciones_servicios/nginx/default ubuntu@$NGINX_FALLBACK_PUBLIC_IP:/home/ubuntu/default
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ../configuraciones_servicios/nginx/nginx.conf ubuntu@$NGINX_FALLBACK_PUBLIC_IP:/home/ubuntu/nginx.conf
# Execute the script on the instance
ssh -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_FALLBACK_PUBLIC_IP "chmod +x /home/ubuntu/nginxfallback.sh && sudo /home/ubuntu/nginxfallback.sh"




# ============================
# Clave KMS
# ============================
KMS_KEY_ID=$(aws kms create-key --query 'KeyMetadata.KeyId' --output text)
aws kms create-alias --alias-name alias/wordpress-key --target-key-id $KMS_KEY_ID
aws kms enable-key-rotation --key-id $KMS_KEY_ID
aws kms tag-resource --key-id $KMS_KEY_ID --tags TagKey=Name,TagValue="wordpress-key"

# ============================
# Instancia RDS
# ============================
# Crear subnet RD
aws rds create-db-subnet-group \
    --db-subnet-group-name wp-rds-subnet-group \
    --db-subnet-group-description "RDS Subnet Group" \
    --subnet-ids "$SUBNET_PRIVATE1_ID" "$SUBNET_PRIVATE2_ID"

aws rds create-db-instance \
    --db-instance-identifier wordpress-db \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username admin \
    --master-user-password _admin123 \
    --allocated-storage 20 \
    --vpc-security-group-ids $SG_MYSQL_ID \
    --db-subnet-group-name wp-rds-subnet-group \
    --availability-zone ${REGION}a \
    --backup-retention-period 30 \
    --no-multi-az \
    --no-publicly-accessible \
    --storage-type gp2 \
    --tags Key=Name,Value="wordpress-db"
aws rds wait db-instance-available --db-instance-identifier "wordpress-db"

# Recibe el RDS ENDPOINT PARA USARLO MAS ADELANTE
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "wordpress-db" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

echo "RDS Endpoint: $RDS_ENDPOINT"
# ============================
# Wordpress maestro
# ============================
WORDPRESS_INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --subnet-id $SUBNET_PRIVATE2_ID --security-group-ids $SG_CMS_ID --private-ip-address 10.$RED.3.100 --query 'Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources $WORDPRESS_INSTANCE_ID --tags Key=Name,Value="WORDPRESS"

# Wait for the instance to be in running state
aws ec2 wait instance-running --instance-ids $NGINX_INSTANCE_ID
aws ec2 wait instance-running --instance-ids $WORDPRESS_INSTANCE_ID
sleep 60
# Get the private IP of the instance
WORDPRESS_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $WORDPRESS_INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

# Copy scripts and configuration files to the instance via bastion host (Nginx)
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../scripts_servicios/wordpress.sh ubuntu@$WORDPRESS_PRIVATE_IP:/home/ubuntu/wordpress.sh
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../scripts_servicios/wordpress2.sh ubuntu@$WORDPRESS_PRIVATE_IP:/home/ubuntu/wordpress2.sh
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" $PRIVATE_KEY_PATH ubuntu@$WORDPRESS_PRIVATE_IP:/home/ubuntu/clave.pem
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../configuraciones_servicios/wordpress/default-ssl.conf ubuntu@$WORDPRESS_PRIVATE_IP:/home/ubuntu/default-ssl.conf

# Ejecutar comandos para WordPress
ssh -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ubuntu@$WORDPRESS_PRIVATE_IP << 'EOF'
cd ~
sudo chmod +x wordpress.sh
sudo ./wordpress.sh
wait 180
sudo -u www-data wp-cli core config --dbname=wordpress --dbuser=wordpress --dbpass=_Admin123 --dbhost=${RDS_ENDPOINT} --dbprefix=wp --path=/var/www/html
sudo -u www-data wp-cli core install --url='http://wordpress-test217.duckdns.org' --title='Wordpress equipo 4' --admin_user='equipo4' --admin_password='_Admin123' --admin_email='admin@example.com' --path=/var/www/html
sudo -u www-data wp-cli plugin install supportcandy --activate --path='/var/www/html'
sudo -u www-data wp-cli plugin install user-registration --activate --path='/var/www/html'
sudo -u www-data wp-cli plugin install wps-hide-login --activate --path='/var/www/html'
sudo -u www-data wp-cli option update wps_hide_login_url equipo4-admin --path='/var/www/html'
sudo chmod +x wordpress2.sh
sudo ./wordpress2.sh
EOF

# ============================
# Wordpress esclavo
# ============================
WORDPRESS_FALLBACK_INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --subnet-id $SUBNET_PRIVATE2_ID --security-group-ids $SG_CMS_ID --private-ip-address 10.$RED.3.101 --query 'Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources $WORDPRESS_FALLBACK_INSTANCE_ID --tags Key=Name,Value="WORDPRESS-2"

# Wait for the instance to be in running state
aws ec2 wait instance-running --instance-ids $NGINX_INSTANCE_ID
aws ec2 wait instance-running --instance-ids $WORDPRESS_FALLBACK_INSTANCE_ID
sleep 60
# Get the private IP of the instance
WORDPRESS_FALLBACK_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $WORDPRESS_FALLBACK_INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

# Copy scripts and configuration files to the instance via bastion host (Nginx)
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../scripts_servicios/wordpress.sh ubuntu@$WORDPRESS_FALLBACK_PRIVATE_IP:/home/ubuntu/wordpress.sh
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../scripts_servicios/wordpressbackup.sh ubuntu@$WORDPRESS_FALLBACK_PRIVATE_IP:/home/ubuntu/wordpressbackup.sh
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" $PRIVATE_KEY_PATH ubuntu@$WORDPRESS_FALLBACK_PRIVATE_IP:/home/ubuntu/clave.pem
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../configuraciones_servicios/wordpress/default-ssl.conf ubuntu@$WORDPRESS_FALLBACK_PRIVATE_IP:/home/ubuntu/default-ssl.conf

# Execute the script on the instance via bastion host (Nginx)
ssh -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ubuntu@$WORDPRESS_FALLBACK_PRIVATE_IP << 'EOF'
cd ~
sudo chmod +x wordpress.sh
sudo ./wordpress.sh
wait 180
sudo -u www-data wp-cli core config --dbname=wordpress --dbuser=wordpress --dbpass=_Admin123 --dbhost=${aws_db_instance.MySQL_Wordpress.endpoint} --dbprefix=wp --path=/var/www/html
sudo -u www-data wp-cli core install --url='http://wordpress-test217.duckdns.org' --title='Wordpress equipo 4' --admin_user='admin' --admin_password='_Admin123' --admin_email='admin@example.com' --path=/var/www/html
sudo -u www-data wp-cli plugin install supportcandy --activate --path='/var/www/html'
sudo -u www-data wp-cli plugin install user-registration --activate --path='/var/www/html'
sudo -u www-data wp-cli plugin install wps-hide-login --activate --path='/var/www/html'
sudo -u www-data wp-cli option update wps_hide_login_url equipo4-admin --path='/var/www/html'
sudo chmod +x wordpressbackup.sh
sudo ./wordpressbackup.sh
EOF

# ============================
# SERVIDOR XMPP OPENFIRE
# ============================
XMPP_INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --subnet-id $SUBNET_PRIVATE1_ID --security-group-ids $SG_XMPP_ID --private-ip-address 10.$RED.2.100 --query 'Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources $XMPP_INSTANCE_ID --tags Key=Name,Value="OPENFIRE"

# Wait for the instance to be in running state
aws ec2 wait instance-running --instance-ids $NGINX_INSTANCE_ID
aws ec2 wait instance-running --instance-ids $XMPP_INSTANCE_ID
sleep 60
# Get the private IP of the instance
XMPP_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $XMPP_INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

# Copy scripts and configuration files to the instance via bastion host (Nginx)
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../scripts_servicios/openfire.sh ubuntu@$XMPP_PRIVATE_IP:/home/ubuntu/openfire.sh

# Execute the script on the instance via bastion host (Nginx)
ssh -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ubuntu@$XMPP_PRIVATE_IP "chmod +x /home/ubuntu/openfire.sh && sudo /home/ubuntu/openfire.sh"

# ============================
# Base de datos maestro openfire
# ============================
XMPP_DB_MASTER_INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --subnet-id $SUBNET_PRIVATE1_ID --security-group-ids $SG_MYSQL_ID --private-ip-address 10.$RED.2.200 --query 'Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources $XMPP_DB_MASTER_INSTANCE_ID --tags Key=Name,Value="Mysql_Openfire_maestro"

# Wait for the instance to be in running state
aws ec2 wait instance-running --instance-ids $NGINX_INSTANCE_ID
aws ec2 wait instance-running --instance-ids $XMPP_DB_MASTER_INSTANCE_ID
sleep 60
# Get the private IP of the instance
XMPP_DB_MASTER_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $XMPP_DB_MASTER_INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

# Copy scripts and configuration files to the instance via bastion host (Nginx)
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../configuraciones_servicios/openfire/openfire.sql ubuntu@$XMPP_DB_MASTER_PRIVATE_IP:/home/ubuntu/openfire.sql
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../aws-data-user/clustersqlmaster.sh ubuntu@$XMPP_DB_MASTER_PRIVATE_IP:/home/ubuntu/clustersql.sh
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" $PRIVATE_KEY_PATH ubuntu@$XMPP_DB_MASTER_PRIVATE_IP:/home/ubuntu/clave.pem

# Execute the script on the instance via bastion host (Nginx)
ssh -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ubuntu@$XMPP_DB_MASTER_PRIVATE_IP "chmod +x /home/ubuntu/clustersql.sh && sudo /home/ubuntu/clustersql.sh"

# ============================
# Replica de base de datos de openfire
# ============================
XMPP_DB_REPLICA_INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --subnet-id $SUBNET_PRIVATE1_ID --security-group-ids $SG_MYSQL_ID --private-ip-address 10.$RED.2.201 --query 'Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources $XMPP_DB_REPLICA_INSTANCE_ID --tags Key=Name,Value="Mysql_Openfire_esclavo"

# Wait for the instance to be in running state
aws ec2 wait instance-running --instance-ids $NGINX_INSTANCE_ID
aws ec2 wait instance-running --instance-ids $XMPP_DB_REPLICA_INSTANCE_ID
sleep 60
# Get the private IP of the instance
XMPP_DB_REPLICA_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $XMPP_DB_REPLICA_INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

# Copy scripts and configuration files to the instance via bastion host (Nginx)
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../aws-data-user/clustersqlslave.sh ubuntu@$XMPP_DB_REPLICA_PRIVATE_IP:/home/ubuntu/clustersql.sh
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" $PRIVATE_KEY_PATH ubuntu@$XMPP_DB_REPLICA_PRIVATE_IP:/home/ubuntu/clave.pem

# Execute the script on the instance via bastion host (Nginx)
ssh -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ubuntu@$XMPP_DB_REPLICA_PRIVATE_IP "chmod +x /home/ubuntu/clustersql.sh && sudo /home/ubuntu/clustersql.sh"


# ============================
# Crear Volúmenes EBS
# ============================

VOLUME1_ID=$(aws ec2 create-volume --availability-zone ${REGION}a --size 20 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=backup-volume-1-'$NOMBRE_ALUMNO'}]' --query 'VolumeId' --output text)
VOLUME2_ID=$(aws ec2 create-volume --availability-zone ${REGION}a --size 20 --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=backup-volume-2-'$NOMBRE_ALUMNO'}]' --query 'VolumeId' --output text)

# ============================
# Servidor NAS 
# ============================

NAS_INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME --subnet-id $SUBNET_PRIVATE1_ID --security-group-ids $SG_NAS_ID --private-ip-address 10.$RED.2.150 --query 'Instances[0].InstanceId' --output text)
aws ec2 create-tags --resources $NAS_INSTANCE_ID --tags Key=Name,Value="NAS"

# Wait for the instance to be in running state
aws ec2 wait instance-running --instance-ids $NGINX_INSTANCE_ID
aws ec2 wait instance-running --instance-ids $NAS_INSTANCE_ID
sleep 60
# Adjuntar Volúmenes EBS al servidor NAS
aws ec2 attach-volume --device /dev/sdf --volume-id $VOLUME1_ID --instance-id $NAS_INSTANCE_ID
aws ec2 attach-volume --device /dev/sdg --volume-id $VOLUME2_ID --instance-id $NAS_INSTANCE_ID

# Get the private IP of the instance
NAS_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $NAS_INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

# Copy scripts and configuration files to the instance via bastion host (Nginx)
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../scripts_servicios/nas.sh ubuntu@$NAS_PRIVATE_IP:/home/ubuntu/nas.sh
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" $PRIVATE_KEY_PATH ubuntu@$NAS_PRIVATE_IP:/home/ubuntu/clave.pem
scp -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ../scripts_servicios/backups.sh ubuntu@$NAS_PRIVATE_IP:/home/ubuntu/backups.sh

# Execute the script on the instance via bastion host (Nginx)
ssh -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -i $PRIVATE_KEY_PATH -o StrictHostKeyChecking=no ubuntu@$NGINX_PUBLIC_IP" ubuntu@$NAS_PRIVATE_IP "chmod +x /home/ubuntu/nas.sh && sudo /home/ubuntu/nas.sh"
