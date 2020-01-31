#!/usr/bin/env bash
set -e


# Create a user for the script
useradd -g wheel -s /sbin/nologin cwpublisher


# Install dependencies
pip3 install boto3 psutil timeloop


# Create folders and copy source and config
mkdir -p /opt/aws/amazon-cloudwatch-publisher/bin/
mkdir -p /opt/aws/amazon-cloudwatch-publisher/etc/
mkdir -p /opt/aws/amazon-cloudwatch-publisher/logs/
cp amazon-cloudwatch-publisher /opt/aws/amazon-cloudwatch-publisher/bin/
cp configs/amazon-cloudwatch-publisher-rpi.json /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
chown -R cwpublisher: /opt/aws/amazon-cloudwatch-publisher
chmod -R u+rwX,g-rwx,o-rwx /opt/aws/amazon-cloudwatch-publisher


# Write configuration file details
read -p "Region: " region
read -p "Account ID: " account_id
read -p "User Pool ID: " user_pool_id
read -p "Identity Pool ID: " identity_pool_id
read -p "App Client ID: " app_client_id
read -p "Password: " password
sed -i "s/REGION/$region/" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
sed -i "s/ACCOUNT_ID/$account_id/" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
sed -i "s/USER_POOL_ID/$user_pool_id/" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
sed -i "s/IDENTITY_POOL_ID/$identity_pool_id/" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
sed -i "s/APP_CLIENT_ID/$app_client_id/" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
sed -i "s/PASSWORD/$password/" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json


# Write the daemon configuration file
cat << EOF > /etc/systemd/system/amazon-cloudwatch-publisher.service
[Unit]
Description=amazon-cloudwatch-publisher
Requires=network.target
After=network.target
[Service]
Type=simple
User=cwpublisher
Group=wheel
ExecStart=/opt/aws/amazon-cloudwatch-publisher/bin/amazon-cloudwatch-publisher
[Install]
WantedBy=multi-user.target
EOF

# Install the publisher as a daemon that runs at boot, and then start it
systemctl enable amazon-cloudwatch-publisher
systemctl start amazon-cloudwatch-publisher
