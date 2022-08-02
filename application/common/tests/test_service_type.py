from unittest.mock import MagicMock, patch

import pytest
from pytest import raises

from ..constants import DENTIST_ORG_TYPE_ID, PHARMACY_ORG_TYPE_ID, SERVICE_TYPES, VALID_SERVICE_TYPES_KEY
from ..service_type import get_valid_service_types, validate_organisation_keys, validate_organisation_type_id
from common.errors import ValidationException

FILE_PATH = "application.common.service_type"


@pytest.mark.parametrize(
    "org_type_id, org_sub_type",
    [
        (
            "Dentist",
            "TBA",
        ),
        (
            "PHA",
            "Community",
        ),
    ],
)
@patch(f"{FILE_PATH}.validate_organisation_type_id")
def test_validate_organisation_keys(
    mock_validate_organisation_type_id,
    org_type_id,
    org_sub_type,
):
    # Act & Assert
    validate_organisation_keys(org_type_id, org_sub_type)


@pytest.mark.parametrize(
    "org_type_id, org_sub_type",
    [
        (
            "Dentist",
            "RANDOM",
        ),
        (
            "PHA",
            "TEST1",
        ),
    ],
)
@patch(f"{FILE_PATH}.validate_organisation_type_id")
def test_validate_organisation_keys_org_sub_type_id_exception(
    mock_validate_organisation_type_id, org_type_id, org_sub_type
):
    # Act & Assert
    with raises(ValidationException) as exception:
        validate_organisation_keys(org_type_id, org_sub_type)
        assert f"Unexpected Org Sub Type ID: '{org_sub_type}'" in str(exception.value)


@pytest.mark.parametrize("org_type_id", [PHARMACY_ORG_TYPE_ID, DENTIST_ORG_TYPE_ID])
@patch(f"{FILE_PATH}.AppConfig")
def test_validate_organisation_type_id(mock_app_config, org_type_id):
    # Arrange
    feature_flags = MagicMock()
    mock_app_config().get_feature_flags.return_value = feature_flags
    feature_flags.evaluate.return_value = True
    # Act
    validate_organisation_type_id(org_type_id)
    # Assert
    feature_flags.evaluate.assert_called_once_with(
        name="accepted_org_types", context={"org_type": org_type_id}, default=False
    )


@pytest.mark.parametrize("org_type_id", [PHARMACY_ORG_TYPE_ID, DENTIST_ORG_TYPE_ID])
@patch(f"{FILE_PATH}.AppConfig")
def test_validate_organisation_type_id_wrong_org_type_id_exception(mock_app_config, org_type_id):
    # Arrange
    feature_flags = MagicMock()
    mock_app_config().get_feature_flags.return_value = feature_flags
    feature_flags.evaluate.return_value = False
    # Act
    with raises(ValidationException) as exception:
        validate_organisation_type_id(org_type_id)
        assert f"Unexpected Org Type ID: '{org_type_id}'" in str(exception.value)
    # Assert
    feature_flags.evaluate.assert_called_once_with(
        name="accepted_org_types", context={"org_type": org_type_id}, default=False
    )
    mock_app_config().get_raw_configuration.assert_called_once_with()


@pytest.mark.parametrize(
    "org_type, expected_valid_service_types",
    [
        (
            "Dentist",
            SERVICE_TYPES["Dentist"][VALID_SERVICE_TYPES_KEY],
        ),
        (
            "PHA",
            SERVICE_TYPES["PHA"][VALID_SERVICE_TYPES_KEY],
        ),
    ],
)
def test_get_valid_service_types(org_type, expected_valid_service_types):
    # Act
    valid_service_types = get_valid_service_types(org_type)
    # Assert
    assert expected_valid_service_types == valid_service_types
