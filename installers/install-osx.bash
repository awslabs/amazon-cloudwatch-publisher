#!/usr/bin/env bash
set -e


# Create a user for the script
sysadminctl -addUser _cwpublisher -admin


# Install dependencies
pip3 install -r requirements.txt


# Create folders and copy source and config
mkdir -p /opt/aws/amazon-cloudwatch-publisher/bin/
mkdir -p /opt/aws/amazon-cloudwatch-publisher/etc/
mkdir -p /opt/aws/amazon-cloudwatch-publisher/logs/
cp amazon-cloudwatch-publisher /opt/aws/amazon-cloudwatch-publisher/bin/
cp configs/amazon-cloudwatch-publisher-osx.json /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
chown -R _cwpublisher: /opt/aws/amazon-cloudwatch-publisher
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


# Write the launch daemon configuration file
cat << EOF > /Library/LaunchDaemons/com.amazonaws.amazon-cloudwatch-publisher.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>UserName</key><string>_cwpublisher</string>
  <key>KeepAlive</key><true/>
  <key>RunAtLoad</key><true/>
  <key>Label</key><string>com.amazonaws.amazon-cloudwatch-publisher</string>
  <key>ProgramArguments</key>
    <array>
      <string>$(which python3)</string>
      <string>/opt/aws/amazon-cloudwatch-publisher/bin/amazon-cloudwatch-publisher</string>
      <string>/opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json</string>
    </array>
</dict>
</plist>
EOF

# Install the publisher as a daemon that runs at boot
launchctl load /Library/LaunchDaemons/com.amazonaws.amazon-cloudwatch-publisher.plist
