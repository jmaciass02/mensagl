apt update && DEBIAN_FRONTEND=noninteractive apt install  -y mysql-server

sudo sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl restart mysql

sudo mysql -u root -e "CREATE DATABASE openfire;"
sudo mysql -u root -e "source /home/ubuntu/openfire.sql"
sudo mysql -u root -e "CREATE USER 'openfire'@'%' IDENTIFIED BY '_Admin123';"
sudo mysql -u root -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER ON openfire.* TO 'openfire'@'%';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

chmod +x /home/ubuntu/backups.sh
mkdir /home/ubuntu/backups
(crontab -l 2>/dev/null; echo "0 3 * * * /home/ubuntu/backups.sh >/dev/null 2>&1") | crontab -