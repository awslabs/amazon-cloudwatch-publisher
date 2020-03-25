#!/usr/bin/env bash
set -e

# This function writes the cloud watch configuration file details for either AWS Cognito credentials (Y) or AWS CLI credentials (N)
function uninstall_answer () {

read -p "
Are you sure you want to uninstall CloudWatch Publisher?: (Y/N)(Don't know what this is? Press 'n' then enter) " unin_ans

if [ -z "$unin_ans" ]; then

  read -p "
	Please Enter (Y/y) for yes or (N/n) for No, are you sure you want to uninstall CloudWatch Publisher?: (Don't Know what this is? Press 'n' then enter" unin_ans

elif [[ $unin_ans =~ ^([yY][eE][sS]|[yY])$ ]]; then

  # Stop and Uninstall the publisher as a daemon that runs at boot
  launchctl stop com.amazonaws.amazon-cloudwatch-publisher
  launchctl unload /Library/LaunchDaemons/com.amazonaws.amazon-cloudwatch-publisher.plist

  # Delete application and configuration folders. The Logs folder will not be deleted.
  rm -fr /opt/aws/amazon-cloudwatch-publisher/bin/
  rm -fr /opt/aws/amazon-cloudwatch-publisher/etc/

  # Delete a user for the script
  sysadminctl -deleteUser _cwpublisher -admin



elif [[ $unin_ans =~ ^([nN][oO]|[nN])$ ]]; then
  echo "
  Canceling this uninstall"
  exit 1;

uninstall_answer

fi


}

# execute the uninstall function

uninstall_answer

echo "============================================="
echo "Finished - OSX Cloudwatch Publisher uninstall"
echo "============================================="
