from os import getenv

from aws_lambda_powertools.logging import Logger
from psycopg import Connection

from common.commissioned_service_type import PALLIATIVE_CARE, CommissionedServiceType
from common.constants import DISTANCE_SELLING_PHARMACY_ID, DOS_ACTIVE_STATUS_ID, PHARMACY_SERVICE_TYPE_IDS
from common.dos import DoSService
from common.dos_db_connection import query_dos_db

logger = Logger(child=True)


def search_for_pharmacy_ods_codes(connection: Connection) -> set[str]:
    """Search for pharmacy ODS codes in DoS DB.

    Args:
        connection (Connection): Connection to the DoS DB.

    Returns:
        set[str]: Unique set of pharmacy ODS codes.
    """
    starting_character = getenv("ODSCODE_STARTING_CHARACTER") or "f"
    cursor = query_dos_db(
        connection,
        "SELECT LEFT(odscode, 5) FROM services s WHERE s.typeid = ANY(%(PHARMACY_SERVICE_TYPE_IDS)s) "
        "AND s.statusid = %(ACTIVE_STATUS_ID)s AND LEFT(REPLACE(TRIM(odscode), CHR(9), ''), 1) IN "
        "(%(ODSCODE_STARTING_CHARACTER_CAPITALISED)s, %(ODSCODE_STARTING_CHARACTER)s)",
        {
            "PHARMACY_SERVICE_TYPE_IDS": PHARMACY_SERVICE_TYPE_IDS,
            "ACTIVE_STATUS_ID": DOS_ACTIVE_STATUS_ID,
            "ODSCODE_STARTING_CHARACTER_CAPITALISED": starting_character.upper(),
            "ODSCODE_STARTING_CHARACTER": starting_character.lower(),
        },
    )
    odscodes = {odscode_row["left"] for odscode_row in cursor.fetchall()}
    cursor.close()
    logger.info(f"Found {len(odscodes)} pharmacy ODS codes.", odscodes=odscodes)
    return odscodes


def search_for_matching_services(connection: Connection, odscode: str) -> list[DoSService]:
    """Search for matching services in DoS DB using odscode.

    Args:
        connection (Connection): Connection to the DoS DB.
        odscode (str): Search for matching services using this odscode.

    Returns:
        list[DoSService]: List of matching services.
    """
    cursor = query_dos_db(
        connection,
        "SELECT s.id, uid, s.name, odscode, address, postcode, web, typeid,"
        "statusid, ss.name status_name, publicphone, publicname, st.name service_type_name "
        "FROM services s LEFT JOIN servicetypes st ON s.typeid = st.id "
        "LEFT JOIN servicestatuses ss on s.statusid = ss.id "
        "WHERE s.odscode LIKE %(ODSCODE)s AND s.statusid = %(ACTIVE_STATUS_ID)s "
        "AND s.typeid = ANY(%(PHARMACY_SERVICE_TYPE_IDS)s)",
        {
            "ODSCODE": f"{odscode}%",
            "ACTIVE_STATUS_ID": DOS_ACTIVE_STATUS_ID,
            "PHARMACY_SERVICE_TYPE_IDS": PHARMACY_SERVICE_TYPE_IDS,
        },
    )
    services = [DoSService(row) for row in cursor.fetchall()]
    cursor.close()
    logger.info(f"Found {len(services)} active matching services.", services=services)
    return services


