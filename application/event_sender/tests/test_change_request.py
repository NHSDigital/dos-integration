from logging import getLogger
from os import environ
from unittest.mock import MagicMock

from requests.auth import HTTPBasicAuth
from responses import POST, activate, add

from ..change_request import ChangeRequest


class TestChangeRequest:
    change_request_event = {
        "reference": "1",
        "system": "Profile Updater (test)",
        "message": "Test message 1531816592293|@./",
        "service_id": "49016",
        "changes": {"ods_code": "f0000", "phone": "0118 999 88199 9119 725 3", "website": "https://www.google.pl"},
    }

    def test__init__(self):
        # Arrange
        environ["PROFILE"] = "remote"
        expected_change_request_url = "https://test.com"
        environ["DOS_API_GATEWAY_URL"] = expected_change_request_url
        expected_timeout = "10"
        environ["DOS_API_GATEWAY_REQUEST_TIMEOUT"] = expected_timeout
        expected_username = "username"
        environ["DOS_API_GATEWAY_USERNAME"] = expected_username
        expected_password = "password"
        environ["DOS_API_GATEWAY_PASSWORD"] = expected_password
        expected_auth = HTTPBasicAuth(expected_username, expected_password)
        # Act
        change_request = ChangeRequest(self.change_request_event)
        # Assert
        assert change_request.logger == getLogger("lambda")
        assert change_request.headers == {"Content-Type": "application/json", "Accept": "application/json"}
        assert change_request.change_request_url == expected_change_request_url
        assert change_request.timeout == int(expected_timeout)
        assert change_request.authorisation == expected_auth
        assert change_request.change_request_body == self.change_request_event
        # Clean up
        del environ["DOS_API_GATEWAY_URL"]
        del environ["DOS_API_GATEWAY_REQUEST_TIMEOUT"]
        del environ["DOS_API_GATEWAY_USERNAME"]
        del environ["DOS_API_GATEWAY_PASSWORD"]
        del environ["PROFILE"]

    @activate
    def test_post_change_request(self):
        # Arrange
        environ["PROFILE"] = "remote"
        expected_change_request_url = "https://test.com"
        environ["DOS_API_GATEWAY_URL"] = expected_change_request_url
        expected_timeout = "10"
        environ["DOS_API_GATEWAY_REQUEST_TIMEOUT"] = expected_timeout
        expected_username = "username"
        environ["DOS_API_GATEWAY_USERNAME"] = expected_username
        expected_password = "password"
        environ["DOS_API_GATEWAY_PASSWORD"] = expected_password
        change_request = ChangeRequest(self.change_request_event)
        expected_response_body = {"my-key": "my-val"}
        status_code = 200
        add(POST, expected_change_request_url, json=expected_response_body, status=status_code)
        change_request.change_request_logger = MagicMock()
        # Act
        change_request.post_change_request()
        # Assert
        assert change_request.response.status_code == status_code
        change_request.change_request_logger.log_change_request_response.assert_called_once_with(
            change_request.response
        )
        # Clean up
        del environ["DOS_API_GATEWAY_URL"]
        del environ["DOS_API_GATEWAY_REQUEST_TIMEOUT"]
        del environ["DOS_API_GATEWAY_USERNAME"]
        del environ["DOS_API_GATEWAY_PASSWORD"]
        del environ["PROFILE"]
