# ============================
# Variable para nombrar los recursos
# ============================
variable "nombre_alumno" {
  description = "Nombre para nombrar los recursos"
  type        = string
  default     = "josems" 
}

# ============================
# CLAVE SSH
# ============================

# Generacion de la clave SSH
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Creacion de la clave SSH en AWS
resource "aws_key_pair" "ssh_key" {
  key_name   = "ssh-mensagl-2025-${var.nombre_alumno}"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Guardar la clave privada localmente
resource "local_file" "private_key_file" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "./.ssh/${path.module}/ssh-mensagl-2025-${var.nombre_alumno}.pem"
}

# Salidas para referencia
output "private_key" {
  value     = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}

output "key_name" {
  value = aws_key_pair.ssh_key.key_name
}

provider "aws" {
  region = "us-east-1"
}


# ============================
# VPC
# ============================

# Crear VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.218.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-vpc"
  }
}

# Crear Subnets públicas
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.218.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-subnet-public1-us-east-1a"
  }
}

# Crear Subnets privadas
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.218.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-subnet-private1-us-east-1a"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.218.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-subnet-private2-us-east-1b"
  }
}

# Crear Gateway de Internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-igw"
  }
}

# Crear tabla de rutas públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-rtb-public"
  }
}

# Asociar subnets públicas a la tabla de rutas pública
resource "aws_route_table_association" "assoc_public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

# Crear IP elastica para NAT Gateway
resource "aws_eip" "nat" {
  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-eip"
  }
}

# Crear NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-nat"
  }
}

# Crear tablas de rutas privadas
resource "aws_route_table" "private1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-rtb-private1-us-east-1a"
  }
}

resource "aws_route_table" "private2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "vpc-mensagl-2025-${var.nombre_alumno}-rtb-private2-us-east-1b"
  }
}

# Asociar subnets privadas a las tablas de rutas privadas
resource "aws_route_table_association" "assoc_private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private1.id
}

resource "aws_route_table_association" "assoc_private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private2.id
}

# ============================
# Grupos de Seguridad
# ============================

# Grupo de seguridad para nginx
resource "aws_security_group" "sg_nginx" {
  name        = "sg_nginx"
  description = "Grupo de seguridad para nginx"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.218.0.0/16"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_nginx"
  }
}

# Grupo de seguridad para el CMS
resource "aws_security_group" "sg_cms" {
  name        = "sg_cms"
  description = "Security group for CMS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_cms"
  }
}

# Grupo de seguridad para MySQL
resource "aws_security_group" "sg_mysql" {
  name        = "sg_mysql"
  description = "Grupo de seguridad para MySQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_mysql"
  }
}
# Grupo de seguridad para NAS
resource "aws_security_group" "sg_nas" {
  name        = "sg_nas"
  description = "Grupo de seguridad para NAS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_nas"
  }
}
# Grupo de seguridad para Mensajería (XMPP Openfire + MySQL)
resource "aws_security_group" "sg_xmpp" {
  name        = "sg_xmpp"
  description = "Grupo de seguirdad para XMPP Openfire"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # XMPP Openfire (puertos predeterminados)
  ingress {
    from_port   = 5222
    to_port     = 5223
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9091
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 7777
    to_port     = 7777
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 5262
    to_port     = 5263
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 5269
    to_port     = 5270
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 7443
    to_port     = 7443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 7070
    to_port     = 7070
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    from_port   = 26001
    to_port     = 27000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    from_port   = 50000
    to_port     = 50010
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5349
    to_port     = 5349
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 5349
    to_port     = 5349
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Tráfico de salida
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_xmpp"
  }
}

# ============================
# Instancias
# ============================

