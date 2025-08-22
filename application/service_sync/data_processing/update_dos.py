from aws_lambda_powertools.logging import Logger
from psycopg import Connection
from psycopg.sql import SQL, Identifier, Literal

from ..service_update_logger import log_service_updates
from .changes_to_dos import ChangesToDoS
from .service_histories import ServiceHistories
from .validation import validate_z_code_exists, validate_z_code_exists_on_service
from common.constants import (
    DOS_ACTIVE_STATUS_ID,
    DOS_BLOOD_PRESSURE_SGSDID,
    DOS_BLOOD_PRESSURE_SYMPTOM_DISCRIMINATOR,
    DOS_BLOOD_PRESSURE_SYMPTOM_GROUP,
    DOS_BLOOD_PRESSURE_TYPE_ID,
    DOS_CLOSED_STATUS_ID,
    DOS_CONTRACEPTION_SGSDID,
    DOS_CONTRACEPTION_SYMPTOM_DISCRIMINATOR,
    DOS_CONTRACEPTION_SYMPTOM_GROUP,
    DOS_CONTRACEPTION_TYPE_ID,
    DOS_PALLIATIVE_CARE_SYMPTOM_DISCRIMINATOR,
    DOS_PALLIATIVE_CARE_SYMPTOM_GROUP,
)
from common.dos import DoSService
from common.dos_db_connection import connect_to_db_writer, query_dos_db
from common.opening_times import OpenPeriod, SpecifiedOpeningTime

logger = Logger(child=True)


def update_dos_data(changes_to_dos: ChangesToDoS, service_id: int, service_histories: ServiceHistories) -> None:
    """Updates the DoS database with the changes to the service.

    Args:
        changes_to_dos (ChangesToDoS): Changes to the dos service
        service_id (int): Id of service to update
        service_histories (ServiceHistories): Service history of the service
    """
    connection = None
    try:
        # Save all the changes to the DoS database with a single transaction
        with connect_to_db_writer() as connection:
            is_demographic_changes = save_demographics_into_db(
                connection=connection,
                service_id=service_id,
                demographics_changes=changes_to_dos.demographic_changes,
            )
            is_standard_opening_times_changes = save_standard_opening_times_into_db(
                connection=connection,
                service_id=service_id,
                standard_opening_times_changes=changes_to_dos.standard_opening_times_changes,
            )
            is_specified_opening_times_changes = save_specified_opening_times_into_db(
                connection=connection,
                service_id=service_id,
                is_changes=changes_to_dos.specified_opening_times_changes,
                specified_opening_times_changes=changes_to_dos.new_specified_opening_times,
            )
            is_palliative_care_changes = save_palliative_care_into_db(
                connection=connection,
                dos_service=changes_to_dos.dos_service,
                is_changes=changes_to_dos.palliative_care_changes,
                palliative_care=changes_to_dos.nhs_entity.palliative_care,
            )
            is_blood_pressure_changes, service_histories = save_blood_pressure_into_db(
                connection=connection,
                dos_service=changes_to_dos.dos_service,
                is_changes=changes_to_dos.blood_pressure_changes,
                blood_pressure=changes_to_dos.nhs_entity.blood_pressure,
                service_histories=service_histories,
            )
            is_contraception_changes, service_histories = save_contraception_into_db(
                connection=connection,
                dos_service=changes_to_dos.dos_service,
                is_changes=changes_to_dos.contraception_changes,
                contraception=changes_to_dos.nhs_entity.contraception,
                service_histories=service_histories,
            )
            # If there are any changes, update the service history and commit the changes to the database
            if any(
                [
                    is_demographic_changes,
                    is_standard_opening_times_changes,
                    is_specified_opening_times_changes,
                    is_palliative_care_changes,
                    is_blood_pressure_changes,
                    is_contraception_changes,
                ],
            ):
                service_histories.save_service_histories(connection=connection)
                connection.commit()
                logger.info(f"Updates successfully committed to the DoS database for service id {service_id}")
                log_service_updates(changes_to_dos=changes_to_dos, service_histories=service_histories)
            else:
                logger.info(f"No changes to save for service id {service_id}")
    finally:
        # Close the connection even if an error occurs
        if connection:
            # Close without committing causes the transaction to be rolled back
            connection.close()


