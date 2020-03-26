#!/usr/bin/env python3


"""Execute the CDK destroy."""


# Standard library imports
import subprocess
import sys


# Dictionary to collect the output parameters from running CDK deploy
outputs = {}

# Hopefully CDK will eventually have a cleaner way to gather
# results, but for now this output parsing gets the job done
process = subprocess.Popen(('cdk', 'destroy'), cwd='infrastructure', stderr=subprocess.STDOUT)
with process as p:
        # Since the output is captured by Popen, it won't end up on
        # the console unless we explicitly print it, so let's do that
        print()

# Bail if the deploy process failed for any reason
if process.returncode != 0:
    print('An error occurred while executing the CDK deployment')
    sys.exit(process.returncode)
