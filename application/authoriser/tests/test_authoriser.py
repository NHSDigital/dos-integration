from base64 import b64encode
from os import environ
from unittest.mock import patch

from aws_lambda_powertools.utilities.typing.lambda_context import LambdaContext

from ..authoriser import generate_policy, get_basic_auth, lambda_handler

FILE_PATH = "application.authoriser.authoriser"


@patch(f"{FILE_PATH}.generate_policy")
@patch(f"{FILE_PATH}.get_basic_auth")
def test_lambda_handler(mock_get_basic_auth, mock_generate_policy):
    # Arrange
    context = LambdaContext()
    event = {
        "authorizationToken": "Basic test",
        "methodArn": "arn:aws:execute-api:eu-west-1:123456789012:qwerty/dev/GET/hello",
    }
    mock_get_basic_auth.return_value = event["authorizationToken"]
    test_policy = {"policy": "test"}
    mock_generate_policy.return_value = test_policy
    # Act
    response = lambda_handler(event, context)
    # Assert
    assert response == test_policy
    mock_generate_policy.assert_called_once_with("*", "Allow", event["methodArn"])


@patch(f"{FILE_PATH}.generate_policy")
@patch(f"{FILE_PATH}.get_basic_auth")
def test_lambda_handler_incorrect_auth(mock_get_basic_auth, mock_generate_policy):
    # Arrange
    context = LambdaContext()
    event = {
        "authorizationToken": "Basic test",
        "methodArn": "arn:aws:execute-api:eu-west-1:123456789012:qwerty/dev/GET/hello",
    }
    mock_get_basic_auth.return_value = ""
    test_policy = {"policy": "test"}
    mock_generate_policy.return_value = test_policy
    # Act
    response = lambda_handler(event, context)
    # Assert
    assert response == test_policy
    mock_generate_policy.assert_called_once_with(None, "Deny", event["methodArn"])


@patch(f"{FILE_PATH}.client")
def test_get_basic_auth(mock_sm_client):
    # Arrange
    username = "test_username"
    password = "test_password"
    secret_id = "test_secret_id"
    environ["DOS_API_GATEWAY_CREDENTIALS_SECRET_NAME"] = secret_id
    environ["DOS_API_GATEWAY_USERNAME_KEY"] = "test_username_key"
    environ["DOS_API_GATEWAY_PASSWORD_KEY"] = "test_password_key"
    secret_string = '{"test_username_key": "test_username", "test_password_key": "test_password"}'
    mock_sm_client().get_secret_value.return_value = {"SecretString": secret_string}
    expected_auth = "Basic " + b64encode(bytes(f"{username}:{password}", encoding="utf-8")).decode("utf-8")
    # Act
    response = get_basic_auth()
    # Assert
    assert response == expected_auth
    mock_sm_client.assert_called_with("secretsmanager")
    mock_sm_client().get_secret_value.assert_called_once_with(SecretId=secret_id)
    # Clean up
    del environ["DOS_API_GATEWAY_CREDENTIALS_SECRET_NAME"]
    del environ["DOS_API_GATEWAY_USERNAME_KEY"]
    del environ["DOS_API_GATEWAY_PASSWORD_KEY"]


def test_generate_policy():
    # Arrange
    principal_id = "test_principal_id"
    effect = "Allow"
    resource = "test_resource"
    # Act
    response = generate_policy(principal_id, effect, resource)
    # Assert
    assert response["principalId"] == principal_id
    assert response["policyDocument"] == {
        "Statement": [
            {
                "Action": "execute-api:Invoke",
                "Effect": effect,
                "Resource": resource,
                "Sid": "FirstStatement",
            },
        ],
        "Version": "2012-10-17",
    }