def save_demographics_into_db(connection: Connection, service_id: int, demographics_changes: dict) -> bool:
    """Saves the demographic changes to the DoS database.

    Args:
        connection (connection): Connection to the DoS database
        service_id (int): Id of service to update
        demographics_changes (dict): Demographic changes to save

    Returns:
        bool: True if any demographic changes were saved, False otherwise
    """
    if demographics_changes:
        # Update the service demographics
        logger.info(
            f"Demographics changes found for service id {service_id}",
            demographics_changes=demographics_changes,
        )
        columns_and_values = [
            SQL("{} = {}").format(Identifier(key), Literal(value)).as_string(connection)
            for key, value in demographics_changes.items()
        ]
        query = SQL("""UPDATE services SET {} WHERE id = %(SERVICE_ID)s;""").format(SQL(", ".join(columns_and_values)))
        query_str = query.as_string(connection)
        cursor = query_dos_db(
            connection=connection,
            query=query_str,
            query_vars={"SERVICE_ID": service_id},
        )
        cursor.close()
        return True

    # No demographic changes found so no need to update the service
    logger.info(f"No demographic changes found for service id {service_id}")
    return False


def save_standard_opening_times_into_db(
    connection: Connection,
    service_id: int,
    standard_opening_times_changes: dict[int, list[OpenPeriod]],
) -> bool:
    """Saves the standard opening times changes to the DoS database.

    Args:
        connection (connection): Connection to the DoS database
        service_id (int): Id of the service to update
        standard_opening_times_changes (Dict[int, List[OpenPeriod]]): Changes to the standard opening times

    Returns:
        bool: True if changes were made to the database, False if no changes were made
    """
    if standard_opening_times_changes:
        logger.info(f"Saving standard opening times changes for service id {service_id}")
        for dayid, opening_periods in standard_opening_times_changes.items():
            logger.info(f"Deleting standard opening times for dayid: {dayid}")
            # Cascade delete the standard opening times in both
            # servicedayopenings table and servicedayopeningtimes table
            cursor = query_dos_db(
                connection=connection,
                query="""DELETE FROM servicedayopenings WHERE serviceid=%(SERVICE_ID)s AND dayid=%(DAY_ID)s""",
                query_vars={"SERVICE_ID": service_id, "DAY_ID": dayid},
            )
            cursor.close()
            if opening_periods != []:
                logger.info(f"Saving standard opening times for dayid: {dayid}")
                cursor = query_dos_db(
                    connection=connection,
                    query=(
                        """INSERT INTO servicedayopenings (serviceid, dayid) """
                        """VALUES (%(SERVICE_ID)s, %(DAY_ID)s) RETURNING id"""
                    ),
                    query_vars={"SERVICE_ID": service_id, "DAY_ID": dayid},
                )
                # Get the id of the newly created servicedayopenings entry by using the RETURNING clause
                service_day_opening_id = cursor.fetchone()["id"]
                cursor.close()

                open_period: OpenPeriod  # Type hint for the for loop
                for open_period in opening_periods:
                    logger.info(f"Saving standard opening times period for dayid: {dayid}, period: {open_period}")
                    cursor = query_dos_db(
                        connection=connection,
                        query=(
                            """INSERT INTO servicedayopeningtimes (servicedayopeningid, starttime, endtime) """
                            """VALUES (%(SERVICE_DAY_OPENING_ID)s, %(OPEN_PERIOD_START)s, %(OPEN_PERIOD_END)s);"""
                        ),
                        query_vars={
                            "SERVICE_DAY_OPENING_ID": service_day_opening_id,
                            "OPEN_PERIOD_START": open_period.start,
                            "OPEN_PERIOD_END": open_period.end,
                        },
                    )
                    cursor.close()
            else:
                logger.info(f"No standard opening times to add for dayid: {dayid}")
        return True
    logger.info(f"No standard opening times changes to save for service id {service_id}")
    return False


