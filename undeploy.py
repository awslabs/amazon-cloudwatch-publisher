#!/usr/bin/env python3


"""Execute the CDK destroy."""


# Standard library imports
import subprocess
import sys
import os.path

# Third-party imports
import boto3
import passgen



# Dictionary to collect the output parameters from running CDK deploy
outputs = {}

# Hopefully CDK will eventually have a cleaner way to gather
# results, but for now this output parsing gets the job done
process = subprocess.Popen(('cdk', 'destroy'), cwd='infrastructure', stderr=subprocess.STDOUT)
with process as p:
    #for line in (l.decode().strip() for l in p.stdout):
        # Since the output is captured by Popen, it won't end up on
        # the console unless we explicitly print it, so let's do that
        print()
        # The lines that contain output parameters start with the text below; note that
        # it's possible this breaks if CDK changes its ouptut format in a future release
        # if line.startswith('amazon-cloudwatch-publisher.'):
        #    key, value = line.split(' = ')
        #    outputs[key] = value

# Bail if the deploy process failed for any reason
if process.returncode != 0:
    print('An error occurred while executing the CDK deployment')
    sys.exit(process.returncode)
