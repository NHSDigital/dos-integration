import hashlib
from datetime import date
from json import dumps
from os import environ
from unittest.mock import MagicMock, call, patch

import pytest
from aws_embedded_metrics.logger.metrics_logger import MetricsLogger
from aws_lambda_powertools.logging import Logger

from application.common.types import HoldingQueueChangeEventItem
from application.conftest import PHARMACY_STANDARD_EVENT, dummy_dos_service
from application.service_matcher.service_matcher import (
    get_matching_services,
    get_pharmacy_first_phase_one_feature_flag,
    lambda_handler,
    log_missing_dos_services,
    remove_service_if_not_on_change_event,
    send_update_requests,
)
from common.commissioned_service_type import BLOOD_PRESSURE, CONTRACEPTION
from common.nhs import NHSEntity
from common.opening_times import OpenPeriod, SpecifiedOpeningTime

FILE_PATH = "application.service_matcher.service_matcher"

SERVICE_MATCHER_ENVIRONMENT_VARIABLES = ["ENV"]


@patch(f"{FILE_PATH}.get_pharmacy_first_phase_one_feature_flag")
@patch(f"{FILE_PATH}.get_matching_dos_services")
def test_get_matching_services(
    mock_get_matching_dos_services,
    mock_get_pharmacy_first_phase_one_feature_flag: MagicMock,
    change_event,
):
    # Arrange
    nhs_entity = NHSEntity(change_event)
    service = dummy_dos_service()
    service.typeid = 13
    service.statusid = 1
    mock_get_matching_dos_services.return_value = [service]
    mock_get_pharmacy_first_phase_one_feature_flag.return_value = True
    # Act
    matching_services = get_matching_services(nhs_entity)
    # Assert
    assert matching_services == [service]
    mock_get_pharmacy_first_phase_one_feature_flag.assert_called_once()


@patch(f"{FILE_PATH}.get_pharmacy_first_phase_one_feature_flag")
@patch(f"{FILE_PATH}.get_matching_dos_services")
def test_get_unmatching_services(
    mock_get_matching_dos_services,
    mock_get_pharmacy_first_phase_one_feature_flag: MagicMock,
    change_event,
):
    # Arrange
    nhs_entity = NHSEntity(change_event)
    mock_get_matching_dos_services.return_value = []
    mock_get_pharmacy_first_phase_one_feature_flag.return_value = True
    # Act
    response = get_matching_services(nhs_entity)
    # Assert
    assert response == []
    mock_get_pharmacy_first_phase_one_feature_flag.assert_called_once()


def get_message_attributes(
    correlation_id: str,
    message_received: int,
    record_id: str,
    ods_code: str,
    message_deduplication_id: str,
    message_group_id: str,
):
    return {
        "correlation_id": {"DataType": "String", "StringValue": correlation_id},
        "message_received": {"DataType": "Number", "StringValue": str(message_received)},
        "dynamo_record_id": {"DataType": "String", "StringValue": record_id},
        "ods_code": {"DataType": "String", "StringValue": ods_code},
        "message_deduplication_id": {"DataType": "String", "StringValue": message_deduplication_id},
        "message_group_id": {"DataType": "String", "StringValue": message_group_id},
    }


@patch(f"{FILE_PATH}.log_missing_dos_service_for_a_given_type")
def test_log_missing_dos_services__missing(mock_log_missing_dos_service_for_a_given_type, change_event):
    # Arrange
    entity = MagicMock()
    entity.check_for_service.return_value = True
    service = dummy_dos_service()
    service.typeid = 13
    service.statusid = 1
    matching_dos_services = [service]

    # Act
    log_missing_dos_services(entity, matching_dos_services, BLOOD_PRESSURE)

    # Assert
    entity.check_for_service.assert_called_once_with(BLOOD_PRESSURE.NHS_UK_SERVICE_CODE)
    mock_log_missing_dos_service_for_a_given_type.assert_called_once_with(
        nhs_entity=entity,
        matching_services=matching_dos_services,
        missing_type=BLOOD_PRESSURE,
        reason=f"No '{BLOOD_PRESSURE.TYPE_NAME}' type services found in DoS even though its specified"
        f" in the NHS UK Change Event (dos type {BLOOD_PRESSURE.DOS_TYPE_ID})",
    )