def save_specified_opening_times_into_db(
    connection: Connection,
    service_id: int,
    is_changes: bool,
    specified_opening_times_changes: list[SpecifiedOpeningTime],
) -> bool:
    """Saves the specified opening times changes to the DoS database.

    Args:
        connection (connection): Connection to the DoS database
        service_id (int): Id of the service to update
        is_changes (bool): True if changes should be made to the database, False if no changes need to be made
        specified_opening_times_changes (List[SpecifiedOpeningTime]): Changes to the specified opening times

    Returns:
        bool: True if changes were made to the database, False if no changes were made
    """
    if is_changes:
        logger.info(f"Deleting all specified opening times for service id {service_id}")
        # Cascade delete the standard opening times in both
        # servicedayopenings table and servicedayopeningtimes table
        cursor = query_dos_db(
            connection=connection,
            query=("""DELETE FROM servicespecifiedopeningdates WHERE serviceid=%(SERVICE_ID)s """),
            query_vars={"SERVICE_ID": service_id},
        )
        cursor.close()
        for specified_opening_times_day in specified_opening_times_changes:
            logger.info(f"Saving specified opening times for: {specified_opening_times_day}")
            cursor = query_dos_db(
                connection=connection,
                query=(
                    """INSERT INTO servicespecifiedopeningdates (date,serviceid) """
                    """VALUES (%(SPECIFIED_OPENING_TIMES_DATE)s,%(SERVICE_ID)s) RETURNING id;"""
                ),
                query_vars={"SPECIFIED_OPENING_TIMES_DATE": specified_opening_times_day.date, "SERVICE_ID": service_id},
            )
            # Get the id of the newly created servicedayopenings entry by using the RETURNING clause
            service_specified_opening_date_id = cursor.fetchone()["id"]
            cursor.close()
            if specified_opening_times_day.is_open:
                # If the day is open, save the potentially mutiple opening times
                open_period: OpenPeriod  # Type hint for the for loop
                for open_period in specified_opening_times_day.open_periods:
                    logger.debug(
                        "Saving specified opening times period for dayid: "
                        f"{specified_opening_times_day.date}, period: {open_period}",
                    )
                    cursor = query_dos_db(
                        connection=connection,
                        query=(
                            """INSERT INTO servicespecifiedopeningtimes """
                            """(starttime, endtime, isclosed, servicespecifiedopeningdateid) """
                            """VALUES (%(OPEN_PERIOD_START)s, %(OPEN_PERIOD_END)s,"""
                            """%(IS_CLOSED)s,%(SERVICE_SPECIFIED_OPENING_DATE_ID)s);"""
                        ),
                        query_vars={
                            "OPEN_PERIOD_START": open_period.start,
                            "OPEN_PERIOD_END": open_period.end,
                            "IS_CLOSED": not specified_opening_times_day.is_open,
                            "SERVICE_SPECIFIED_OPENING_DATE_ID": service_specified_opening_date_id,
                        },
                    )
                    cursor.close()
            else:
                # If the day is closed, save the single closed all day times
                cursor = query_dos_db(
                    connection=connection,
                    query=(
                        """INSERT INTO servicespecifiedopeningtimes """
                        """(starttime, endtime, isclosed, servicespecifiedopeningdateid) """
                        """VALUES ('00:00:00', '00:00:00',"""
                        """%(IS_CLOSED)s,%(SERVICE_SPECIFIED_OPENING_DATE_ID)s);"""
                    ),
                    query_vars={
                        "IS_CLOSED": not specified_opening_times_day.is_open,
                        "SERVICE_SPECIFIED_OPENING_DATE_ID": service_specified_opening_date_id,
                    },
                )
                cursor.close()

        return True
    logger.info(f"No specified opening times changes to save for service id {service_id}")
    return False


def save_sgsdid_update(
    name: str,
    value: bool,
    sdid: int,
    sgid: int,
    dos_service: DoSService,
    connection: Connection,
) -> None:
    """Saves the palliative care update to the DoS database.

    Args:
        name (str): The name of the change
        value (bool): True if the change is to set the value to be added, False if the change is to remove the value
        sdid (int): The symptom discriminator id
        sgid (int): The symptom group id
        dos_service (DoSService): The dos service to update
        connection (Connection): Connection to the DoS database

    Returns:
        None
    """
    query_vars = {
        "SERVICE_ID": dos_service.id,
        "SDID": sdid,
        "SGID": sgid,
    }

    if value:
        query = "INSERT INTO servicesgsds (serviceid, sdid, sgid) VALUES (%(SERVICE_ID)s, %(SDID)s, %(SGID)s);"
        logger.debug(f"Setting {name} to true for service id {dos_service.id}")
    else:
        query = "DELETE FROM servicesgsds WHERE serviceid=%(SERVICE_ID)s AND sdid=%(SDID)s AND sgid=%(SGID)s;"
        logger.debug(f"Setting {name} to false for service id {dos_service.id}")
    cursor = query_dos_db(connection=connection, query=query, query_vars=query_vars)
    cursor.close()
    logger.info(f"Saving {name} changes for service id {dos_service.id}", value=value)


