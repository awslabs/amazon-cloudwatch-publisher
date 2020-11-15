# Amazon CloudWatch Publisher

Amazon CloudWatch provides a wealth of tools for monitoring resources and applications in real-time. However,
out-of-the-box support is limited to AWS-native resources (e.g. EC2 instances) or systems compatible with
the [CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html).

The purpose of this tool is to expand CloudWatch monitoring support to additional platforms, essentially any that
can run Python. It has been explicitly tested on (and includes daemon installers for) MacOS and the Raspberry Pi.

It supports authentication using locally-stored AWS credentials, a Cognito user, or IoT X.509 certificates.


## Getting Started


### Prerequisites

The publisher itself requires the following runtime dependencies:

*  Python 3 with pip
*  A shell with the `tail` command available (which the script uses to watch log files)
*  A number of Python packages, install with the following:

```bash
pip3 install -r requirements.txt
```


### Installation

The publisher uses a JSON file to provide configuration. The format of this file is based on the
[configuration](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)
used by the default CloudWatch Agent, but it does not support all those options, and it adds its
own unique configuration items. There are example config files in the `configs` folder of the repository.

The location of the config file can be provided to the script via command line parameter, or if
omitted it is assumed to be at `/opt/aws/amazon-cloudwatch-publisher/etc/amazon-cloudwatch-publisher.json`
(again to mimic the behavior of the default agent).

The config file has three top level keys: `agent`, `metrics`, and `logs`.

#### Agent

This section contains general configuration for the script. All keys are optional.

*  `instance`: Has three potential subkeys, `prefix`, `serial` and `command`. These values are used
   to construct a unique identifier for the system on which the publisher is being run. To construct
   the identifier, the `command` string is executed on the system using the shell to return a unique
   identifying number (e.g. on MacOS it queries the system profiler for the hardware serial number),
   or the `serial` field can provide a hardcoded number (note that if both are provided the `command`
   will be ignored and `serial` will be used). This number is then joined to the prefix string with
   a dash to form the final identifier (e.g. `osx-c02v41p2hv2f`). If this key is not provided, a
   default of `sys-000000000000` is used, which is okay for testing but not suitable for production.

*  `authentication`: See the next subsection for details on the authentication options.

*  `region`: AWS region identifier (e.g. `us-west-2`) to which metrics and logs should be published. This
   value is required only if the above `authentication` section is provided, otherwise it is ignored and
   the region configured via the AWS CLI profile (environment variable or `~/.aws/config` file) is used.

*  `metrics_collection_interval`: How often (in seconds) metric values should be sent to CloudWatch.
   Defaults to 300 seconds (5 minutes) if not provided.

