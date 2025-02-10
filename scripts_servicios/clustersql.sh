#!/bin/bash

# Variables from Terraform
role="${role}"
primary_ip="10.218.2.200"
secondary_ip="10.218.2.201"
db_user="openfire"
db_password="_Admin123"
db_name="openfire"
repl_user="openfire"
repl_password="_Admin123"
ssh_key_path="/home/ubuntu/clave.pem"

# 1. Configure SSH Key
chmod 600 $ssh_key_path

# 2. Install MySQL if not installed
if ! dpkg -l | grep -q mysql-server; then
    apt update && DEBIAN_FRONTEND=noninteractive apt install -y mysql-server mysql-client
    
fi

# 3. Configure MySQL
server_id=1
if [ "$role" = "secondary" ]; then
    server_id=2
fi

tee /etc/mysql/mysql.conf.d/replication.cnf > /dev/null <<EOF
[mysqld]
bind-address = 0.0.0.0
server-id = $server_id
log_bin = /var/log/mysql/mysql-bin.log
binlog_format = ROW
relay-log = /var/log/mysql/mysql-relay-bin
EOF

# 4. Restart MySQL Service
systemctl restart mysql
systemctl enable mysql

# 5. Basic Security Setup
mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$db_password';
DELETE FROM mysql.user WHERE User='';
CREATE DATABASE IF NOT EXISTS $db_name;
FLUSH PRIVILEGES;
EOF

# 6. Role-Specific Configuration
if [ "$role" = "primary" ]; then
    mysql -u root -p"$db_password" <<EOF
    CREATE USER '$db_user'@'%' IDENTIFIED WITH mysql_native_password BY '$db_password';
    GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'%';
    CREATE USER '$repl_user'@'%' IDENTIFIED WITH mysql_native_password BY '$repl_password';
    GRANT REPLICATION SLAVE ON *.* TO '$repl_user'@'%';
    FLUSH PRIVILEGES;
EOF

    mysql -u root -p"$db_password" -e "SHOW MASTER STATUS" | awk 'NR==2 {print $1, $2}' > /tmp/master_status.txt

elif [ "$role" = "secondary" ]; then
    # Wait for primary to be ready
    echo "Waiting for primary MySQL server to be ready..."
    timeout 300 bash -c 'until nc -z $primary_ip 3306; do sleep 10; done'

    # Copy master status from primary
    scp -o StrictHostKeyChecking=no -i $ssh_key_path ubuntu@$primary_ip:/tmp/master_status.txt /tmp/

    MASTER_STATUS=$(cat /tmp/master_status.txt)
    binlog_file=$(echo "$MASTER_STATUS" | awk '{print $1}')
    binlog_pos=$(echo "$MASTER_STATUS" | awk '{print $2}')

    mysql -u root -p"$db_password" <<EOF
    CHANGE MASTER TO
    MASTER_HOST='$primary_ip',
    MASTER_USER='$repl_user',
    MASTER_PASSWORD='$repl_password',
    MASTER_LOG_FILE='$binlog_file',
    MASTER_LOG_POS=$binlog_pos;
    START SLAVE;
EOF
fi
