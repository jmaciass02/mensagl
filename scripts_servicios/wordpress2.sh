sudo -u www-data wp-cli cap add "subscriber" "read" --path=/var/www/html
sudo -u www-data wp-cli cap add "subscriber" "create_ticket" --path=/var/www/html
sudo -u www-data wp-cli cap add "subscriber" "view_own_ticket" --path=/var/www/html
sudo -u www-data wp-cli option update default_role "subscriber" --path=/var/www/html




sudo -u www-data wp-cli option update users_can_register 1 --path=/var/www/html
sudo -u www-data wp-cli post create --post_title="Mi cuenta" --post_content="[user_registration_my_account]" --post_status="publish" --post_type="page" --path=/var/www/html --porcelain
sudo -u www-data wp-cli post create --post_title="Registro" --post_content="[user_registration_form id="17"]" --post_status="publish" --post_type="page" --path=/var/www/html --porcelain
sudo -u www-data wp-cli post create --post_title="Tickets" --post_content="[supportcandy]" --post_status="publish" --post_type="page" --path=/var/www/html --porcelain

sudo sed -i '1d' /var/www/html/wp-config.php

sudo sed -i '1i\
<?php if (isset($_SERVER["HTTP_X_FORWARDED_FOR"])) {\
    $list = explode(",", $_SERVER["HTTP_X_FORWARDED_FOR"]);\
    $_SERVER["REMOTE_ADDR"] = $list[0];\
}\
$_SERVER["HTTP_HOST"] = "nginxequipo4-5.duckdns.org";\
$_SERVER["REMOTE_ADDR"] = "nginxequipo4-5.duckdns.org";\
$_SERVER["SERVER_ADDR"] = "nginxequipo4-5.duckdns.org";\
' /var/www/html/wp-config.php


sudo scp -i clave.pem -o StrictHostKeyChecking=no ubuntu@10.217.1.10:/home/ubuntu/certwordpress/* /home/ubuntu/
sudo cp /home/ubuntu/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
sudo a2enmod ssl
sudo a2enmod headers
sudo a2ensite default-ssl.conf
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