@patch(f"{FILE_PATH}.log_missing_dos_service_for_a_given_type")
def test_log_missing_dos_services__not_missing(mock_log_missing_dos_service_for_a_given_type, change_event):
    # Arrange
    entity = MagicMock()
    entity.check_for_service.return_value = True
    service = dummy_dos_service()
    service.typeid = 13
    service.statusid = 1
    service_two = dummy_dos_service()
    service_two.typeid = BLOOD_PRESSURE.DOS_TYPE_ID
    service_two.statusid = 1
    matching_dos_services = [service, service_two]

    # Act
    log_missing_dos_services(entity, matching_dos_services, BLOOD_PRESSURE)

    # Assert
    entity.check_for_service.assert_called_once_with(BLOOD_PRESSURE.NHS_UK_SERVICE_CODE)
    mock_log_missing_dos_service_for_a_given_type.assert_not_called()


@patch(f"{FILE_PATH}.log_missing_dos_service_for_a_given_type")
def test_log_missing_dos_services__not_on_nhs_entity(mock_log_missing_dos_service_for_a_given_type, change_event):
    # Arrange
    entity = MagicMock()
    entity.check_for_service.return_value = False
    service = dummy_dos_service()
    service.typeid = 13
    service.statusid = 1
    service_two = dummy_dos_service()
    service_two.typeid = BLOOD_PRESSURE.DOS_TYPE_ID
    service_two.statusid = 1
    matching_dos_services = [service, service_two]

    # Act
    log_missing_dos_services(entity, matching_dos_services, BLOOD_PRESSURE)

    # Assert
    entity.check_for_service.assert_called_once_with(BLOOD_PRESSURE.NHS_UK_SERVICE_CODE)
    mock_log_missing_dos_service_for_a_given_type.assert_not_called()


@patch(f"{FILE_PATH}.get_matching_services")
@patch(f"{FILE_PATH}.send_update_requests")
@patch(f"{FILE_PATH}.NHSEntity")
@patch(f"{FILE_PATH}.extract_body")
@patch.object(MetricsLogger, "put_metric")
@patch.object(MetricsLogger, "set_dimensions")
def test_lambda_handler_unmatched_service(
    mock_set_dimension,
    mock_put_metric,
    mock_extract_body,
    mock_nhs_entity,
    mock_send_update_requests,
    mock_get_matching_services,
    change_event,
    lambda_context,
):
    # Arrange
    mock_entity = NHSEntity(change_event)
    sqs_event = SQS_EVENT.copy()
    sqs_event["Records"][0]["body"] = dumps(HOLDING_QUEUE_CHANGE_EVENT_ITEM)
    mock_extract_body.return_value = HOLDING_QUEUE_CHANGE_EVENT_ITEM
    mock_nhs_entity.return_value = mock_entity
    mock_get_matching_services.return_value = []
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        environ[env] = "test"
    # Act
    response = lambda_handler(sqs_event, lambda_context)
    # Assert
    assert response is None, f"Response should be None but is {response}"
    mock_extract_body.assert_called_once_with(sqs_event["Records"][0]["body"])
    mock_nhs_entity.assert_called_once_with(change_event)
    mock_get_matching_services.assert_called_once_with(mock_entity)
    mock_send_update_requests.assert_not_called()
    # Clean up
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        del environ[env]


@patch(f"{FILE_PATH}.log_unmatched_nhsuk_service")
@patch(f"{FILE_PATH}.get_matching_services")
@patch(f"{FILE_PATH}.send_update_requests")
@patch(f"{FILE_PATH}.NHSEntity")
@patch(f"{FILE_PATH}.extract_body")
def test_lambda_handler_no_matching_dos_services(
    mock_extract_body,
    mock_nhs_entity,
    mock_send_update_requests,
    mock_get_matching_services,
    mock_log_unmatched_nhsuk_service,
    change_event,
    lambda_context,
):
    # Arrange
    mock_entity = NHSEntity(change_event)
    sqs_event = SQS_EVENT.copy()
    sqs_event["Records"][0]["body"] = dumps(HOLDING_QUEUE_CHANGE_EVENT_ITEM)
    mock_extract_body.return_value = HOLDING_QUEUE_CHANGE_EVENT_ITEM
    mock_nhs_entity.return_value = mock_entity
    mock_get_matching_services.return_value = []
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        environ[env] = "test"
    # Act
    lambda_handler(sqs_event, lambda_context)
    # Assert
    mock_log_unmatched_nhsuk_service.assert_called_once()
    mock_send_update_requests.assert_not_called()
    # Clean up
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        del environ[env]


