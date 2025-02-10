sudo sed -i '1d' /var/www/html/wp-config.php

sudo sed -i '1i\
<?php if (isset($_SERVER["HTTP_X_FORWARDED_FOR"])) {\
    $list = explode(",", $_SERVER["HTTP_X_FORWARDED_FOR"]);\
    $_SERVER["REMOTE_ADDR"] = $list[0];\
}\
$_SERVER["HTTP_HOST"] = "nginxequipo45.duckdns.org";\
$_SERVER["REMOTE_ADDR"] = "nginxequipo45.duckdns.org";\
$_SERVER["SERVER_ADDR"] = "nginxequipo45.duckdns.org";\
' /var/www/html/wp-config.php


sudo scp -i clave.pem -o StrictHostKeyChecking=no ubuntu@10.218.1.10:/home/ubuntu/certwordpress/* /home/ubuntu/
sudo cp /home/ubuntu/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
sudo a2enmod ssl
sudo a2enmod headers
sudo a2ensite default-ssl.conf
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
