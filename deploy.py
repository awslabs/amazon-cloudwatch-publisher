#!/usr/bin/env python3


"""Execute the CDK deploy and populate the user pool."""


# Standard library imports
import subprocess
import sys

# Third-party imports
import boto3
import passgen


# Dictionary to collect the output parameters from running CDK deploy
outputs = {}

# Hopefully CDK will eventually have a cleaner way to gather
# results, but for now this output parsing gets the job done
process = subprocess.Popen(('cdk', 'deploy'), cwd='infrastructure', stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
with process as p:
    for line in (l.decode().strip() for l in p.stdout):
        # Since the output is captured by Popen, it won't end up on
        # the console unless we explicitly print it, so let's do that
        print(line)
        # The lines that contain output parameters start with the text below; note that
        # it's possible this breaks if CDK changes its ouptut format in a future release
        if line.startswith('amazon-cloudwatch-publisher.'):
            key, value = line.split(' = ')
            outputs[key] = value

# Bail if the deploy process failed for any reason
if process.returncode != 0:
    print('An error occurred while executing the CDK deployment')
    sys.exit(process.returncode)


# Grab the created user pool identifier for future use
user_pool_id = outputs['amazon-cloudwatch-publisher.UserPoolId']

# Read the list of usernames (i.e. system IDs) from file
new_usernames = set(l.strip() for l in open('systems.txt').readlines() if l)

# Set up the client object that will be used to create users
cognito_idp = boto3.client('cognito-idp')


# Get the set of current users from Cognito by repeatedly
# through list user calls until all pages are fetched
existing_usernames = set()
params = {'UserPoolId': user_pool_id, 'AttributesToGet': []}
while True:
    response = cognito_idp.list_users(**params)
    existing_usernames.update(u['Username'] for u in response['Users'])
    if 'PaginationToken' in response:
        params['PaginationToken'] = response['PaginationToken']
    else:
        break

# Determine a delta of new system identifiers that need to be added; note that
# the identifiers not in the local systems.txt file are retained (in other
# words this process is purely additive in order to prevent accidental deletion)
usernames_to_add = new_usernames - existing_usernames


# Create a new Cognito user for each new system identifier, generate a
# randomized password for each one, and then set that password permanently
print('Adding system identifiers to {0}'.format(user_pool_id))
for username in usernames_to_add:
    params = {'UserPoolId': user_pool_id, 'Username': username}
    cognito_idp.admin_create_user(**params)
    params['Password'] = passgen.passgen(32, True, limit_punctuation='!@#$%^&*()')
    params['Permanent'] = True
    cognito_idp.admin_set_user_password(**params)
    print('Added user: {0} // {1}'.format(username, params['Password']))
