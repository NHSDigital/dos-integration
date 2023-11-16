from datetime import date, time
from logging import INFO
from unittest.mock import MagicMock, patch

import pytest

from application.common.constants import (
    DOS_INTEGRATION_USER_NAME,
    DOS_PALLIATIVE_CARE_SGSDID,
    DOS_SGSDID_CHANGE_KEY,
    DOS_SPECIFIED_OPENING_TIMES_CHANGE_KEY,
    DOS_STANDARD_OPENING_TIMES_FRIDAY_CHANGE_KEY,
)
from application.common.opening_times import OpenPeriod, SpecifiedOpeningTime
from application.service_sync.service_update_logger import ServiceUpdateLogger, log_service_updates

SERVICE_UID = "12345"
SERVICE_NAME = "Test Service"
TYPE_ID = "1"
ODSCODE = "ODS123"
EXAMPLE_DATA_FIELD_MODIFIED = "test_field"
EXAMPLE_ACTION = "update"
EXAMPLE_PREVIOUS_VALUE = "test_value"
EXAMPLE_NEW_VALUE = "new_test_value"
NULL_VALUE = "NULL"
FILE_PATH = "application.service_sync.service_update_logger"


@pytest.fixture()
def service_update_logger() -> ServiceUpdateLogger:
    return ServiceUpdateLogger(service_uid=SERVICE_UID, service_name=SERVICE_NAME, type_id=TYPE_ID, odscode=ODSCODE)


def test_dos_logger(service_update_logger: ServiceUpdateLogger) -> None:
    # Assert
    assert service_update_logger.logger.name == "service_undefined.application.service_sync.service_update_logger"
    assert service_update_logger.dos_logger.name == "dos_logger"
    assert service_update_logger.dos_logger.level == INFO
    assert (
        service_update_logger.dos_basic_format
        == "%(asctime)s|%(levelname)s|DOS_INTEGRATION_%(environment)s|%(message)s"
    )
    assert service_update_logger.service_uid == SERVICE_UID
    assert service_update_logger.service_name == SERVICE_NAME
    assert service_update_logger.type_id == TYPE_ID


def test_service_update_logger_get_opening_times_change_modify(service_update_logger: ServiceUpdateLogger) -> None:
    # Arrange
    previous_value = "Test123"
    new_value = "321Test"
    data_field_modified = "test_field"
    # Act
    response = service_update_logger.get_opening_times_change(
        data_field_modified=data_field_modified,
        previous_value=previous_value,
        new_value=new_value,
    )
    assert (
        f"{data_field_modified}_existing={previous_value}",
        f"{data_field_modified}_update=remove={previous_value}add={new_value}",
    ) == response


def test_service_update_logger_get_opening_times_change_remove(service_update_logger: ServiceUpdateLogger) -> None:
    # Arrange
    previous_value = "Test123"
    new_value = ""
    data_field_modified = "test_field"
    # Act
    response = service_update_logger.get_opening_times_change(
        data_field_modified=data_field_modified,
        previous_value=previous_value,
        new_value=new_value,
    )
    assert (
        f"{data_field_modified}_existing={previous_value}",
        f"{data_field_modified}_update=remove={previous_value}",
    ) == response


def test_service_update_logger_get_opening_times_change_add(service_update_logger: ServiceUpdateLogger) -> None:
    # Arrange
    previous_value = ""
    new_value = "321Test"
    data_field_modified = "test_field"
    # Act
    response = service_update_logger.get_opening_times_change(
        data_field_modified=data_field_modified,
        previous_value=previous_value,
        new_value=new_value,
    )
    assert ("", f"{data_field_modified}_update=add={new_value}") == response


