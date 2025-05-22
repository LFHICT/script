#!/bin/bash
exec > >(tee /var/log/nextcloud-install.log | logger -t nextcloud-install -s 2>/dev/console) 2>&1
set -x

# Ophalen van parameters vanuit ARM template (via CustomScript Extension)
STORAGE_ACCOUNT_NAME=$1
STORAGE_KEY=$2
CONTAINER_NAME=$3

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

# Wacht tot Nextcloud klaar is
until snap run nextcloud.occ status &>/dev/null; do
    echo "Wachten op Nextcloud services..."
    sleep 5
done

# Haal public IP op
PUBLIC_IP=$(curl -s "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2021-02-01" -H "Metadata:true")
echo "Publiek IP: $PUBLIC_IP"

# Voeg public IP toe aan trusted_domains (als die nog niet bestaat)
if ! snap run nextcloud.occ config:system:get trusted_domains | grep -q "$PUBLIC_IP"; then
  INDEX=$(snap run nextcloud.occ config:system:get trusted_domains | grep -oP "^\s*\d+" | sort -nr | head -n1)
  INDEX=$((INDEX + 1))
  snap run nextcloud.occ config:system:set trusted_domains "$INDEX" --value="$PUBLIC_IP"
fi