@patch(f"{FILE_PATH}.log_closed_or_hidden_services")
@patch(f"{FILE_PATH}.get_matching_services")
@patch(f"{FILE_PATH}.send_update_requests")
@patch(f"{FILE_PATH}.NHSEntity")
@patch(f"{FILE_PATH}.extract_body")
def test_lambda_handler_hidden_or_closed_pharmacies(
    mock_extract_body,
    mock_nhs_entity,
    mock_send_update_requests,
    mock_get_matching_services,
    mock_log_closed_or_hidden_services,
    change_event,
    lambda_context,
):
    # Arrange
    service = dummy_dos_service()
    service.id = 1
    service.uid = 101
    service.odscode = "SLC4501"
    service.web = "www.fakesite.com"
    service.publicphone = "01462622435"
    service.postcode = "S45 1AB"
    service.statusid = 1

    change_event["OrganisationStatus"] = "closed"
    mock_entity = NHSEntity(change_event)
    sqs_event = SQS_EVENT.copy()
    sqs_event["Records"][0]["body"] = dumps(HOLDING_QUEUE_CHANGE_EVENT_ITEM)
    mock_extract_body.return_value = HOLDING_QUEUE_CHANGE_EVENT_ITEM
    mock_nhs_entity.return_value = mock_entity
    mock_get_matching_services.return_value = [service]

    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        environ[env] = "test"
    # Act
    lambda_handler(sqs_event, lambda_context)
    # Assert
    mock_log_closed_or_hidden_services.assert_called_once()
    mock_send_update_requests.assert_not_called()
    # Clean up
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        del environ[env]


@patch(f"{FILE_PATH}.send_update_requests")
@patch(f"{FILE_PATH}.log_invalid_open_times")
@patch(f"{FILE_PATH}.get_matching_services")
@patch(f"{FILE_PATH}.NHSEntity")
@patch(f"{FILE_PATH}.extract_body")
def test_lambda_handler_invalid_open_times(
    mock_extract_body,
    mock_nhs_entity,
    mock_get_matching_services,
    mock_log_invalid_open_times,
    mock_send_update_requests,
    change_event,
    lambda_context,
):
    # Arrange
    service = dummy_dos_service()
    service.id = 1
    service.uid = 101
    service.odscode = "SLC4501"
    service.web = "www.fakesite.com"
    service.publicphone = "01462622435"
    service.postcode = "S45 1AB"
    service.statusid = 1

    change_event["OpeningTimes"] = [
        {
            "Weekday": "Monday",
            "OpeningTime": "09:00",
            "ClosingTime": "13:00",
            "OpeningTimeType": "General",
            "AdditionalOpeningDate": "",
            "IsOpen": True,
        },
        {
            "Weekday": "Monday",
            "OpeningTime": "12:00",
            "ClosingTime": "17:30",
            "OpeningTimeType": "General",
            "AdditionalOpeningDate": "",
            "IsOpen": True,
        },
    ]
    mock_entity = NHSEntity(change_event)
    sqs_event = SQS_EVENT.copy()
    sqs_event["Records"][0]["body"] = dumps(HOLDING_QUEUE_CHANGE_EVENT_ITEM)
    mock_extract_body.return_value = HOLDING_QUEUE_CHANGE_EVENT_ITEM
    mock_nhs_entity.return_value = mock_entity
    mock_get_matching_services.return_value = [service]

    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        environ[env] = "test"
    # Act
    lambda_handler(sqs_event, lambda_context)
    # Assert
    mock_log_invalid_open_times.assert_called_once()
    mock_send_update_requests.assert_called()
    # Clean up
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        del environ[env]


@patch(f"{FILE_PATH}.parameters.get_parameter")
def test_get_pharmacy_first_phase_one_feature_flag(mock_get_parameter: MagicMock) -> None:
    # Arrange
    environ["PHARMACY_FIRST_PHASE_ONE_PARAMETER"] = environment_variable = "test"
    mock_get_parameter.return_value = "True"
    # Act
    response = get_pharmacy_first_phase_one_feature_flag()
    # Assert
    assert response is True
    mock_get_parameter.assert_called_once_with(environment_variable)
    # Clean up
    del environ["PHARMACY_FIRST_PHASE_ONE_PARAMETER"]


def test_lambda_handler_should_throw_exception_if_event_records_len_not_eq_one(lambda_context):
    # Arrange
    sqs_event = SQS_EVENT.copy()
    sqs_event["Records"] = []
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        environ[env] = "test"
    # Act / Assert
    with pytest.raises(StopIteration):
        lambda_handler(sqs_event, lambda_context)
    # Clean up
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        del environ[env]