def save_palliative_care_into_db(
    connection: Connection,
    dos_service: DoSService,
    is_changes: bool,
    palliative_care: bool,
) -> bool:
    """Saves the palliative care changes to the DoS database.

    Args:
        connection (connection): Connection to the DoS database
        dos_service (DoSService): The dos service to update
        is_changes (bool): True if changes should be made to the database, False if no changes need to be made
        palliative_care (bool): Set palliative care in db to true or false

    Returns:
        bool: True if changes were made to the database, False if no changes were made
    """
    # If no changes, return false
    if not is_changes:
        logger.info(
            f"No palliative care changes to save for service id {dos_service.id}",
            palliative_care_is_set_to=palliative_care,
        )
        return False

    if validate_z_code_exists(
        connection=connection,
        dos_service=dos_service,
        symptom_group_id=DOS_PALLIATIVE_CARE_SYMPTOM_GROUP,
        symptom_discriminator_id=DOS_PALLIATIVE_CARE_SYMPTOM_DISCRIMINATOR,
        z_code_alias="Palliative Care",
    ):
        save_sgsdid_update(
            name="palliative care",
            value=palliative_care,
            sdid=DOS_PALLIATIVE_CARE_SYMPTOM_DISCRIMINATOR,
            sgid=DOS_PALLIATIVE_CARE_SYMPTOM_GROUP,
            dos_service=dos_service,
            connection=connection,
        )
        return True

    logger.error(
        f"Unable to save palliative care changes for service id {dos_service.id} as the "
        "palliative care Z code does not exist in the DoS database",
        palliative_care_is_set_to=palliative_care,
        cloudwatch_metric_filter_matching_attribute="DoSPalliativeCareZCodeDoesNotExist",
    )
    return False


def save_blood_pressure_into_db(
    connection: Connection,
    dos_service: DoSService,
    is_changes: bool,
    blood_pressure: bool,
    service_histories: ServiceHistories,
) -> tuple[bool, ServiceHistories]:
    """Saves the blood pressure changes to the DoS database.

    Args:
        connection (connection): Connection to the DoS database
        dos_service (DoSService): The dos service to update
        is_changes (bool): True if changes should be made to the database, False if no changes need to be made
        blood_pressure (bool): Set blood pressure in db to true or false
        service_histories (ServiceHistories): Service history of the service

    Returns:
        bool: True if changes were made to the database, False if no changes were made
        service_histories (ServiceHistories): Service history of the service
    """

    def save_service_status_update() -> None:
        status = DOS_ACTIVE_STATUS_ID if blood_pressure else DOS_CLOSED_STATUS_ID
        query = "UPDATE services SET statusid=%(STATUS_ID)s WHERE id=%(SERVICE_ID)s;"
        cursor = query_dos_db(
            connection=connection,
            query=query,
            query_vars={"STATUS_ID": status, "SERVICE_ID": dos_service.id},
        )
        cursor.close()

    if dos_service.typeid != DOS_BLOOD_PRESSURE_TYPE_ID:
        logger.info(
            f"No blood pressure changes to save for service id {dos_service.id} as the "
            "service is not a blood pressure service",
            current_blood_pressure=blood_pressure,
        )
        return False, service_histories
    # If no changes, return false
    if not is_changes:
        logger.info(
            f"No blood pressure changes to save for service id {dos_service.id}",
            current_blood_pressure=blood_pressure,
        )
        return False, service_histories

    save_service_status_update()
    if blood_pressure and not validate_z_code_exists_on_service(
        connection=connection,
        dos_service=dos_service,
        symptom_group_id=DOS_BLOOD_PRESSURE_SYMPTOM_GROUP,
        symptom_discriminator_id=DOS_BLOOD_PRESSURE_SYMPTOM_DISCRIMINATOR,
        z_code_alias="Blood Pressure",
    ):
        if not validate_z_code_exists(
            connection=connection,
            dos_service=dos_service,
            symptom_group_id=DOS_BLOOD_PRESSURE_SYMPTOM_GROUP,
            symptom_discriminator_id=DOS_BLOOD_PRESSURE_SYMPTOM_DISCRIMINATOR,
            z_code_alias="Blood Pressure",
        ):
            logger.error(
                f"Unable to save z code blood pressure changes for service id {dos_service.id} as the "
                "blood pressure Z code does not exist in the DoS database",
                new_blood_pressure_status=blood_pressure,
                cloudwatch_metric_filter_matching_attribute="BloodPressureZCodeDoesNotExist",
            )
            return False, service_histories

        save_sgsdid_update(
            name="blood pressure",
            value=blood_pressure,
            sdid=DOS_BLOOD_PRESSURE_SYMPTOM_DISCRIMINATOR,
            sgid=DOS_BLOOD_PRESSURE_SYMPTOM_GROUP,
            dos_service=dos_service,
            connection=connection,
        )
        service_histories.add_sgsdid_change(
            sgsdid=DOS_BLOOD_PRESSURE_SGSDID,
            new_value=blood_pressure,
        )

    return True, service_histories