*  `logs_collection_interval`: How often (in seconds) outstanding log entries should be sent to
   CloudWatch. Defaults to 10 seconds if not provided. This needs to be set to strike a balance
   between being too chatty and waiting to long to send logs that are rapidly generated, as there
   is a limit on how much log data can be sent in a single call to CloudWatch, see the [put-log-events]
   (https://docs.aws.amazon.com/cli/latest/reference/logs/put-log-events.html) doc page for details.

*  `logfile`: Full path and filename to which the publisher's own log file should be written. Defaults to
   `/opt/aws/amazon-cloudwatch-publisher/logs/amazon-cloudwatch-publisher.log` (to mimic the default agent)
   if not provided. Do not configure the publisher to publish the output of this log file itself when
   debugging is turned on, otherwise a portal of infinite recursion will open up and consume the
   universe. You have been warned.

*  `debug`: When `true`, includes additional information in the above log. Defaults to `false`, which
   is recommended for normal operation.

#### Authentication

For non-production or testing of the publisher, omit the `authentication` key from the config altogether,
ad the script will use the AWS credentials stored in the usual way (i.e. files in
the `.aws` folder under the home folder) See the [AWS CLI documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) for more details.

For Cognito authentication, the following subkeys should be included under `authentication`
(an example of which is in the `configs/amazon-cloudwatch-publisher-osx.json` file). All values
are printed when the `deploy-cognito.py` script is run to configure the authentication back-end
(more details in the Deployment section below):

*  `accountId`: The 12 digit AWS account ID to authenticate into.

*  `userPoolId`: The Cognito user pool identifier, e.g. us-east-1_xxxxxxxxx.

*  `identityPoolId`: The Cognito identity pool identifier, e.g. us-east-1:00000000-0000-0000-0000-000000000000.

*  `appClientId`: The Cognito user pool app client identifier, e.g. a1b2c3d4e5f6g7h8i9j0k1l2m3

*  `password`: The random password for the associated Cognito username that matches this system's unique
   instance identifier. This will be output only once from the deployment script so be sure to grab it,
   else the user will need to be re-created.

For IoT X.509 authentication, the following subkeys should be included (an example of which is in
the `configs/amazon-cloudwatch-publisher-iot.json` file). More details on all these values can
be found in the Deployment section below:

*  `iotUrl`: The IoT endpoint for the AWS account, obtainable by running
   `aws iot describe-endpoint --endpoint-type iot:CredentialProvider`.

*  `roleAlias`: Alias to the role the script will assume when authenticating; this role must have
   a policy with sufficient permissions (see the list in the Running section below)

*  `thingName`: Each instance of the publisher is represented as an IoT thing; this name
   unique identifies a thing.

*  `certificate`: The X.509 certificate for the IoT thing. This field can either be an array with
   two paths, to the device certificate and private key files (in that order), or it can be a single
   path to a file which is the concatenation of both the cert and key files.

#### Metrics

This section contains configuration specific to metrics gathering. Currently only one key is supported
and it is optional.

*  `namespace`: The namespace under which metrics will be published. Defaults to `System/Default`
   if not provided. Note that hostname and instance identifier are automatically used as dimensions
   to further segregate published metrics.

#### Logs

This section contains configuration specific to log publishing. All keys are optional, but if omitted
no logs will be pushed.

*  `logs_collected`: Contains the following subkeys:

   *  `files`: Contains one subkey, `collect_list`, which is array of objects with the following keys:

      *  `file_path`: Full path to the log file to push to CloudWatch
      *  `include_patterns`: List of regular expressions that, if provided, must match a log line for
         it to be included in the push to CloudWatch
      *  `exclude_patterns`: List of regular expressions that, if provided, must not match a log line
         for it to be included in the push; exclude patterns take priority over include patterns when
         both are provided


   *  `journal`: If provided, and if the instance supports it, pushes the system journal to the log
      using the `journalctl` command. The following subkeys are supported:

      *  `include_patterns`: List of regular expressions that, if provided, must match a log line for
         it to be included in the push to CloudWatch
      *  `exclude_patterns`: List of regular expressions that, if provided, must not match a log line
         for it to be included in the push; exclude patterns take priority over include patterns when
         both are provided

*  `log_group_name`: Identifier to use for the log group under which each log file will be
   published. Should be unique per instance. The easiest way to do this is to put `{instance_id}`
   in the string somewhere, which the script will replace with the computed instance ID. Defaults
   to `/system/default/{instance_id}` if not provided.

*  `retention_in_days`: Number of days to retain logs; allowed values are 1, 3, 5, 7, 14, 30, 60,
   90, 120, 150, 180, 365, 400, 545, 731, 1827, or 3653. If no value is provided, logs will be
   retained indefinitely.


### Running

To run the publisher locally for testing, assuming AWS credentials are already configured properly
for the CLI with adequate permissions, and a configuration file has been created, simply execute the
script with `./amazon-cloudwatch-publisher PATH_TO_CONFIG_FILE`.

The required permissions to run the publisher are the following:

*  `cloudwatch:PutMetricData`
*  `logs:CreateLogGroup`
*  `logs:CreateLogStream`
*  `logs:DescribeLogGroups`
*  `logs:DescribeLogStreams`
*  `logs:PutLogEvents`


## Deployment

While locally-stored AWS credentials are acceptable for local execution, it's insufficient for
production for a number of reasons:

*  Systems likely need to operate unattended and the long-lasting credentials that requires are a security risk

*  Credentials would either have to be shared across systems or each system would require its own IAM user, which
   is both a security and management challenge

Instead when used in production the script should use either the Cognito or IoT X.509 methods, both of which
require some additional steps to set up their respective infrastructure. These steps should be performed on
a system separate from those on which the publisher itself will run, since they require locally-configured
AWS credentials with full permissions to run CloudFormation, create Cognito items, and create IoT devices
and certificates.


### Cognito

If using the Cognito authentication solution, the following tools are required:

*  Node >=10.3.0
*  AWS CDK (installed with `npm i -g aws-cdk`)
*  Additional Python packages (installed with `pip3 install aws-cdk.core aws-cdk.aws-cognito aws-cdk.aws-iam passgen`)

The deploy process executes by running `./deploy-cognito.py`, which uses the [AWS CDK](https://aws.amazon.com/cdk)
to create the required infrastructure via code in the `infrastructure` folder. It also creates a set of
users by reading from a text file named `systems.txt`. This file should contain a list of instance identifiers,
one per line, that correspond to the systems running the publisher that will authenticate into Cognito.

The `systems.txt` file must exist, or the deployment will fail. Furthermore, the script will only add systems
to the user pool that don't already exist.

After execution, the deployment script prints the passwords generated for each new user, but only for new users,
so be sure to copy them elsewhere so they can be specified during each system's installation. The script will
also print several other identifiers that will be needed.


### IoT X.509

To use the AWS IoT Credentials Provider to authenticate via X.509, follow the instructions in this
[blog post](https://aws.amazon.com/blogs/security/how-to-eliminate-the-need-for-hardcoded-aws-credentials-in-devices-by-using-the-aws-iot-credentials-provider/)
to set up the necessary configuration, and note the required values which then are added to the publisher
configuration's `authentication` section as described in the Installation section above.


### Installing

Scripts are provided in the `installers` folder to automatically install the script as a background daemon
on the following platforms:

*  MacOS: `install-osx.bash`
*  Raspberry Pi (or any Linux platform that uses systemd): `install-rpi.bash`

To use these scripts, copy the repo files to the system and execute the corresponding script with `sudo`.
When prompted, enter the appropriate values from the deployment step above. The daemon will start
when installation is done, and on all subsequent reboots.


### Uninstalling

The uninstall process is platform dependent, but for the two current platforms, run the following:

*  MacOS: `sudo launchctl unload /Library/LaunchDaemons/com.amazonaws.amazon-cloudwatch-publisher.plist`
*  Raspberry Pi: `systemctl disable amazon-cloudwatch-publisher`


## Limitations

*  The system must have a `tail` command to follow logs; this tool is used since it cleanly
   handles edge cases like rotation and files that don't exist yet when the scripts starts.

*  No two parsed logs can have the same base filename

*  The periodic push from each log file must satisfy the constraints of
   [put_log_events](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/logs.html#CloudWatchLogs.Client.put_log_events);
   adjust `logs_collection_interval` accordingly

*  Hard cap of 50 streamed logs per publisher (matches default query limit for log streams;
   we could make multiple calls, but 50 seems like a reasonable maximum for a single instance)


## Contributing

Pull requests are welcomed. Here are a few items that would be nice to get implemented:

*  More installers / broader OS support and testing
*  Automated tests of some kind
*  Implement include and exclude patterns for logs
*  Retention options for log groups

Please lint all changes with `flake8 --max-line-length=120` before submitting. Also review
the [Contributing Guidelines](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).


## Authors

*  Jud Neer (judneer@amazon.com)


## License

This project is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for details.
