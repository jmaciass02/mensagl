#!/bin/bash

# Variables from Terraform
role="secondary"
primary_ip="10.218.2.200"
secondary_ip="10.218.2.201"
db_user="openfire"
db_password="_Admin123"
db_name="openfire"
ssh_key_path="/home/ubuntu/clave.pem"

# 1. Configure SSH Key
chmod 600 $ssh_key_path

# 2. Install MySQL if not installed
if ! dpkg -l | grep -q mysql-server; then
    apt update && DEBIAN_FRONTEND=noninteractive apt install -y mysql-server mysql-client
    
fi


server_id=1
# 3. Configure MySQL
if [ "$role" = "secondary" ]; then
    server_id=2
fi

tee /etc/mysql/mysql.conf.d/replication.cnf > /dev/null <<EOF
[mysqld]
bind-address = 0.0.0.0
server-id =$server_id
binlog_do_db=openfire
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
relay-log = /var/log/mysql/mysql-relay-bin
auto-increment-increment=2
auto-increment-offset=$server_id
EOF

# 4. Restart MySQL Service
systemctl restart mysql
systemctl enable mysql

# 5. Basic Security Setup
mysql -u root -p_Admin123 <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '_Admin123';
CREATE DATABASE IF NOT EXISTS $db_name;
FLUSH PRIVILEGES;
EOF

# 6. Role-Specific Configuration
if [ "$role" = "primary" ]; then
    mysql -u root -p_Admin123 <<EOF
    CREATE USER 'openfire'@'%' IDENTIFIED WITH mysql_native_password BY '_Admin123';
    GRANT ALL PRIVILEGES ON $db_name.* TO 'openfire'@'%';
    GRANT REPLICATION SLAVE ON *.* TO 'openfire'@'%';
    GRANT REPLICATION CLIENT ON *.* TO 'openfire'@'%';
    FLUSH PRIVILEGES;
EOF
    mysql -u root -p'_Admin123' -e "SHOW MASTER STATUS" | awk 'NR==2 {print $1, $2}' > /tmp/master_status.txt

elif [ "$role" = "secondary" ]; then
    # Wait for primary to be ready
    echo "Waiting for primary MySQL server to be ready..."
    timeout 300 bash -c "until nc -z $primary_ip 3306; do sleep 10; done"
    # Copy master status from primary
    scp -o StrictHostKeyChecking=no -i $ssh_key_path ubuntu@$primary_ip:/tmp/master_status.txt /tmp/

    MASTER_STATUS=$(cat /tmp/master_status.txt)
    binlog_file=$(echo "$MASTER_STATUS" | awk '{print $1}')
    binlog_pos=$(echo "$MASTER_STATUS" | awk '{print $2}')
    mysql -u root -p_Admin123 <<EOF
    CREATE USER 'openfire'@'%' IDENTIFIED WITH mysql_native_password BY '_Admin123';
    GRANT ALL PRIVILEGES ON $db_name.* TO 'openfire'@'%';
    GRANT REPLICATION SLAVE ON *.* TO 'openfire'@'%';
    GRANT REPLICATION CLIENT ON *.* TO 'openfire'@'%';
    FLUSH PRIVILEGES;
EOF
    mysql -u root -p_Admin123 <<EOF 
    CHANGE MASTER TO
    MASTER_HOST="$primary_ip",
    MASTER_USER='openfire',
    MASTER_PASSWORD='_Admin123',
    MASTER_LOG_FILE="$binlog_file",
    MASTER_LOG_POS=$binlog_pos;
    START SLAVE;
EOF
fi

if [ "$role" = "primary" ]; then
    # Wait for secondary to be ready
    echo "Waiting for secondary MySQL server to be ready..."
    timeout 300 bash -c "until nc -z $secondary_ip 3306; do sleep 10; done"

    # Fetch secondary's master status (needed for replication)
    scp -o StrictHostKeyChecking=no -i $ssh_key_path ubuntu@$secondary_ip:/tmp/master_status.txt /tmp/

    MASTER_STATUS=$(cat /tmp/master_status.txt)
    binlog_file=$(echo "$MASTER_STATUS" | awk '{print $1}')
    binlog_pos=$(echo "$MASTER_STATUS" | awk '{print $2}')

    # Set up the primary as a slave to the secondary
    mysql -u root -p_Admin123 <<EOF
    STOP SLAVE;
    RESET SLAVE ALL;
    CHANGE MASTER TO
        MASTER_HOST="$secondary_ip",
        MASTER_USER='openfire',
        MASTER_PASSWORD='_Admin123',
        MASTER_LOG_FILE="$binlog_file",
        MASTER_LOG_POS=$binlog_pos;
    START SLAVE;
EOF

sudo systemctl restart mysql

sudo mysql -u root -p_Admin123 -e "CREATE DATABASE openfire;"
sudo mysql -u root -p_Admin123 -e "USE openfire; source /home/ubuntu/openfire.sql;"
sudo mysql -u root -p_Admin123 -e "CREATE USER 'openfire'@'%' IDENTIFIED BY '_Admin123';"
sudo mysql -u root -p_Admin123 -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON openfire.* TO 'openfire'@'%';"
sudo mysql -u root -p_Admin123 -e "FLUSH PRIVILEGES;"
fi
