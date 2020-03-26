#!/usr/bin/env bash
set -e

function install_cw_creds () {
  read -p "
    Setup your AWS CLI credentials now for the _cwpublisher user?: (this can be done later using 'aws configure') (y/n)" cwenv_ans

  if [[ $cwenv_ans =~ ^([yY][eE][sS]|[yY])$ ]]; then
   awsclicheck=`/usr/bin/which aws`

    if [[ -z $awsclicheck  ]]; then
        # Set up aws cli and environment variables
        read -p "AWS Access Key ID:" cw_access_key_id
        read -s -p "AWS Secret Access Key:" cw_secret_access_key
        read -p "
        Default region name:" cw_region
        read -p "Default output format:" cw_output_format

        # create credential file
        if [[ ! -d /Users/_cwpublisher/.aws/ ]]; then
        mkdir /Users/_cwpublisher/.aws/
        fi

        cat << EOF > /Users/_cwpublisher/.aws/credentials
        [default]
        aws_access_key_id = $cw_access_key_id
        aws_secret_access_key = $cw_secret_access_key
EOF

        # create config file
        cat << EOF > /Users/_cwpublisher/.aws/config
        [default]
        region = $cw_region
        output = $cw_output_format
EOF

        # Set owner permissions
        chown -R _cwpublisher /Users/_cwpublisher/.aws
        chmod 600 /Users/_cwpublisher/.aws/config
        chmod 600 /Users/_cwpublisher/.aws/credentials

      else

       sudo -H -u _cwpublisher aws configure

      fi
echo "configuring LaunchAgent..."

  elif [[ $cogn_ans =~ ^([nN][oO]|[nN])$ ]]; then
  echo "configuring LaunchAgent..."

  fi

}

# This function writes the cloud watch configuration file details for either AWS Cognito credentials (Y) or AWS CLI credentials (N)
function cognito_answer () {


read -p "
Would you like to use cognito authentication?: (Y/N)(Don't know what this is? Press 'n' then enter) " cogn_ans

# if the response not set ask question again
#Actions if 'y' is entered
if [[ $cogn_ans =~ ^([yY][eE][sS]|[yY])$ ]]; then
  #Copy source cloudwatch agent - cognito file to config Destination
  cp configs/amazon-cloudwatch-publisher-osx-cognito.json /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json

  # Write configuration file details
  read -p "Region: " region
  read -p "Account ID: " account_id
  read -p "User Pool ID: " user_pool_id
  read -p "Identity Pool ID: " identity_pool_id
  read -p "App Client ID: " app_client_id
  read -s -p "Password: " password

  sed -i'' -e "s/REGION/$region/g" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
  sed -i'' -e "s/ACCOUNT_ID/$account_id/g" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
  sed -i'' -e "s/USER_POOL_ID/${user_pool_id}/g" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
  sed -i'' -e "s/IDENTITY_POOL_ID/${identity_pool_id}/g" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
  sed -i'' -e "s/APP_CLIENT_ID/${app_client_id}/g" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json
  sed -i'' -e "s/PASSWORD/${password}/g" /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json

  echo "configuring LaunchAgent..."

# Actions if 'n' is entered
elif [[ $cogn_ans =~ ^([nN][oO]|[nN])$ ]]; then

  echo "Please Note this method should not be used on Production Systems."
  #Copy source cloudwatch basic agent file to config Destination
  cp configs/amazon-cloudwatch-publisher-osx-credentials.json /opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json


  # execute credential installation function
  install_cw_creds

else

  cognito_answer

fi


}
# Create a user for the script
sysadminctl -addUser _cwpublisher -admin


# Install dependencies
sudo -H -u _cwpublisher pip3 install boto3 psutil timeloop --user


# Create folders and copy source and config
mkdir -p /opt/aws/amazon-cloudwatch-publisher/bin/
mkdir -p /opt/aws/amazon-cloudwatch-publisher/etc/
mkdir -p /opt/aws/amazon-cloudwatch-publisher/logs/
cp amazon-cloudwatch-publisher /opt/aws/amazon-cloudwatch-publisher/bin/
chown -R _cwpublisher: /opt/aws/amazon-cloudwatch-publisher
chmod -R u+rwX,g-rwx,o-rwx /opt/aws/amazon-cloudwatch-publisher


# Write configuration file details
cognito_answer




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
echo "==========================================="
echo "Finished - OSX Cloudwatch Publisher install"
echo "==========================================="