resource "aws_instance" "nginx" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public1.id 
  key_name               = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.sg_nginx.id, aws_security_group.sg_xmpp.id]
  associate_public_ip_address = true
  private_ip             = "10.218.1.10"
  provisioner "file" {
    source      = "../scripts_servicios/nginx.sh"  # ubicacion del script local
    destination = "/home/ubuntu/nginx.sh"          # destino en el equipo remoto
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.public_ip
    }
  }
    provisioner "file" {
    source      = ".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem"  
    destination = "/home/ubuntu/clave.pem"          
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.public_ip
    }
  }
  provisioner "file" {
    source      = "../configuraciones_servicios/nginx/default"  
    destination = "/home/ubuntu/default"          
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.public_ip
    }
  }
  provisioner "file" {
    source      = "../configuraciones_servicios/nginx/nginx.conf"  
    destination = "/home/ubuntu/nginx.conf"          
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.public_ip
    }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host        = self.public_ip
}
        inline = [
      "chmod +x /home/ubuntu/nginx.sh",
      "sudo /home/ubuntu/nginx.sh"
    ]
  }
  tags = {
    Name = "Nginx"
  }
  depends_on = [
    aws_vpc.main,
    aws_subnet.public1,
    aws_security_group.sg_nginx,
    aws_security_group.sg_xmpp,
    aws_key_pair.ssh_key
  ]
}

resource "aws_instance" "nginx_fallback" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public1.id 
  key_name               = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.sg_nginx.id, aws_security_group.sg_xmpp.id]
  associate_public_ip_address = true
  private_ip             = "10.218.1.20"
  
  provisioner "file" {
    source      = "../scripts_servicios/nginxfallback.sh"  
    destination = "/home/ubuntu/nginxfallback.sh"          
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.public_ip
    }
  }

  provisioner "file" {
    source      = ".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem"
    destination = "/home/ubuntu/clave.pem"          
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.public_ip
    }
  }

  provisioner "file" {
    source      = "../configuraciones_servicios/nginx/default"  
    destination = "/home/ubuntu/default"          
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.public_ip
    }
  }

  provisioner "file" {
    source      = "../configuraciones_servicios/nginx/nginx.conf"  
    destination = "/home/ubuntu/nginx.conf"          
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.public_ip
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host        = self.public_ip
    }
    inline = [
      "chmod +x /home/ubuntu/nginxfallback.sh",
      "sudo /home/ubuntu/nginxfallback.sh"
    ]
  }
  tags = {
    Name = "Nginx_Fallback"
  }

  depends_on = [
    aws_vpc.main,
    aws_subnet.public1,
    aws_security_group.sg_nginx,
    aws_security_group.sg_xmpp,
    aws_key_pair.ssh_key,
    aws_instance.nginx
  ]
}


resource "aws_instance" "Wordpress" {
  ami                    = "ami-053b0d53c279acc90"  # Ubuntu Server 22.04 LTS en us-east-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private2.id
  vpc_security_group_ids = [aws_security_group.sg_cms.id]
  key_name               = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = false
  private_ip             = "10.218.3.100"
  provisioner "file" {
    source      = ".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem"  # ubicacion del script local
    destination = "/home/ubuntu/clave.pem"          # destino en el equipo remoto
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
    }
  }
  provisioner "file" {
    source      = "../scripts_servicios/wordpress.sh"  # script local
    destination = "/home/ubuntu/wordpress.sh" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"  
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
  provisioner "file" {
    source      = "../scripts_servicios/wordpress2.sh"  # script local
    destination = "/home/ubuntu/wordpress2.sh" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"  
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
    provisioner "file" {
    source      = "../configuraciones_servicios/wordpress/default-ssl.conf"  # script local
    destination = "/home/ubuntu/default-ssl.conf" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"  
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host        = self.private_ip
      # SSH a través de nginx ya que es el unico con ip publica
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
    }
    inline = [
      "cd ~",
      "sudo chmod +x wordpress.sh",
      "sudo ./wordpress.sh",
      "wait 180",
      "sudo -u www-data wp-cli core config --dbname=wordpress --dbuser=wordpress --dbpass=_Admin123 --dbhost=${aws_db_instance.MySQL_Wordpress.endpoint} --dbprefix=wp --path=/var/www/html",
      "sudo -u www-data wp-cli core install --url='http://nginx-equipofinal217.duckdns.org' --title='Wordpress equipo 4' --admin_user='equipo4' --admin_password='_Admin123' --admin_email='admin@example.com' --path=/var/www/html",
      "sudo -u www-data wp-cli plugin install supportcandy --activate --path='/var/www/html'",
      "sudo -u www-data wp-cli plugin install user-registration --activate --path=/var/www/html",
      "sudo -u www-data wp-cli plugin install wps-hide-login --activate --path='/var/www/html'",
      "sudo -u www-data wp-cli option update wps_hide_login_url equipo4-admin --path='/var/www/html'",
      "sudo chmod +x wordpress2.sh",
      "sudo ./wordpress2.sh"
    ]
}

  tags = {
    Name = "WORDPRESS"
  }
  depends_on = [
    aws_vpc.main,
    aws_subnet.private2,
    aws_security_group.sg_cms,
    aws_instance.nginx,
    aws_key_pair.ssh_key,
    aws_db_instance.MySQL_Wordpress
  ]
}