def search_for_incorrectly_profiled_z_code_on_incorrect_type(
    connection: Connection,
    service_type: CommissionedServiceType,
) -> list[DoSService]:
    """Search for incorrectly profiled services in DoS DB on wrong service type.

    Args:
        connection (Connection): Connection to the DoS DB.
        service_type (CommissionedServiceType): Service type to check for.

    Returns:
        list[DoSService]: List of matching services.
    """
    matchable_service_types = PHARMACY_SERVICE_TYPE_IDS.copy()
    if service_type == PALLIATIVE_CARE:
        # Remove DSPs from check, as it's valid for the palliative z-code to be present on them
        matchable_service_types.remove(DISTANCE_SELLING_PHARMACY_ID)
    matchable_service_types.remove(service_type.DOS_TYPE_ID)
    starting_character = getenv("ODSCODE_STARTING_CHARACTER") or "f"
    cursor = query_dos_db(
        connection,
        "SELECT s.id, uid, s.name, odscode, address, postcode, web, typeid, statusid, ss.name status_name, "
        "publicphone, publicname, st.name service_type_name "
        "FROM services s LEFT JOIN servicetypes st ON s.typeid = st.id "
        "LEFT JOIN servicestatuses ss on s.statusid = ss.id "
        "LEFT JOIN servicesgsds sgsds on s.id = sgsds.serviceid "
        "WHERE sgsds.sgid = %(SYMPTOM_GROUP)s AND sgsds.sdid = %(SYMPTOM_DISCRIMINATOR)s "
        "AND s.statusid = %(ACTIVE_STATUS_ID)s AND s.typeid = ANY(%(SERVICE_TYPE_IDS)s) "
        "AND LEFT(s.odscode,1) in (%(ODSCODE_STARTING_CHARACTER_CAPITALISED)s, %(ODSCODE_STARTING_CHARACTER)s)",
        {
            "ACTIVE_STATUS_ID": DOS_ACTIVE_STATUS_ID,
            "SERVICE_TYPE_IDS": matchable_service_types,
            "SYMPTOM_GROUP": service_type.DOS_SYMPTOM_GROUP,
            "SYMPTOM_DISCRIMINATOR": service_type.DOS_SYMPTOM_DISCRIMINATOR,
            "ODSCODE_STARTING_CHARACTER_CAPITALISED": starting_character.upper(),
            "ODSCODE_STARTING_CHARACTER": starting_character.lower(),
        },
    )
    services = [DoSService(row) for row in cursor.fetchall()]
    cursor.close()
    logger.info(
        f"Found {len(services)} {service_type.TYPE_NAME} active offending services on incorrect type .",
        matchable_service_types=matchable_service_types,
        services=services,
    )
    return services


def search_for_incorrectly_profiled_z_code_on_correct_type(
    connection: Connection,
    service_type: CommissionedServiceType,
) -> list[DoSService]:
    """Search for incorrectly profiled services in DoS DB on correct service type.

    Args:
        connection (Connection): Connection to the DoS DB.
        service_type (CommissionedServiceType): Service type to check for.

    Returns:
        list[DoSService]: List of matching services.
    """
    starting_character = getenv("ODSCODE_STARTING_CHARACTER") or "f"
    cursor = query_dos_db(
        connection,
        "SELECT s.id, uid, s.name, odscode, address, postcode, web, typeid, statusid, ss.name status_name, "
        "publicphone, publicname, st.name service_type_name "
        "FROM services s LEFT JOIN servicetypes st ON s.typeid = st.id "
        "LEFT JOIN servicestatuses ss on s.statusid = ss.id "
        "LEFT JOIN servicesgsds sgsds on s.id = sgsds.serviceid "
        "WHERE sgsds.sgid = %(SYMPTOM_GROUP)s AND sgsds.sdid = %(SYMPTOM_DISCRIMINATOR)s "
        "AND s.statusid = %(ACTIVE_STATUS_ID)s AND s.typeid = ANY(%(SERVICE_TYPE_IDS)s) "
        "AND LEFT(s.odscode,1) in (%(ODSCODE_STARTING_CHARACTER_CAPITALISED)s, %(ODSCODE_STARTING_CHARACTER)s)"
        "AND LENGTH(s.odscode) > 5",
        {
            "ACTIVE_STATUS_ID": DOS_ACTIVE_STATUS_ID,
            "SERVICE_TYPE_IDS": [service_type.DOS_TYPE_ID],
            "SYMPTOM_GROUP": service_type.DOS_SYMPTOM_GROUP,
            "SYMPTOM_DISCRIMINATOR": service_type.DOS_SYMPTOM_DISCRIMINATOR,
            "ODSCODE_STARTING_CHARACTER_CAPITALISED": starting_character.upper(),
            "ODSCODE_STARTING_CHARACTER": starting_character.lower(),
        },
    )
    services = [DoSService(row) for row in cursor.fetchall()]
    cursor.close()
    logger.info(f"Found {len(services)} active offending services on correct type.", services=services)
    return services
