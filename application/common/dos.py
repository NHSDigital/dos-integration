from collections.abc import Iterable
from dataclasses import dataclass, fields
from itertools import groupby
from typing import Self

from aws_lambda_powertools.logging import Logger
from psycopg import Connection
from psycopg.rows import DictRow

from .constants import (
    DOS_ACTIVE_STATUS_ID,
    DOS_CLOSED_STATUS_ID,
    DOS_COMMISSIONING_STATUS_ID,
    DOS_PALLIATIVE_CARE_SYMPTOM_DISCRIMINATOR,
    DOS_PALLIATIVE_CARE_SYMPTOM_GROUP,
    PHARMACY_SERVICE_TYPE_IDS,
)
from .dos_db_connection import connect_to_db_reader, query_dos_db
from .dos_location import DoSLocation
from .opening_times import OpenPeriod, SpecifiedOpeningTime, StandardOpeningTimes
from common.commissioned_service_type import BLOOD_PRESSURE, CONTRACEPTION, CommissionedServiceType

logger = Logger(child=True)
dos_location_cache = {}


@dataclass
class DoSService:
    """Class to represent a DoS Service."""

    id: int
    uid: int
    name: str
    odscode: str
    address: str
    town: str
    postcode: str
    web: str
    typeid: int
    statusid: int
    status_name: str
    publicphone: str
    publicname: str
    service_type_name: str
    easting: int
    northing: int
    latitude: float
    longitude: float
    region: str = ""

    @staticmethod
    def field_names() -> list[str]:
        """Returns a list of field names for this class."""
        return [f.name for f in fields(DoSService)]

    def __init__(self: Self, db_cursor_row: dict) -> Self:
        """Sets the attributes of this object to those found in the db row.

        Args:
            db_cursor_row (dict): row from db as key/val pairs.
        """
        for row_key, row_value in db_cursor_row.items():
            setattr(self, row_key, row_value)

        self.standard_opening_times = None
        self.specified_opening_times = None
        self.palliative_care = False
        self.blood_pressure = False
        self.contraception = False

    def __repr__(self: Self) -> str:
        """Returns a string representation of this object."""
        if self.publicname is not None:
            name = self.publicname
        elif self.name is not None:
            name = self.name
        else:
            name = "NO-VALID-NAME"

        return (
            f"<DoSService: name='{name[:16]}' id={self.id} uid={self.uid} "
            f"odscode={self.odscode} type={self.typeid} status={self.statusid}>"
        )

    def __eq__(self: Self, other) -> bool:  # noqa: ANN001
        """Checks DoS service equality using service id.

        Args:
            other (DoSService): DoS service to compare too

        Returns:
            bool: True if equal, False if not
        """
        return self.id == other.id

    def normal_postcode(self: Self) -> str:
        """Returns the postcode with no spaces and in uppercase."""
        return self.postcode.replace(" ", "").upper()

    def any_generic_bankholiday_open_periods(self: Self) -> bool:
        """Returns True if any of the opening times are generic bank holiday opening times."""
        return len(self.standard_opening_times.generic_bankholiday) > 0

    def get_region(self: Self) -> str:
        """Returns the region of the service."""
        if not self.region:
            self.region = get_region(self.id)
        return self.region


def get_matching_dos_services(odscode: str) -> list[DoSService]:
    """Retrieves DoS Services from DoS database.

    Args:
        odscode (str): ODScode to match on

    Returns:
        list[DoSService]: List of DoSService objects with matching first 5
        digits of odscode, taken from DoS database
    """
    named_args = {
        "ODS": f"{odscode[:5]}%",
        "PHARMACY_SERVICE_TYPE_IDS": [13, 131, 132, 134, 137],
        "ACTIVE_STATUS_ID": DOS_ACTIVE_STATUS_ID,
        "PHARMACY_FIRST_SERVICE_TYPE_IDS": [148, 149],
        "PHARMACY_FIRST_STATUSES": [DOS_ACTIVE_STATUS_ID, DOS_CLOSED_STATUS_ID, DOS_COMMISSIONING_STATUS_ID],
    }
    sql_query = (
        "SELECT s.id, uid, s.name, odscode, address, postcode, web, typeid,"
        "statusid, ss.name status_name, publicphone, publicname, st.name service_type_name "
        "FROM services s LEFT JOIN servicetypes st ON s.typeid = st.id "
        "LEFT JOIN servicestatuses ss on s.statusid = ss.id "
        "WHERE s.odscode LIKE %(ODS)s AND s.typeid = ANY(%(PHARMACY_SERVICE_TYPE_IDS)s) "
        "AND s.statusid = %(ACTIVE_STATUS_ID)s OR s.odscode LIKE %(ODS)s "
        "AND s.typeid = ANY(%(PHARMACY_FIRST_SERVICE_TYPE_IDS)s) AND s.statusid = ANY(%(PHARMACY_FIRST_STATUSES)s)"
    )
    with connect_to_db_reader() as connection:
        cursor = query_dos_db(connection=connection, query=sql_query, query_vars=named_args)
        # Create list of DoSService objects from returned rows
        services = [DoSService(row) for row in cursor.fetchall()]
        cursor.close()
        # Connection closed by context manager
    return services