resource "aws_instance" "Wordpress2" {
  ami                    = "ami-053b0d53c279acc90"  # Ubuntu Server 22.04 LTS en us-east-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private2.id
  vpc_security_group_ids = [aws_security_group.sg_cms.id]
  key_name               = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = false
  private_ip             = "10.218.3.101"
  provisioner "file" {
    source      = ".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem"  # ubicacion del script local
    destination = "/home/ubuntu/clave.pem"          # destino en el equipo remoto
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key = file(".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
    }
  }
  provisioner "file" {
    source      = "../scripts_servicios/wordpress.sh"  # script local
    destination = "/home/ubuntu/wordpress.sh" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"  
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
  provisioner "file" {
    source      = "../scripts_servicios/wordpressbackup.sh"  # script local
    destination = "/home/ubuntu/wordpressbackup.sh" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"  
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
    provisioner "file" {
    source      = "../configuraciones_servicios/wordpress/default-ssl.conf"  # script local
    destination = "/home/ubuntu/default-ssl.conf" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"  
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host        = self.private_ip
      # SSH a través de nginx ya que es el unico con ip publica
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
    }
    inline = [
      "cd ~",
      "sudo chmod +x wordpress.sh",
      "sudo ./wordpress.sh",
      "wait 180",
      "sudo -u www-data wp-cli core config --dbname=wordpress --dbuser=wordpress --dbpass=_Admin123 --dbhost=${aws_db_instance.MySQL_Wordpress.endpoint} --dbprefix=wp --path=/var/www/html",
      "sudo -u www-data wp-cli core install --url='http://nginx-equipofinal217.duckdns.org' --title='Wordpress equipo 4' --admin_user='admin' --admin_password='_Admin123' --admin_email='admin@example.com' --path=/var/www/html",
      "sudo -u www-data wp-cli plugin install supportcandy --activate --path='/var/www/html'",
      "sudo -u www-data wp-cli plugin install user-registration --activate --path='/var/www/html'",
      "sudo -u www-data wp-cli plugin install wps-hide-login --activate --path='/var/www/html'",
      "sudo -u www-data wp-cli option update wps_hide_login_url equipo4-admin --path='/var/www/html'",
      "sudo chmod +x wordpressbackup.sh",
      "sudo ./wordpressbackup.sh"
    ]
}
  tags = {
    Name = "WORDPRESS-2"
  }
  depends_on = [
    aws_vpc.main,
    aws_subnet.private2,
    aws_instance.Wordpress,
    aws_security_group.sg_cms,
    aws_instance.nginx,
    aws_key_pair.ssh_key,
    aws_db_instance.MySQL_Wordpress
  ]
}

# RDS
resource "aws_db_subnet_group" "cms_subnet_group" {
  name       = "mysql_subnet_group"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]
  tags = {
    Name = "mysql-subnet-group"
  }
}
resource "aws_db_instance" "MySQL_Wordpress" {
  allocated_storage    = 10
  storage_type         = "gp2"
  instance_class       = "db.t3.medium"
  engine               = "mysql"
  engine_version       = "8.0"
  username             = "wordpress"
  password             = "_Admin123"
  db_name              = "wordpress"
  publicly_accessible  = false
  multi_az             = false
  availability_zone    = "us-east-1b"  
  db_subnet_group_name = aws_db_subnet_group.cms_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sg_mysql.id]
  skip_final_snapshot  = true 
  backup_retention_period = 30 # mantener los backups por 30 dias
  tags = {
    Name = "MySQL_Wordpress"
  }
  identifier = "mysql-wordpress"
  kms_key_id = aws_kms_key.default.arn   # Aquí se usa la ARN en lugar del ID
  storage_encrypted = true   # Habilitar la encriptación del almacenamiento
  depends_on = [aws_db_subnet_group.cms_subnet_group, aws_kms_key.default]
}