def save_contraception_into_db(
    connection: Connection,
    dos_service: DoSService,
    is_changes: bool,
    contraception: bool,
    service_histories: ServiceHistories,
) -> tuple[bool, ServiceHistories]:
    """Saves the contraception changes to the DoS database.

    Args:
        connection (connection): Connection to the DoS database
        dos_service (DoSService): The dos service to update
        is_changes (bool): True if changes should be made to the database, False if no changes need to be made
        contraception (bool): Set contraception in db to true or false
        service_histories (ServiceHistories): Service history of the service

    Returns:
        bool: True if changes were made to the database, False if no changes were made
        service_histories (ServiceHistories): Service history of the service
    """

    def save_service_status_update() -> None:
        status = DOS_ACTIVE_STATUS_ID if contraception else DOS_CLOSED_STATUS_ID
        query = "UPDATE services SET statusid=%(STATUS_ID)s WHERE id=%(SERVICE_ID)s;"
        cursor = query_dos_db(
            connection=connection,
            query=query,
            query_vars={"STATUS_ID": status, "SERVICE_ID": dos_service.id},
        )
        cursor.close()

    if dos_service.typeid != DOS_CONTRACEPTION_TYPE_ID:
        logger.info(
            f"No contraception changes to save for service id {dos_service.id} as the "
            "service is not a contraception service",
            current_contraception=contraception,
        )
        return False, service_histories
    # If no changes, return false
    if not is_changes:
        logger.info(
            f"No contraception changes to save for service id {dos_service.id}",
            current_contraception=contraception,
        )
        return False, service_histories

    save_service_status_update()
    if contraception and not validate_z_code_exists_on_service(
        connection=connection,
        dos_service=dos_service,
        symptom_group_id=DOS_CONTRACEPTION_SYMPTOM_GROUP,
        symptom_discriminator_id=DOS_CONTRACEPTION_SYMPTOM_DISCRIMINATOR,
        z_code_alias="Contraception",
    ):
        if not validate_z_code_exists(
            connection=connection,
            dos_service=dos_service,
            symptom_group_id=DOS_CONTRACEPTION_SYMPTOM_GROUP,
            symptom_discriminator_id=DOS_CONTRACEPTION_SYMPTOM_DISCRIMINATOR,
            z_code_alias="Contraception",
        ):
            logger.error(
                f"Unable to save z code contraception changes for service id {dos_service.id} as the "
                "contraception Z code does not exist in the DoS database",
                new_contraception_status=contraception,
                cloudwatch_metric_filter_matching_attribute="ContraceptionZCodeDoesNotExist",
            )
            return False, service_histories

        save_sgsdid_update(
            name="contraception",
            value=contraception,
            sdid=DOS_CONTRACEPTION_SYMPTOM_DISCRIMINATOR,
            sgid=DOS_CONTRACEPTION_SYMPTOM_GROUP,
            dos_service=dos_service,
            connection=connection,
        )
        service_histories.add_sgsdid_change(
            sgsdid=DOS_CONTRACEPTION_SGSDID,
            new_value=contraception,
        )

    return True, service_histories
