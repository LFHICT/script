#!/bin/bash

# Parameters
NEXTCLOUD_VERSION=28.0.1
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=ChangeThis123!
DOMAIN_NAME=nextcloud.local

# Update systeem
apt update && apt upgrade -y

# Install dependencies
apt install -y apache2 mariadb-server libapache2-mod-php php php-mysql php-xml php-mbstring php-curl php-zip php-gd php-intl php-bcmath unzip wget

# Configure database
mysql -u root <<EOF
CREATE DATABASE nextcloud;
CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY 'NCpassw0rd!';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextclouduser'@'localhost';
FLUSH PRIVILEGES;
EOF

# Download en installeer Nextcloud
cd /var/www/
wget https://download.nextcloud.com/server/releases/nextcloud-${NEXTCLOUD_VERSION}.zip
unzip nextcloud-${NEXTCLOUD_VERSION}.zip
chown -R www-data:www-data nextcloud
chmod -R 755 nextcloud

# Configure Apache
cat <<EOL > /etc/apache2/sites-available/nextcloud.conf
<VirtualHost *:80>
    DocumentRoot /var/www/nextcloud
    ServerName ${DOMAIN_NAME}

    <Directory /var/www/nextcloud/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
EOL

a2ensite nextcloud.conf
a2enmod rewrite headers env dir mime
systemctl restart apache2

# (Optioneel) installeer Nextcloud via OCC
sudo -u www-data php /var/www/nextcloud/occ maintenance:install \
  --database "mysql" \
  --database-name "nextcloud" \
  --database-user "nextclouduser" \
  --database-pass "NCpassw0rd!" \
  --admin-user "$NEXTCLOUD_ADMIN_USER" \
  --admin-pass "$NEXTCLOUD_ADMIN_PASSWORD"