#
# ============================
# Backups programados de RDS 
# ============================
# 
# Da error pero los backups quedan configurados puede que no se necesite
#starting RDS Instance Automated Backups Replication (arn:aws:rds:us-east-1:327540127980:db:mysql-wordpress): operation error RDS: StartDBInstanceAutomatedBackupsReplication, https response error StatusCode: 400, RequestID: 6d871039-3472-4770-b654-004adc8c3c55, api error InvalidParameterValue: Feature is not available in region us-east-1.
# 
# 
# resource "aws_db_instance_automated_backups_replication" "default" {
#   source_db_instance_arn = aws_db_instance.MySQL_Wordpress.arn
#   kms_key_id             = aws_kms_key.default.arn
#   retention_period       = 14
# }


# ============================
# clave KMS para encriptar base de datos de RDS 
# ============================

resource "aws_kms_key" "default" {
  description = "clave de encriptacion para RDS"
  tags = {
    Name = "rds-backup-key-${var.nombre_alumno}"
  }
}

resource "aws_kms_alias" "rds_backup_key_alias" {
  name          = "alias/rds-backup-key-${var.nombre_alumno}"
  target_key_id = aws_kms_key.default.id  
}



# SERVIDOR XMPP OPENFIRE

resource "aws_instance" "XMPP-openfire" {
  ami                    = "ami-053b0d53c279acc90"  # Ubuntu Server 22.04 LTS en us-east-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.sg_xmpp.id]
  key_name               = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = false
  private_ip             = "10.218.2.100"
  provisioner "file" {
    source      = "../scripts_servicios/openfire.sh"  # script local
    destination = "/home/ubuntu/openfire.sh" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host        = self.private_ip
      # SSH a través de nginx ya que es el unico con ip publica
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
    }

    inline = [
      "cd /home/ubuntu/",
      "sudo chmod +x openfire.sh",
      "sudo ./openfire.sh"
    ]
  }
  tags = {
    Name = "OPENFIRE"
  }
  depends_on = [
    aws_vpc.main,
    aws_subnet.private1,
    aws_security_group.sg_xmpp,
    aws_instance.nginx,
    aws_key_pair.ssh_key
  ]
}

#Base de datos maestro openfire 

