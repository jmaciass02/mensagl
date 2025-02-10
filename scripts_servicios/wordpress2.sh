
echo "
if(isset(\$_SERVER['HTTP_X_FORWARDED_FOR'])) {
    \$list = explode(',', \$_SERVER['HTTP_X_FORWARDED_FOR']);
    \$_SERVER['REMOTE_ADDR'] = \$list[0];
}
\$_SERVER['HTTP_HOST'] = 'nginxequipo45.duckdns.org';
\$_SERVER['REMOTE_ADDR'] = 'nginxequipo45.duckdns.org';
\$_SERVER['SERVER_ADDR'] = 'nginxequipo45.duckdns.org';
" | sudo tee -a /var/www/html/wp-config.php
sudo scp -i clave.pem ubuntu@10.218.1.100:/home/ubuntu/certwordpress/* /home/ubuntu/
sudo cp /home/ubuntu/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf 
sudo a2enmod ssl
sudo a2enmod headers
sudo a2ensite default-ssl.conf
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