def get_dos_locations(postcode: str | None = None, try_cache: bool = True) -> list[DoSLocation]:
    """Retrieves DoS Locations from DoS database.

    Args:
        postcode (str, optional): Postcode to match on. Defaults to None.
        try_cache (bool, optional): Whether to try and use the local cache. Defaults to True.

    Returns:
        list[DoSLocation]: List of DoSLocation objects with matching postcode, taken from DoS database
    """
    logger.debug(f"Searching for DoS locations with postcode of '{postcode}'")
    norm_pc = postcode.replace(" ", "").upper()
    global dos_location_cache  # noqa: PLW0602
    if try_cache and norm_pc in dos_location_cache:
        logger.info(f"Postcode {norm_pc} location/s found in local cache.")
        return dos_location_cache[norm_pc]

    # Search for any variation of whitespace in postcode
    postcode_variations = [norm_pc] + [f"{norm_pc[:i]} {norm_pc[i:]}" for i in range(1, len(norm_pc))]
    db_column_names = [f.name for f in fields(DoSLocation)]
    sql_command = (
        f"SELECT {', '.join(db_column_names)} FROM locations WHERE postcode = ANY(%(pc_variations)s)"  # noqa: S608
        # Safe as conditional is configurable but variables is inputted to psycopg as variables
    )

    with connect_to_db_reader() as connection:
        cursor = query_dos_db(
            connection=connection,
            query=sql_command,
            query_vars={"pc_variations": postcode_variations},
        )
        dos_locations = [DoSLocation(**row) for row in cursor.fetchall()]
        cursor.close()
    dos_location_cache[norm_pc] = dos_locations
    logger.debug(f"Postcode location/s for {norm_pc} added to local cache.")

    return dos_locations


def get_valid_dos_location(postcode: str) -> DoSLocation | None:
    """Gets the valid DoS location for the given postcode.

    Args:
        postcode (str): The postcode to search for.

    Returns:
        Optional[DoSLocation]: The valid DoS location for the given postcode or None if no valid location is found.
    """
    dos_locations = [loc for loc in get_dos_locations(postcode) if loc.is_valid()]
    return dos_locations[0] if dos_locations else None


def get_specified_opening_times_from_db(connection: Connection, service_id: int) -> list[SpecifiedOpeningTime]:
    """Retrieves specified opening times from  DoS database.

    Args:
        connection (Connection): Connection to DoS database
        service_id (int): serviceid to match on

    Returns:
        List[SpecifiedOpeningTime]: List of Specified Opening times with
        matching serviceid
    """
    logger.debug(f"Searching for specified opening times with serviceid that matches '{service_id}'")

    sql_query = (
        "SELECT ssod.serviceid, ssod.date, ssot.starttime, ssot.endtime, ssot.isclosed "
        "FROM servicespecifiedopeningdates ssod "
        "INNER JOIN servicespecifiedopeningtimes ssot "
        "ON ssod.id = ssot.servicespecifiedopeningdateid "
        "WHERE ssod.serviceid = %(SERVICE_ID)s"
    )
    named_args = {"SERVICE_ID": service_id}
    cursor = query_dos_db(connection=connection, query=sql_query, query_vars=named_args)
    specified_opening_times = db_rows_to_spec_open_times(cursor.fetchall())
    cursor.close()
    return specified_opening_times


