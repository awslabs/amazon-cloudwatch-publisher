from aws_cdk.core import App, Stack, CfnOutput
from aws_cdk.aws_iam import Effect, PolicyDocument, PolicyStatement, Role, FederatedPrincipal
from aws_cdk.aws_cognito import AuthFlow, UserPool, UserPoolClient
from aws_cdk.aws_cognito import CfnIdentityPool, CfnIdentityPoolRoleAttachment


class CloudWatchPublisher(Stack):
    """Set up the Congito infrastructure needed for publisher authentication and authorization."""

    def __init__(self, scope, id, **kwargs):

        super().__init__(scope, id, **kwargs)

        # Each publisher instance authenticates as an individual user stored in this pool
        user_pool = UserPool(
            self, 'user-pool',
            user_pool_name='amazon-cloudwatch-publisher'
        )

        # Set up the client app with simple username/password authentication
        user_pool_client = UserPoolClient(
            self, 'user-pool-client',
            user_pool=user_pool,
            enabled_auth_flows=[
                AuthFlow.USER_PASSWORD
            ],
            user_pool_client_name='amazon-cloudwatch-publisher'
        )

        # The identity pool exists to associate users to roles they can assume
        identity_pool = CfnIdentityPool(
            self, 'identity-pool',
            identity_pool_name='amazon-cloudwatch-publisher',
            allow_unauthenticated_identities=False
        )

        # Setting this property links the identity pool to the user pool client app
        identity_pool.add_property_override(
            property_path='CognitoIdentityProviders',
            value=[
                {
                    'ClientId': user_pool_client.user_pool_client_id,
                    'ProviderName': 'cognito-idp.{0}.amazonaws.com/{1}'.format(self.region, user_pool.user_pool_id)
                }
            ]
        )

        # Only identities that come from Congito users should be able to assume the publisher role
        principal = FederatedPrincipal(
            federated='cognito-identity.amazonaws.com',
            assume_role_action='sts:AssumeRoleWithWebIdentity',
            conditions={
                'StringEquals': {
                    'cognito-identity.amazonaws.com:aud': identity_pool.ref
                },
                'ForAnyValue:StringLike': {
                    'cognito-identity.amazonaws.com:amr': 'authenticated'
                }
            }
        )

        # Minimum set of permissions required to push metrics and logs
        policy = PolicyDocument(
            statements=[
                PolicyStatement(
                    effect=Effect.ALLOW,
                    actions=[
                        'cloudwatch:PutMetricData',
                        'logs:CreateLogGroup',
                        'logs:CreateLogStream',
                        'logs:DescribeLogGroups',
                        'logs:DescribeLogStreams',
                        'logs:PutLogEvents',
                    ],
                    resources=[
                        '*',
                    ]
                )
            ]
        )

        # Create the role itself using the principal and policy defined above
        role = Role(
            self, 'role',
            assumed_by=principal,
            inline_policies=[
                policy
            ]
        )

        # Associate the above role with the identity pool; we don't want
        # any unauthenticated access so explicitly ensure it's set to None
        CfnIdentityPoolRoleAttachment(
            self, 'identity-pool-role-attachment-authenticated',
            identity_pool_id=identity_pool.ref,
            roles={
                'authenticated': role.role_arn,
                'unauthenticated': None
            }
        )

        # Defining outputs here allows them to be scraped from the `cdk deploy` command
        CfnOutput(self, 'Region', value=self.region)
        CfnOutput(self, 'AccountId', value=self.account)
        CfnOutput(self, 'UserPoolId', value=user_pool.user_pool_id)
        CfnOutput(self, 'IdentityPoolId', value=identity_pool.ref)
        CfnOutput(self, 'AppClientId', value=user_pool_client.user_pool_client_id)


# Actually do the work of creating the CKD app and instantiating the infrastructure
app = App()
CloudWatchPublisher(app, 'amazon-cloudwatch-publisher')
app.synth()