def test_remove_service_if_not_on_change_event() -> None:
    # Arrange
    service = dummy_dos_service()
    service.typeid = 13
    service.statusid = 1
    service2 = dummy_dos_service()
    service2.typeid = 148
    service2.statusid = 2
    matching_services = [service, service2]
    nhs_entity = NHSEntity(PHARMACY_STANDARD_EVENT)
    nhs_entity.blood_pressure = False
    # Act
    response = remove_service_if_not_on_change_event(matching_services, nhs_entity, "blood_pressure", BLOOD_PRESSURE)
    # Assert
    assert response == [service]


@patch(f"{FILE_PATH}.sqs")
@patch.object(Logger, "get_correlation_id", return_value="1")
@patch.object(Logger, "info")
def test_send_update_requests(mock_logger, get_correlation_id_mock, mock_sqs):
    # Arrange
    q_name = "test-queue"
    environ["UPDATE_REQUEST_QUEUE_URL"] = q_name
    message_received = 1642501355616
    record_id = "someid"
    sequence_number = 1
    odscode = "FXXX1"
    update_requests = [{"service_id": "1", "change_event": {"ODSCode": odscode}}]
    # Act
    send_update_requests(
        update_requests=update_requests,
        message_received=message_received,
        record_id=record_id,
        sequence_number=sequence_number,
    )
    # Assert
    payload = dumps(update_requests[0])
    encoded = payload.encode()
    hashed_payload = hashlib.sha256(encoded).hexdigest()
    entry_details = {
        "Id": "1-1",
        "MessageBody": payload,
        "MessageDeduplicationId": f"1-{hashed_payload}",
        "MessageGroupId": "1",
        "MessageAttributes": get_message_attributes(
            "1",
            message_received,
            record_id,
            odscode,
            f"1-{hashed_payload}",
            "1",
        ),
    }
    mock_sqs.send_message_batch.assert_called_with(
        QueueUrl=q_name,
        Entries=[entry_details],
    )
    mock_logger.assert_called_with("Sent off update request for id=1")
    # Clean up
    del environ["UPDATE_REQUEST_QUEUE_URL"]


@patch(f"{FILE_PATH}.send_update_requests")
@patch(f"{FILE_PATH}.log_invalid_open_times")
@patch(f"{FILE_PATH}.get_matching_services")
@patch(f"{FILE_PATH}.NHSEntity")
@patch(f"{FILE_PATH}.extract_body")
def test_lambda_handler_invalid_existing_dos_opening_times(
    mock_extract_body,
    mock_nhs_entity,
    mock_get_matching_services,
    mock_log_invalid_open_times,
    mock_send_update_requests,
    change_event,
    lambda_context,
):
    mock_entity = NHSEntity(change_event)
    sqs_event = SQS_EVENT.copy()
    holding_queue_change_event_item = HOLDING_QUEUE_CHANGE_EVENT_ITEM.copy()
    holding_queue_change_event_item["change_event"] = change_event
    mock_extract_body.return_value = holding_queue_change_event_item
    mock_nhs_entity.return_value = mock_entity

    service = dummy_dos_service()
    spec_open_time = SpecifiedOpeningTime([OpenPeriod.from_string("12:00-16:00")], date(2023, 3, 1), True)
    service.specified_opening_times = [spec_open_time, spec_open_time]
    mock_get_matching_services.return_value = [service]

    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        environ[env] = "test"
    # Act
    lambda_handler(sqs_event, lambda_context)
    # Assert
    # Clean up
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        del environ[env]