def convert_db_to_specified_opening_times(db_specified_opening_times: list[DictRow]) -> list[SpecifiedOpeningTime]:
    """Retrieves specified opening times from  DoS database."""
    return db_rows_to_spec_open_times(db_specified_opening_times)


def get_standard_opening_times_from_db(connection: Connection, service_id: int) -> StandardOpeningTimes:
    """Retrieves standard opening times from DoS database.

    If the service id does not even match any service this function will still return a blank StandardOpeningTime
    with no opening periods.
    """
    logger.debug(f"Searching for standard opening times with serviceid that matches '{service_id}'")
    sql_command = (
        "SELECT sdo.serviceid, sdo.dayid, otd.name, sdot.starttime, sdot.endtime "
        "FROM servicedayopenings sdo "
        "INNER JOIN servicedayopeningtimes sdot "
        "ON sdo.id = sdot.servicedayopeningid "
        "LEFT JOIN openingtimedays otd "
        "ON sdo.dayid = otd.id "
        "WHERE sdo.serviceid = %(SERVICE_ID)s"
    )
    named_args = {"SERVICE_ID": service_id}
    cursor = query_dos_db(connection=connection, query=sql_command, query_vars=named_args)
    standard_opening_times = db_rows_to_std_open_times(cursor.fetchall())
    cursor.close()
    return standard_opening_times


def convent_db_to_standard_opening_times(db_std_opening_times: list[DictRow]) -> StandardOpeningTimes:
    """Retrieves standard opening times from DoS database.

    If the service id does not even match any service this function will still return a blank StandardOpeningTime
    with no opening periods.
    """
    return db_rows_to_std_open_times(db_std_opening_times)


def db_rows_to_spec_open_times(db_rows: Iterable[dict]) -> list[SpecifiedOpeningTime]:
    """Turns a set of dos database rows into a list of SpecifiedOpenTime objects.

    note: The rows must to be for the same service.
    """
    specified_opening_times = []
    date_sorted_rows = sorted(db_rows, key=lambda row: (row["date"], row["starttime"]))
    for date, rows in groupby(date_sorted_rows, lambda row: row["date"]):
        is_open = True
        open_periods = []
        for row in list(rows):
            if row["isclosed"] is True:
                is_open = False
            else:
                open_periods.append(OpenPeriod(row["starttime"], row["endtime"]))
        specified_opening_times.append(SpecifiedOpeningTime(open_periods, date, is_open))

    return specified_opening_times


def db_big_rows_to_spec_open_times(db_rows: Iterable[dict]) -> list[SpecifiedOpeningTime]:
    """Turns a set of dos database rows into a list of SpecifiedOpenTime objects.

    note: The rows must to be for the same service.
    """
    specified_opening_times = []
    specified_op_times_ids = []
    db_rows_refined = []
    for row in list(db_rows):
        if row["ssot_id"] is not None and row["ssot_id"] not in specified_op_times_ids:
            specified_op_times_ids.append(row["ssot_id"])
            db_rows_refined.append(row)
    date_sorted_rows = sorted(db_rows_refined, key=lambda row: (row["date"], row["date_starttime"]))
    for date, db_rows_refined in groupby(date_sorted_rows, lambda row: row["date"]):
        is_open = True
        open_periods = []
        for row in list(db_rows_refined):
            if row["isclosed"] is True:
                is_open = False
            else:
                open_periods.append(OpenPeriod(row["date_starttime"], row["date_endtime"]))
        specified_opening_times.append(SpecifiedOpeningTime(open_periods, date, is_open))

    return specified_opening_times


def db_rows_to_std_open_times(db_rows: Iterable[dict]) -> StandardOpeningTimes:
    """Turns a set of dos database rows into a StandardOpeningTime object.

    note: The rows must be for the same service.
    """
    standard_opening_times = StandardOpeningTimes()
    for row in db_rows:
        weekday = row["name"].lower()
        start = row["starttime"]
        end = row["endtime"]
        open_period = OpenPeriod(start, end)
        standard_opening_times.add_open_period(open_period, weekday)
    return standard_opening_times


