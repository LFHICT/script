#!/bin/bash

# Update en installeer snapd
apt update
apt install -y snapd

# Zorg dat snapd werkt
systemctl enable snapd
systemctl start snapd

# Installeer nextcloud via snap
snap install nextcloud

# Open de benodigde poorten (optioneel, maar ARM NSG regelt dit al)
ufw allow 80,443,22/tcp

# Restart Nextcloud om zeker te zijn dat alles loopt
snap restart nextcloud