@patch(f"{FILE_PATH}.log_service_updated")
def test_service_update_logger_log_service_update(
    mock_log_service_update: MagicMock, service_update_logger: ServiceUpdateLogger
) -> None:
    # Arrange
    service_update_logger.dos_logger = dos_logger_mock = MagicMock()
    service_update_logger.dos_service = dos_service = MagicMock()
    # Act
    service_update_logger.log_service_update(
        data_field_modified=EXAMPLE_DATA_FIELD_MODIFIED,
        action=EXAMPLE_ACTION,
        previous_value=EXAMPLE_PREVIOUS_VALUE,
        new_value=EXAMPLE_NEW_VALUE,
    )
    correlation_id = service_update_logger.correlation_id
    # Assert
    mock_log_service_update.assert_called_once_with(
        action=EXAMPLE_ACTION,
        data_field_modified=EXAMPLE_DATA_FIELD_MODIFIED,
        new_value=f'"{EXAMPLE_NEW_VALUE}"',
        previous_value=f'"{EXAMPLE_PREVIOUS_VALUE}"',
        service_name=SERVICE_NAME,
        service_uid=SERVICE_UID,
        type_id=TYPE_ID,
        dos_service=dos_service,
    )
    dos_logger_mock.info.assert_called_once_with(
        msg=f"{correlation_id}|{DOS_INTEGRATION_USER_NAME}|{NULL_VALUE}|{SERVICE_UID}|"
        f"{SERVICE_NAME}|{TYPE_ID}|{EXAMPLE_DATA_FIELD_MODIFIED}|{EXAMPLE_ACTION}|"
        f""""{EXAMPLE_PREVIOUS_VALUE}"|"{EXAMPLE_NEW_VALUE}"|{NULL_VALUE}|message=UpdateService|"""
        f"correlationId={correlation_id}|elapsedTime={NULL_VALUE}|execution_time={NULL_VALUE}",
        extra={"environment": "LOCAL"},
    )


@patch(f"{FILE_PATH}.ServiceUpdateLogger.log_service_update")
@patch(f"{FILE_PATH}.ServiceUpdateLogger.get_opening_times_change")
@patch(f"{FILE_PATH}.opening_period_times_from_list")
def test_service_update_logger_log_standard_opening_times_service_update_for_weekday(
    mock_opening_period_times_from_list: MagicMock,
    mock_get_opening_times_change: MagicMock,
    mock_log_service_update: MagicMock,
    service_update_logger: ServiceUpdateLogger,
) -> None:
    # Arrange
    weekday = "monday"
    mock_get_opening_times_change.return_value = (EXAMPLE_PREVIOUS_VALUE, EXAMPLE_NEW_VALUE)
    # Act
    service_update_logger.log_standard_opening_times_service_update_for_weekday(
        data_field_modified=EXAMPLE_DATA_FIELD_MODIFIED,
        action=EXAMPLE_ACTION,
        previous_value=EXAMPLE_PREVIOUS_VALUE,
        new_value=EXAMPLE_NEW_VALUE,
        weekday=weekday,
    )
    # Assert
    mock_opening_period_times_from_list.assert_not_called()
    mock_get_opening_times_change.assert_called_once_with(
        EXAMPLE_DATA_FIELD_MODIFIED,
        EXAMPLE_PREVIOUS_VALUE,
        EXAMPLE_NEW_VALUE,
    )
    mock_log_service_update.assert_called_once_with(
        data_field_modified=EXAMPLE_DATA_FIELD_MODIFIED,
        action=EXAMPLE_ACTION,
        previous_value=EXAMPLE_PREVIOUS_VALUE,
        new_value=EXAMPLE_NEW_VALUE,
    )


