#!/bin/bash

# Variables
NOMBRE_ALUMNO="josems"
REGION="us-east-1"
RED="217"
# Create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.$RED.0.0/16 --region $REGION --query 'Vpc.VpcId' --output text)

aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-vpc"

# Create Subnets
SUBNET_PUBLIC1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.$RED.1.0/24 --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_PUBLIC1_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-subnet-public1-${REGION}a"

SUBNET_PRIVATE1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.$RED.2.0/24 --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_PRIVATE1_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-subnet-private1-${REGION}a"

SUBNET_PRIVATE2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.$RED.3.0/24 --availability-zone ${REGION}b --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources $SUBNET_PRIVATE2_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-subnet-private2-${REGION}b"

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-igw"

# Create Route Table for Public Subnet
RTB_PUBLIC_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PUBLIC_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 create-tags --resources $RTB_PUBLIC_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-rtb-public"
aws ec2 associate-route-table --subnet-id $SUBNET_PUBLIC1_ID --route-table-id $RTB_PUBLIC_ID

# Create Elastic IP for NAT Gateway
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
aws ec2 create-tags --resources $EIP_ALLOC_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-eip"

# Create NAT Gateway
NAT_GW_ID=$(aws ec2 create-nat-gateway --allocation-id $EIP_ALLOC_ID --subnet-id $SUBNET_PUBLIC1_ID --query 'NatGateway.NatGatewayId' --output text)
aws ec2 create-tags --resources $NAT_GW_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-nat"

# Create Route Tables for Private Subnets
RTB_PRIVATE1_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PRIVATE1_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID
aws ec2 create-tags --resources $RTB_PRIVATE1_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-rtb-private1-${REGION}a"
aws ec2 associate-route-table --subnet-id $SUBNET_PRIVATE1_ID --route-table-id $RTB_PRIVATE1_ID

RTB_PRIVATE2_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $RTB_PRIVATE2_ID --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW_ID
aws ec2 create-tags --resources $RTB_PRIVATE2_ID --tags Key=Name,Value="vpc-mensagl-2025-$NOMBRE_ALUMNO-rtb-private2-${REGION}b"
aws ec2 associate-route-table --subnet-id $SUBNET_PRIVATE2_ID --route-table-id $RTB_PRIVATE2_ID

# Create Security Groups
SG_NGINX_ID=$(aws ec2 create-security-group --group-name sg_nginx --description "Grupo de seguridad para nginx" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_NGINX_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_NGINX_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_NGINX_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_NGINX_ID --protocol tcp --port 3306 --cidr 10.$RED.0.0/16
aws ec2 create-tags --resources $SG_NGINX_ID --tags Key=Name,Value="sg_nginx"

SG_CMS_ID=$(aws ec2 create-security-group --group-name sg_cms --description "Security group for CMS cluster" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_CMS_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_CMS_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_CMS_ID --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 create-tags --resources $SG_CMS_ID --tags Key=Name,Value="sg_cms"

SG_MYSQL_ID=$(aws ec2 create-security-group --group-name sg_mysql --description "Grupo de seguridad para MySQL" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_MYSQL_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_MYSQL_ID --protocol tcp --port 3306 --cidr 0.0.0.0/0
aws ec2 create-tags --resources $SG_MYSQL_ID --tags Key=Name,Value="sg_mysql"

SG_NAS_ID=$(aws ec2 create-security-group --group-name sg_nas --description "Grupo de seguridad para NAS" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_NAS_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 create-tags --resources $SG_NAS_ID --tags Key=Name,Value="sg_nas"

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
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol udp --port 50000-55000 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_XMPP_ID --protocol udp --port 9999 --cidr 0.0.0.0/0
aws ec2 create-tags --resources $SG_XMPP_ID --tags Key=Name,Value="sg_xmpp"