resource "aws_instance" "XMPP-database-maestro" {
  ami                    = "ami-053b0d53c279acc90"  # Ubuntu Server 22.04 LTS en us-east-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.sg_mysql.id]
  key_name               = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = false
  private_ip             = "10.218.2.200"
  provisioner "file" {
    source      = "../configuraciones_servicios/openfire/openfire.sql"  # script local
    destination = "/home/ubuntu/openfire.sql" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  } 
    provisioner "file" {
    source      = ".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem"  # ubicacion del script local
    destination = "/home/ubuntu/clave.pem"          # destino en el equipo remoto
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
    provisioner "file" {
    source      = "../scripts_servicios/clustersql.sh"  # script local
    destination = "/home/ubuntu/clustersql.sh" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
    user_data = base64encode(templatefile("../scripts_servicios/clustersql.sh", {
    role           = "primary"
  }))

  tags = {
    Name = "Mysql_Openfire_maestro"
  }
  depends_on = [
    aws_vpc.main,
    aws_subnet.private1,
    aws_security_group.sg_mysql,
    aws_instance.nginx,
    aws_key_pair.ssh_key
  ]
}

#Replica de base de datos de openfire

resource "aws_instance" "XMPP-database-replica" {
  ami                    = "ami-053b0d53c279acc90"  # Ubuntu Server 22.04 LTS en us-east-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private1.id
  vpc_security_group_ids = [aws_security_group.sg_mysql.id]
  key_name               = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = false
  private_ip             = "10.218.2.201"
  provisioner "file" {
    source      = ".ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem"  # ubicacion del script local
    destination = "/home/ubuntu/clave.pem"          # destino en el equipo remoto
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
  provisioner "file" {
    source      = "../scripts_servicios/clustersql.sh"  # script local
    destination = "/home/ubuntu/clustersql.sh" # destino
    connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
}
  user_data = base64encode(templatefile("../scripts_servicios/clustersql.sh", {
    role           = "secondary"
  }))
  tags = {
    Name = "Mysql_Openfire_esclavo"
  }
  depends_on = [
    aws_vpc.main,
    aws_subnet.private1,
    aws_security_group.sg_mysql,
    aws_instance.nginx,
    aws_key_pair.ssh_key,
    aws_instance.XMPP-database-maestro
  ]
}

# ============================
# Crear Volúmenes EBS
# ============================

resource "aws_ebs_volume" "volume1" {
  availability_zone = "us-east-1a"
  size              = 20 
  tags = {
    Name = "backup-volume-1-${var.nombre_alumno}"
  }
}

resource "aws_ebs_volume" "volume2" {
  availability_zone = "us-east-1a"
  size              = 20
  tags = {
    Name = "backup-volume-2-${var.nombre_alumno}"
  }
}


# Servidor NAS 
resource "aws_instance" "NAS" {
  ami                    = "ami-053b0d53c279acc90"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private1.id
  key_name               = aws_key_pair.ssh_key.key_name
  vpc_security_group_ids = [aws_security_group.sg_nas.id]
  associate_public_ip_address = false
  private_ip             = "10.218.2.150"
  provisioner "file" {
    source      = "../scripts_servicios/nas.sh"
    destination = "/home/ubuntu/nas.sh"
      connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
    provisioner "file" {
    source      = "./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem"
    destination = "/home/ubuntu/clave.pem"
      connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
  provisioner "file" {
    source      = "../scripts_servicios/backups.sh"
    destination = "/home/ubuntu/backups.sh"
      connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
  }
  provisioner "remote-exec" {
        connection {
      type                = "ssh"
      user                = "ubuntu"
      private_key         = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
      host                = self.private_ip
      bastion_host        = aws_instance.nginx.public_ip
      bastion_user        = "ubuntu"
      bastion_private_key = file("./.ssh/ssh-mensagl-2025-${var.nombre_alumno}.pem")
          }
    inline = [
      "sudo chmod +x /home/ubuntu/nas.sh",
      "sudo /home/ubuntu/nas.sh"
    ]
  }

  tags = {
    Name = "NAS"
  }

  depends_on = [
    aws_vpc.main,
    aws_subnet.private2,
    aws_security_group.sg_nas,
    aws_instance.nginx,
    aws_key_pair.ssh_key,
    aws_ebs_volume.volume1,
    aws_ebs_volume.volume2,
  ]
}


# ============================
# Adjuntar Volúmenes EBS al servidor NAS
# ============================

resource "aws_volume_attachment" "volume1_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.volume1.id
  instance_id = aws_instance.NAS.id 
}

resource "aws_volume_attachment" "volume2_attachment" {
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.volume2.id
  instance_id = aws_instance.NAS.id  
}