@patch(f"{FILE_PATH}.ServiceUpdateLogger.log_service_update")
@patch(f"{FILE_PATH}.ServiceUpdateLogger.get_opening_times_change")
def test_service_update_logger_log_specified_opening_times_service_update(
    mock_get_opening_times_change: MagicMock,
    mock_log_service_update: MagicMock,
) -> None:
    # Arrange
    service_update_logger = ServiceUpdateLogger(
        service_uid=SERVICE_UID,
        service_name=SERVICE_NAME,
        type_id=TYPE_ID,
        odscode=ODSCODE,
    )
    open_periods = [
        OpenPeriod(time(1, 0, 0), time(2, 0, 0)),
        OpenPeriod(time(3, 0, 0), time(5, 0, 0)),
        OpenPeriod(time(8, 0, 0), time(12, 0, 0)),
    ]
    specified_opening_times = SpecifiedOpeningTime(open_periods, date(2022, 12, 26), True)
    previous_value = [specified_opening_times]
    new_value = [specified_opening_times]
    expected_standard_opening_times_string = "2022-12-26-01:00-02:00,2022-12-26-03:00-05:00,2022-12-26-08:00-12:00"
    mock_get_opening_times_change.return_value = (EXAMPLE_PREVIOUS_VALUE, EXAMPLE_NEW_VALUE)
    # Act
    service_update_logger.log_specified_opening_times_service_update(EXAMPLE_ACTION, previous_value, new_value)
    # Assert
    mock_get_opening_times_change.assert_called_once_with(
        DOS_SPECIFIED_OPENING_TIMES_CHANGE_KEY,
        expected_standard_opening_times_string,
        expected_standard_opening_times_string,
    )
    mock_log_service_update.assert_called_once_with(
        data_field_modified=DOS_SPECIFIED_OPENING_TIMES_CHANGE_KEY,
        action=EXAMPLE_ACTION,
        previous_value=EXAMPLE_PREVIOUS_VALUE,
        new_value=EXAMPLE_NEW_VALUE,
    )


@patch(f"{FILE_PATH}.ServiceUpdateLogger")
def test_log_service_updates_demographics_change(mock_service_update_logger: MagicMock) -> None:
    # Arrange
    changes_to_dos = MagicMock()
    service_histories = MagicMock()
    time_stamp = "1661499176"
    change_key = "change_key"
    service_history = {
        time_stamp: {
            "new": {
                change_key: {
                    "changetype": EXAMPLE_ACTION,
                    "data": EXAMPLE_NEW_VALUE,
                    "area": "demographics",
                    "previous": EXAMPLE_PREVIOUS_VALUE,
                },
            },
        },
    }
    service_histories.service_history.keys.return_value = [time_stamp]
    service_histories.service_history.__getitem__.return_value.__getitem__.return_value = service_history[time_stamp][
        "new"
    ]
    # Act
    log_service_updates(changes_to_dos, service_histories)
    # Assert
    mock_service_update_logger.assert_called_once_with(
        service_uid=str(changes_to_dos.dos_service.uid),
        service_name=changes_to_dos.dos_service.name,
        type_id=str(changes_to_dos.dos_service.typeid),
        odscode=str(changes_to_dos.nhs_entity.odscode),
        dos_service=changes_to_dos.dos_service,
    )
    mock_service_update_logger.return_value.log_service_update.assert_called_once_with(
        data_field_modified=change_key,
        action=EXAMPLE_ACTION,
        previous_value=EXAMPLE_PREVIOUS_VALUE,
        new_value=EXAMPLE_NEW_VALUE,
    )


