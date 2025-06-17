#!/bin/bash
set -e

echo "Starting MateCat installation and setup..."

# Создаем необходимые директории
mkdir -p /var/log/supervisor
mkdir -p /var/log/apache2/matecat
mkdir -p /etc/apache2/ssl-cert

# Настраиваем MySQL
service mysql start
sleep 10

# Создаем базу данных и пользователя
mysql -u root -e "CREATE DATABASE IF NOT EXISTS matecat CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -u root -e "CREATE DATABASE IF NOT EXISTS matecat_conversions_log CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -u root -e "CREATE USER IF NOT EXISTS 'matecat'@'localhost' IDENTIFIED BY 'matecat01';"
mysql -u root -e "GRANT ALL PRIVILEGES ON matecat.* TO 'matecat'@'localhost';"
mysql -u root -e "GRANT ALL PRIVILEGES ON matecat_conversions_log.* TO 'matecat'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Настраиваем Redis
sed -i 's/bind 127.0.0.1/bind 0.0.0.0/g' /etc/redis/redis.conf

# Включаем модули Apache
a2enmod rewrite filter deflate headers expires proxy_http ssl php7.4

# Скачиваем и устанавливаем ActiveMQ
cd /tmp
wget -q http://archive.apache.org/dist/activemq/5.15.8/apache-activemq-5.15.8-bin.tar.gz
tar -xzf apache-activemq-5.15.8-bin.tar.gz
mv apache-activemq-5.15.8 /opt/activemq
useradd -r -s /bin/false activemq
chown -R activemq:activemq /opt/activemq

# Устанавливаем Node.js через nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 20
nvm use 20

# Клонируем MateCat
su - matecat -c "git clone https://github.com/matecat/MateCat.git matecat"

# Импортируем схему базы данных
mysql -u root matecat < /home/matecat/matecat/INSTALL/matecat.sql

# Устанавливаем Composer и зависимости PHP
cd /home/matecat/matecat
curl -sS https://getcomposer.org/installer | php
php composer.phar --no-dev install

# Копируем конфигурационные файлы
su - matecat -c "cd ~/matecat/inc && cp oauth_config.ini.sample oauth_config.ini"
su - matecat -c "cd ~/matecat/inc && cp task_manager_config.ini.sample task_manager_config.ini"
su - matecat -c "cd ~/matecat/inc && cp Error_Mail_List.ini.sample Error_Mail_List.ini"

# Копируем наши конфигурационные файлы
cp /tmp/matecat-config.ini /home/matecat/matecat/inc/config.ini
cp /tmp/nodejs-config.ini /home/matecat/matecat/nodejs/config.ini
cp /tmp/apache-matecat.conf /etc/apache2/sites-available/matecat.conf

# Включаем сайт Apache
a2ensite matecat.conf
a2dissite 000-default.conf

# Настраиваем права доступа
chown -R matecat:matecat /home/matecat/matecat
chown -R www-data:www-data /home/matecat/matecat/storage

echo "Setup completed. Starting services..."

# Запускаем supervisor
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
