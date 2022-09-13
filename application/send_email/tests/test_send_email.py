from dataclasses import dataclass

from aws_lambda_powertools.utilities.typing import LambdaContext
from pytest import fixture

from application.send_email.send_email import lambda_handler


@fixture
def lambda_context():
    @dataclass
    class LambdaContext:
        """Mock LambdaContext - All dummy values"""

        function_name: str = "send-email"
        memory_limit_in_mb: int = 128
        invoked_function_arn: str = "arn:aws:lambda:eu-west-1:000000000:function:send-email"
        aws_request_id: str = "52fdfc07-2182-154f-163f-5f0f9a621d72"

    return LambdaContext()


def test_lambda_handler(lambda_context: LambdaContext):
    # Arrange
    event = {}
    # Act
    response = lambda_handler(event, lambda_context)
    # Assert
    assert response is None