@patch(f"{FILE_PATH}.ServiceUpdateLogger")
def test_log_service_updates_standard_opening_times_change(mock_service_update_logger: MagicMock) -> None:
    # Arrange
    changes_to_dos = MagicMock()
    service_histories = MagicMock()
    time_stamp = "1661499176"
    change_key = DOS_STANDARD_OPENING_TIMES_FRIDAY_CHANGE_KEY
    service_history = {
        time_stamp: {
            "new": {
                change_key: {
                    "changetype": EXAMPLE_ACTION,
                    "data": EXAMPLE_NEW_VALUE,
                    "area": "demographics",
                    "previous": EXAMPLE_PREVIOUS_VALUE,
                },
            },
        },
    }
    service_histories.service_history.keys.return_value = [time_stamp]
    service_histories.service_history.__getitem__.return_value.__getitem__.return_value = service_history[time_stamp][
        "new"
    ]
    # Act
    log_service_updates(changes_to_dos, service_histories)
    # Assert
    mock_service_update_logger.assert_called_once_with(
        service_uid=str(changes_to_dos.dos_service.uid),
        service_name=changes_to_dos.dos_service.name,
        type_id=str(changes_to_dos.dos_service.typeid),
        odscode=str(changes_to_dos.nhs_entity.odscode),
        dos_service=changes_to_dos.dos_service,
    )
    mock_service_update_logger.return_value.log_standard_opening_times_service_update_for_weekday.assert_called_once_with(
        data_field_modified=change_key,
        action=EXAMPLE_ACTION,
        previous_value=changes_to_dos.dos_service.standard_opening_times,
        new_value=changes_to_dos.nhs_entity.standard_opening_times,
        weekday="friday",
    )


@patch(f"{FILE_PATH}.ServiceUpdateLogger")
def test_log_service_updates_specified_opening_times_change(mock_service_update_logger: MagicMock) -> None:
    # Arrange
    changes_to_dos = MagicMock()
    service_histories = MagicMock()
    time_stamp = "1661499176"
    change_key = DOS_SPECIFIED_OPENING_TIMES_CHANGE_KEY
    service_history = {
        time_stamp: {
            "new": {
                change_key: {
                    "changetype": EXAMPLE_ACTION,
                    "data": EXAMPLE_NEW_VALUE,
                    "area": "demographics",
                    "previous": EXAMPLE_PREVIOUS_VALUE,
                },
            },
        },
    }
    service_histories.service_history.keys.return_value = [time_stamp]
    service_histories.service_history.__getitem__.return_value.__getitem__.return_value = service_history[time_stamp][
        "new"
    ]
    # Act
    log_service_updates(changes_to_dos, service_histories)
    # Assert
    mock_service_update_logger.assert_called_once_with(
        service_uid=str(changes_to_dos.dos_service.uid),
        service_name=changes_to_dos.dos_service.name,
        type_id=str(changes_to_dos.dos_service.typeid),
        odscode=str(changes_to_dos.nhs_entity.odscode),
        dos_service=changes_to_dos.dos_service,
    )
    mock_service_update_logger.return_value.log_specified_opening_times_service_update.assert_called_once_with(
        action=EXAMPLE_ACTION,
        previous_value=changes_to_dos.current_specified_opening_times,
        new_value=changes_to_dos.new_specified_opening_times,
    )


@patch(f"{FILE_PATH}.ServiceUpdateLogger")
def test_log_service_updates_sgsdid_change(mock_service_update_logger: MagicMock) -> None:
    # Arrange
    changes_to_dos = MagicMock()
    service_histories = MagicMock()
    time_stamp = "1661499176"
    change_key = DOS_SGSDID_CHANGE_KEY
    service_history = {
        time_stamp: {
            "new": {
                change_key: {
                    "changetype": "delete",
                    "data": {"remove": [DOS_PALLIATIVE_CARE_SGSDID]},
                    "area": "clinical",
                    "previous": "",
                },
            },
        },
    }
    service_histories.service_history.keys.return_value = [time_stamp]
    service_histories.service_history.__getitem__.return_value.__getitem__.return_value = service_history[time_stamp][
        "new"
    ]
    # Act
    log_service_updates(changes_to_dos, service_histories)
    # Assert
    mock_service_update_logger.assert_called_once_with(
        service_uid=str(changes_to_dos.dos_service.uid),
        service_name=changes_to_dos.dos_service.name,
        type_id=str(changes_to_dos.dos_service.typeid),
        odscode=str(changes_to_dos.nhs_entity.odscode),
        dos_service=changes_to_dos.dos_service,
    )

    mock_service_update_logger.return_value.log_sgsdid_service_update.assert_called_once_with(
        action="delete",
        new_value=DOS_PALLIATIVE_CARE_SGSDID,
    )
