from typing import Any

from aws_lambda_powertools.logging import Logger
from aws_lambda_powertools.utilities.validation import validate
from aws_lambda_powertools.utilities.validation.exceptions import SchemaValidationError

from .appconfig import AppConfig
from common.constants import (
    DENTIST_ORG_TYPE_ID,
    ODSCODE_LENGTH_KEY,
    ORGANISATION_SUB_TYPES_KEY,
    PHARMACY_ORG_TYPE_ID,
    SERVICE_TYPES,
    SERVICE_TYPES_ALIAS_KEY,
)
from common.errors import ValidationError

logger = Logger(child=True)


def validate_change_event(event: dict[str, Any]) -> None:
    """Validate event using business rules.

    Args:
        event (Dict[str, Any]): Lambda function invocation event.
    """
    logger.info(f"Attempting to validate event payload: {event}")
    try:
        validate(event=event, schema=INPUT_SCHEMA)
    except SchemaValidationError as exception:
        raise ValidationError(exception) from exception
    validate_organisation_keys(event.get("OrganisationTypeId"), event.get("OrganisationSubType"))
    check_ods_code_length(event["ODSCode"], SERVICE_TYPES[event["OrganisationTypeId"]][ODSCODE_LENGTH_KEY])
    logger.info("Event has been validated")


def check_ods_code_length(odscode: str, odscode_length: int) -> None:
    """Check ODS code length as expected, exception raise if error.

    Note: ods code type is checked by schema validation

    Args:
        odscode (str): odscode of NHS UK service.
        odscode_length (int): expected length of odscode.
    """
    logger.debug(f"Checking ODSCode {odscode} length")
    if len(odscode) != odscode_length:
        msg = f"ODSCode Wrong Length, '{odscode}' is not length {odscode_length}."
        raise ValidationError(msg)


def validate_organisation_keys(org_type_id: str, org_sub_type: str) -> None:
    """Validate the organisation type id and organisation sub type.

    Args:
        org_type_id (str): organisation type id
        org_sub_type (str): organisation sub type

    Raises:
        ValidationError: Either Org Type ID or Org Sub Type is not part of the valid list
    """
    validate_organisation_type_id(org_type_id)
    if org_sub_type in SERVICE_TYPES[org_type_id][ORGANISATION_SUB_TYPES_KEY]:
        logger.info(f"Subtype type id: {org_sub_type} validated")
    else:
        msg = f"Unexpected Org Sub Type ID: '{org_sub_type}'"
        raise ValidationError(msg)


def validate_organisation_type_id(org_type_id: str) -> None:
    """Check if the organisation type id is valid.

    Args:
        org_type_id (str): organisation type id
    """
    app_config = AppConfig("ingest-change-event")
    feature_flags = app_config.get_feature_flags()
    in_accepted_org_types: bool = feature_flags.evaluate(
        name="accepted_org_types",
        context={"org_type": org_type_id},
        default=False,
    )
    logger.debug(f"Accepted org types: {in_accepted_org_types}")
    if (
        org_type_id == PHARMACY_ORG_TYPE_ID
        and in_accepted_org_types
        or org_type_id == DENTIST_ORG_TYPE_ID
        and in_accepted_org_types
    ):
        logger.append_keys(service_type_alias=SERVICE_TYPES[org_type_id][SERVICE_TYPES_ALIAS_KEY])
        logger.info(
            f"Org type id: {org_type_id} validated",
            extra={"in_accepted_org_types": in_accepted_org_types},
        )
    else:
        logger.append_keys(in_accepted_org_types=in_accepted_org_types, app_config=app_config.get_raw_configuration())
        msg = f"Unexpected Org Type ID: '{org_type_id}'"
        raise ValidationError(msg)


INPUT_SCHEMA = {
    "$schema": "https://json-schema.org/draft-07/schema",
    "type": "object",
    "required": ["ODSCode", "OrganisationTypeId", "OrganisationSubType"],
    "properties": {
        "ODSCode": {
            "$id": "#/properties/ODSCode",
            "type": "string",
        },
        "OrganisationTypeId": {
            "$id": "#/properties/OrganisationTypeId",
            "type": "string",
        },
        "OrganisationSubType": {
            "$id": "#/properties/OrganisationSubType",
            "type": "string",
        },
    },
    "additionalProperties": "true",
}