@patch(f"{FILE_PATH}.log_missing_dos_services")
@patch(f"{FILE_PATH}.get_matching_services")
@patch(f"{FILE_PATH}.send_update_requests")
@patch(f"{FILE_PATH}.NHSEntity")
@patch(f"{FILE_PATH}.extract_body")
@patch.object(MetricsLogger, "put_metric")
@patch.object(MetricsLogger, "set_dimensions")
def test_lambda_handler_unexpected_pharmacy_profiling_multiple_type_13s(
    mock_set_dimension,
    mock_put_metric,
    mock_extract_body,
    mock_nhs_entity,
    mock_send_update_requests,
    mock_get_matching_services,
    mock_log_missing_dos_services,
    change_event,
    lambda_context,
):
    # Arrange
    mock_entity = NHSEntity(change_event)
    sqs_event = SQS_EVENT.copy()
    sqs_event["Records"][0]["body"] = dumps(HOLDING_QUEUE_CHANGE_EVENT_ITEM)
    mock_extract_body.return_value = HOLDING_QUEUE_CHANGE_EVENT_ITEM
    mock_nhs_entity.return_value = mock_entity
    service = dummy_dos_service()
    service.typeid = 13
    service.statusid = 1
    mock_get_matching_services.return_value = [service, service]
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        environ[env] = "test"
    # Act
    response = lambda_handler(sqs_event, lambda_context)
    # Assert
    assert response is None, f"Response should be None but is {response}"
    mock_extract_body.assert_called_once_with(sqs_event["Records"][0]["body"])
    mock_nhs_entity.assert_called_once_with(change_event)
    mock_get_matching_services.assert_called_once_with(mock_entity)
    mock_log_missing_dos_services.assert_has_calls(
        [call(mock_entity, [service, service], BLOOD_PRESSURE), call(mock_entity, [service, service], CONTRACEPTION)],
    )
    mock_send_update_requests.assert_called()
    # Clean up
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        del environ[env]


@patch(f"{FILE_PATH}.log_missing_dos_services")
@patch(f"{FILE_PATH}.get_matching_services")
@patch(f"{FILE_PATH}.send_update_requests")
@patch(f"{FILE_PATH}.NHSEntity")
@patch(f"{FILE_PATH}.extract_body")
@patch.object(MetricsLogger, "put_metric")
@patch.object(MetricsLogger, "set_dimensions")
def test_lambda_handler_unexpected_pharmacy_profiling_no_type_13s(
    mock_set_dimension,
    mock_put_metric,
    mock_extract_body,
    mock_nhs_entity,
    mock_send_update_requests,
    mock_get_matching_services,
    mock_log_missing_dos_services,
    change_event,
    lambda_context,
):
    # Arrange
    mock_entity = NHSEntity(change_event)
    sqs_event = SQS_EVENT.copy()
    sqs_event["Records"][0]["body"] = dumps(HOLDING_QUEUE_CHANGE_EVENT_ITEM)
    mock_extract_body.return_value = HOLDING_QUEUE_CHANGE_EVENT_ITEM
    mock_nhs_entity.return_value = mock_entity
    service = dummy_dos_service()
    service.typeid = 131
    service.statusid = 1
    mock_get_matching_services.return_value = [service, service]
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        environ[env] = "test"
    # Act
    response = lambda_handler(sqs_event, lambda_context)
    # Assert
    assert response is None, f"Response should be None but is {response}"
    mock_extract_body.assert_called_once_with(sqs_event["Records"][0]["body"])
    mock_nhs_entity.assert_called_once_with(change_event)
    mock_get_matching_services.assert_called_once_with(mock_entity)
    mock_log_missing_dos_services.assert_has_calls(
        [call(mock_entity, [service, service], BLOOD_PRESSURE), call(mock_entity, [service, service], CONTRACEPTION)],
    )
    mock_send_update_requests.assert_called()
    # Clean up
    for env in SERVICE_MATCHER_ENVIRONMENT_VARIABLES:
        del environ[env]


HOLDING_QUEUE_CHANGE_EVENT_ITEM = HoldingQueueChangeEventItem(
    change_event=PHARMACY_STANDARD_EVENT.copy(),
    message_received=1234567890,
    sequence_number=1,
    dynamo_record_id="123",
    correlation_id="correlation_id",
)
SQS_EVENT = {
    "Records": [
        {
            "messageId": "059f36b4-87a3-44ab-83d2-661975830a7d",
            "receiptHandle": "AQEBwJnKyrHigUMZj6rYigCgxlaS3SLy0a...",
            "body": dumps(HOLDING_QUEUE_CHANGE_EVENT_ITEM),
            "attributes": {
                "ApproximateReceiveCount": "1",
                "SentTimestamp": "1642619743522",
                "SenderId": "AIDAIENQZJOLO23YVJ4VO",
                "ApproximateFirstReceiveTimestamp": "1545082649185",
            },
            "messageAttributes": {
                "correlation-id": {"stringValue": "1", "dataType": "String"},
                "sequence-number": {"stringValue": "1", "dataType": "Number"},
            },
            "md5OfBody": "e4e68fb7bd0e697a0ae8f1bb342846b3",
            "eventSource": "aws:sqs",
            "eventSourceARN": "arn:aws:sqs:us-east-2:123456789012:my-queue",
            "awsRegion": "us-east-2",
        },
    ],
}