def db_big_rows_to_std_open_times(db_rows: Iterable[dict]) -> StandardOpeningTimes:
    """Turns a set of dos database rows into a StandardOpeningTime object.

    note: The rows must be for the same service.
    """
    standard_opening_times = StandardOpeningTimes()
    std_op_times_ids = []
    for row in db_rows:
        if row["sdot_id"] is not None and row["sdot_id"] not in std_op_times_ids:
            std_op_times_ids.append(row["sdot_id"])
            weekday = row["name"].lower()
            start = row["day_starttime"]
            end = row["day_endtime"]
            open_period = OpenPeriod(start, end)
            standard_opening_times.add_open_period(open_period, weekday)
    return standard_opening_times


def has_palliative_care(service: DoSService, connection: Connection) -> bool:
    """Checks if a service has palliative care.

    Args:
        service: The service to check
        connection: The database connection to use

    Returns:
        True if the service has palliative care, False otherwise
    """
    if service.typeid in PHARMACY_SERVICE_TYPE_IDS:
        sql_command = """SELECT sgsds.id as z_code from servicesgsds sgsds
            WHERE sgsds.serviceid = %(SERVICE_ID)s
            AND sgsds.sgid = %(PALLIATIVE_CARE_SYMPTOM_GROUP)s
            AND sgsds.sdid  = %(PALLIATIVE_CARE_SYMPTOM_DISCRIMINATOR)s
            """
        named_args = {
            "SERVICE_ID": service.id,
            "PALLIATIVE_CARE_SYMPTOM_GROUP": DOS_PALLIATIVE_CARE_SYMPTOM_GROUP,
            "PALLIATIVE_CARE_SYMPTOM_DISCRIMINATOR": DOS_PALLIATIVE_CARE_SYMPTOM_DISCRIMINATOR,
        }
        cursor = query_dos_db(connection=connection, query=sql_command, query_vars=named_args)
        cursor.fetchall()
        logger.debug("Checked if service has palliative care", has_palliative_care=cursor.rowcount != 0)
        return cursor.rowcount != 0
    return False


def has_blood_pressure(service: DoSService) -> bool:
    """Checks if a service has blood pressure.

    Args:
        service: The service to check

    Returns:
        True if the service has blood pressure, False otherwise
    """
    return has_service(service, BLOOD_PRESSURE)


def has_contraception(service: DoSService) -> bool:
    """Checks if a service has contraception.

    Args:
        service: The service to check

    Returns:
        True if the service has contraception, False otherwise
    """
    return has_service(service, CONTRACEPTION)


def has_service(service: DoSService, service_type: CommissionedServiceType) -> bool:
    """Checks if a service has a given service type.

    Args:
        service: The service to check
        service_type: The service type to check for

    Returns:
        True if the service has the given service type, False otherwise
    """
    if service.typeid == service_type.DOS_TYPE_ID:
        status = service.statusid == DOS_ACTIVE_STATUS_ID
        logger.debug("Checked if service has {service_type.TYPE_NAME.lower()}", service_status=status)
        return status
    return False


def get_region(dos_service_id: str) -> str:
    """Returns the region of the service.

    Args:
        dos_service_id: The id of the service

    Returns:
        The region of the service
    """
    with connect_to_db_reader() as connection:
        logger.debug("Getting region for service")
        sql_command = """WITH
RECURSIVE servicetree as
(SELECT ser.parentid, ser.id, ser.uid, ser.name, 1 AS lvl
FROM services ser where ser.id = %(SERVICE_ID)s
UNION ALL
SELECT ser.parentid, st.id, ser.uid, ser.name, lvl+1 AS lvl
FROM services ser
INNER JOIN servicetree st ON ser.id = st.parentid),
serviceregion as
(SELECT st.*, ROW_NUMBER() OVER (PARTITION BY st.id ORDER BY st.lvl desc) rn
FROM servicetree st)
SELECT sr.name region
FROM serviceregion sr
INNER JOIN services ser ON sr.id = ser.id
LEFT OUTER JOIN services par ON ser.parentid = par.id
WHERE sr.rn=1
ORDER BY ser.name
    """
        named_args = {"SERVICE_ID": dos_service_id}
        cursor = query_dos_db(connection=connection, query=sql_command, query_vars=named_args)
        region_response = cursor.fetchone()
        region_name = region_response["region"] if region_response else "Region not found"
        logger.debug("Got region for service", region_name=region_name)
        cursor.close()
    return region_name
