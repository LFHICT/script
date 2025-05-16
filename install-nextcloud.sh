#!/bin/bash
exec > >(tee /var/log/nextcloud-install.log | logger -t nextcloud-install -s 2>/dev/console) 2>&1
set -x

# Ophalen van parameters vanuit ARM template (via CustomScript Extension)
STORAGE_ACCOUNT_NAME=$1
STORAGE_KEY=$2
CONTAINER_NAME=$3

echo "=== INSTALLATIE BEGONNEN ==="
echo "Storage Account: $STORAGE_ACCOUNT_NAME"
echo "Container Name: $CONTAINER_NAME"

# Updates en vereisten
apt update -y
apt install -y snapd unzip curl apache2-utils php-cli php-curl php-xml php-mbstring php-zip php-bz2 php-intl php-gd php-bcmath

# Installatie van Nextcloud via Snap
snap install nextcloud

# Wacht op voltooiing van initialisatie
sleep 15

# Admin gebruiker aanmaken
nextcloud.manual-install admin "Luke@2007"

# HTTP activeren (HTTPS optioneel toevoegen)
nextcloud.enable-https self-signed

# Installatie van Rclone voor het mounten van Azure Blob Storage
curl https://rclone.org/install.sh | bash

# Rclone configuratiepad
mkdir -p /root/.config/rclone

cat <<EOF > /root/.config/rclone/rclone.conf
[azureblob]
type = azureblob
account = $STORAGE_ACCOUNT_NAME
key = $STORAGE_KEY
endpoint = https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net
EOF

# Mount de Azure Blob container naar Nextcloud's externe directory via systemd
mkdir -p /mnt/azureblob
rclone mount azureblob:$CONTAINER_NAME /mnt/azureblob --daemon --vfs-cache-mode writes

# Externe opslag activeren in Nextcloud
snap run nextcloud.occ app:enable files_external
snap run nextcloud.occ app:enable external

# Maak een externe opslagvermelding aan in Nextcloud
snap run nextcloud.occ files_external:create /AzureBlobStorage local null::local --user=admin
snap run nextcloud.occ files_external:option /AzureBlobStorage path /mnt/azureblob

# Zorg dat rechten kloppen
chown -R root:root /mnt/azureblob
chmod -R 755 /mnt/azureblob

# Klaar!
echo "=== INSTALLATIE VOLTOOID ==="
# Voeg public IP toe aan trusted_domains
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Voeg $PUBLIC_IP toe aan trusted_domains..."

CONFIG_FILE="/var/snap/nextcloud/current/nextcloud/config/config.php"

# Backup maken
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Voeg trusted_domains entry toe
snap run nextcloud.occ config:system:set trusted_domains 1 --value="$PUBLIC_IP"

# Apache/Nginx hoeft niet herstart te worden omdat Snap dat afhandelt