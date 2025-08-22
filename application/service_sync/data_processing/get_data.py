from aws_lambda_powertools.logging import Logger
from psycopg.rows import DictRow

from .service_histories import ServiceHistories
from common.dos import (
    DoSService,
    convent_db_to_standard_opening_times,
    convert_db_to_specified_opening_times,
    db_big_rows_to_spec_open_times,
    db_big_rows_to_std_open_times,
    has_blood_pressure,
    has_contraception,
    has_palliative_care,
)
from common.dos_db_connection import connect_to_db_writer, query_dos_db

logger = Logger(child=True)


def get_dos_service_and_history(service_id: int) -> tuple[DoSService, ServiceHistories]:
    """Retrieves DoS Services from DoS database.

    Args:
        service_id (str): Id of service to retrieve

    Returns:
        Tuple[DoSService, ServiceHistories]: Tuple of DoS service and service history

    """
    sql_query = (
        "SELECT s.id, uid, s.name, odscode, address, town, postcode, web, typeid, statusid, ss.name status_name, "
        "publicphone, publicname, st.name service_type_name, easting, northing, latitude, longitude FROM services s "
        "LEFT JOIN servicetypes st ON s.typeid = st.id LEFT JOIN servicestatuses ss on s.statusid = ss.id "
        "WHERE s.id = %(SERVICE_ID)s"
    )
    std_opening_times_query = (
        "SELECT sdo.serviceid, sdo.dayid, otd.name, sdot.starttime, sdot.endtime "
        "FROM servicedayopenings sdo "
        "INNER JOIN servicedayopeningtimes sdot "
        "ON sdo.id = sdot.servicedayopeningid "
        "LEFT JOIN openingtimedays otd "
        "ON sdo.dayid = otd.id "
        "WHERE sdo.serviceid = %(SERVICE_ID)s"
    )
    specified_op_times_query = (
        "SELECT ssod.serviceid, ssod.date, ssot.starttime, ssot.endtime, ssot.isclosed "
        "FROM servicespecifiedopeningdates ssod "
        "INNER JOIN servicespecifiedopeningtimes ssot "
        "ON ssod.id = ssot.servicespecifiedopeningdateid "
        "WHERE ssod.serviceid = %(SERVICE_ID)s"
    )

    query_vars = {"SERVICE_ID": service_id}
    # Connect to the DoS database
    with connect_to_db_writer() as connection, connection.pipeline() as p:
        # Query the DoS database for the service
        cursor_main = query_dos_db(connection=connection, query=sql_query, query_vars=query_vars)
        cursor_std_ot = query_dos_db(connection=connection, query=std_opening_times_query, query_vars=query_vars)
        cursor_sp_otd = query_dos_db(connection=connection, query=specified_op_times_query, query_vars=query_vars)
        p.sync()
        main_fetch = cursor_main.fetchone()
        std_ot_fetch = cursor_std_ot.fetchall()
        sp_otd_fetch = cursor_sp_otd.fetchall()

        if main_fetch is not None:
            # Select first row (service) and create DoSService object
            service = DoSService(main_fetch)
            logger.append_keys(service_name=service.name)
            logger.append_keys(service_uid=service.uid)
            logger.append_keys(type_id=service.typeid)
        elif main_fetch is None:
            msg = f"Service ID {service_id} not found"
            raise ValueError(msg)
        # Set up remaining service data
        service.standard_opening_times = convent_db_to_standard_opening_times(db_std_opening_times=std_ot_fetch)
        service.specified_opening_times = convert_db_to_specified_opening_times(db_specified_opening_times=sp_otd_fetch)

        # Set up palliative care flag
        service.palliative_care = has_palliative_care(service=service, connection=connection)
        # Set up blood pressure flag
        service.blood_pressure = has_blood_pressure(service=service)
        # Set up contraception flag
        service.contraception = has_contraception(service=service)
        # Set up service history
        service_histories = ServiceHistories(service_id=service_id)
        service_histories.get_service_history_from_db(connection)
        service_histories.create_service_histories_entry()
    # Connection closed by context manager
    return service, service_histories


def get_dos_service_and_history_one_query(service_id: int) -> tuple[DoSService, ServiceHistories]:
    """Retrieves DoS Services from DoS database.

    Args:
        service_id (str): Id of service to retrieve

    Returns:
        Tuple[DoSService, ServiceHistories]: Tuple of DoS service and service history

    """
    sql_query = (
        "SELECT s.id, uid, s.name, odscode, address, town, postcode, web, typeid, statusid, ss.name status_name, "
        "publicphone, publicname, st.name service_type_name, easting, northing, latitude, longitude, "
        'sdo.id as "sdo_id", sdo.dayid, otd.name, sdot.id as "sdot_id", sdot.starttime as "day_starttime", '
        'sdot.endtime as "day_endtime", ssod.id as "ssod_id", ssod.date, ssot.id as "ssot_id", '
        'ssot.starttime as "date_starttime", ssot.endtime as "date_endtime", ssot.isclosed '
        "FROM services s "
        "INNER JOIN servicetypes st ON s.typeid = st.id INNER JOIN servicestatuses ss on s.statusid = ss.id "
        "LEFT JOIN servicedayopenings sdo ON s.id = sdo.serviceid "
        "LEFT JOIN openingtimedays otd ON sdo.dayid = otd.id "
        "LEFT JOIN servicedayopeningtimes sdot ON sdo.id = sdot.servicedayopeningid "
        "LEFT JOIN servicespecifiedopeningdates ssod ON s.id = ssod.serviceid "
        "LEFT JOIN servicespecifiedopeningtimes ssot ON ssod.id = ssot.servicespecifiedopeningdateid "
        "WHERE s.id = %(SERVICE_ID)s"
    )
    query_vars = {"SERVICE_ID": service_id}
    # Connect to the DoS database
    with connect_to_db_writer() as connection:
        # Query the DoS database for the service
        cursor = query_dos_db(connection=connection, query=sql_query, query_vars=query_vars)
        rows: DictRow = cursor.fetchall()
        if len(rows) >= 1:
            # Select first row (service) and create DoSService object
            service = DoSService(rows[0])
            logger.append_keys(service_name=service.name)
            logger.append_keys(service_uid=service.uid)
            logger.append_keys(type_id=service.typeid)
        elif not rows:
            msg = f"Service ID {service_id} not found"
            raise ValueError(msg)
        # Set up remaining service data
        service.standard_opening_times = db_big_rows_to_std_open_times(rows)
        service.specified_opening_times = db_big_rows_to_spec_open_times(rows)
        # Set up palliative care flag
        service.palliative_care = has_palliative_care(service=service, connection=connection)
        # Set up blood pressure flag
        service.blood_pressure = has_blood_pressure(service=service)
        # Set up contraception flag
        service.contraception = has_contraception(service=service)
        # Set up service history
        service_histories = ServiceHistories(service_id=service_id)
        service_histories.get_service_history_from_db(connection)
        service_histories.create_service_histories_entry()
        # Connection closed by context manager
    return service, service_histories
