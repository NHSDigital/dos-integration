import ast
import datetime
from copy import copy
from datetime import datetime as dt
from decimal import Decimal
from json import loads
from os import getenv
from random import randint
from time import sleep

from faker import Faker
from pytest_bdd import given, scenarios, then, when
from pytest_bdd.parsers import parse

from .utilities.aws import get_logs, negative_log_check
from .utilities.change_event_builder import (
    ChangeEventBuilder,
    build_same_as_dos_change_event,
    set_opening_times_change_event,
    valid_change_event,
)
from .utilities.context import Context
from .utilities.utils import (
    check_contact_delete_in_dos,
    check_received_data_in_dos,
    check_specified_received_opening_times_date_in_dos,
    check_specified_received_opening_times_time_in_dos,
    check_standard_received_opening_times_time_in_dos,
    confirm_approver_status,
    confirm_changes,
    generate_correlation_id,
    generate_random_int,
    get_change_event_specified_opening_times,
    get_change_event_standard_opening_times,
    get_changes,
    get_latest_sequence_id_for_a_given_odscode,
    get_odscode_with_contact_data,
    get_service_id,
    get_service_type_data,
    get_service_type_from_cr,
    get_stored_events_from_dynamo_db,
    process_change_request_payload,
    process_payload,
    process_payload_with_sequence,
    re_process_payload,
    remove_opening_days,
    time_to_sec,
)

scenarios(
    "../features/F001_Valid_Change_Events.feature",
    "../features/F002_Invalid_Change_Events.feature",
    "../features/F003_DoS_Security.feature",
    "../features/F004_Error_Handling.feature",
    "../features/F005_Support_Functions.feature",
    "../features/F006_Opening_times.feature",
)
FAKER = Faker("en_GB")


@given(parse('a Changed Event with changed "{contact}" is valid'), target_fixture="context")
def a_changed_contact_event_is_valid(contact: str, context: Context):
    context.change_event = ChangeEventBuilder("pharmacy").build_change_event_from_default()
    validated = False
    while validated is False:
        match contact:
            case "website":
                context.change_event.website = FAKER.domain_word() + ".nhs.uk"
            case "phone_no":
                context.change_event.phone = FAKER.phone_number()
            case "address":
                context.change_event.address_line_1 = FAKER.street_name()
            case _:
                raise ValueError(f"ERROR!.. Input parameter '{contact}' not compatible")

        validated = valid_change_event(context.change_event)
    return context


@given(parse('a Changed Event with a "{data}" value for "{contact_field}"'), target_fixture="context")
def a_valid_changed_event_with_empty_contact(data, contact_field, context: Context):
    def get_value_from_data():

        match data:
            case "None":
                return None
            case "''":
                return ""
            case _:
                return data

    context.change_event = build_same_as_dos_change_event("pharmacy")
    context.change_event.organisation_name = f"Test Service {get_value_from_data()}"
    context.change_event.website = None
    context.change_event.phone = None
    if context.correlation_id is None:
        run_id = getenv("RUN_ID")
        unique_key = generate_random_int()
        context.correlation_id = f"{run_id}_{unique_key}_contact_data_alignment_run"
    context.response = process_payload(context.change_event, True, context.correlation_id)
    assert confirm_approver_status(context.correlation_id) != []
    match contact_field:
        case "website":
            context.change_event.website = get_value_from_data()
        case "phone_no":
            context.change_event.phone = get_value_from_data()
        case "organisation_name":
            context.change_event.organisation_name = get_value_from_data()
        case _:
            raise ValueError(f"ERROR!.. Input parameter '{contact_field}' not compatible")
    context.correlation_id = None
    return context


@given("a specific Changed Event is valid", target_fixture="context")
def a_specific_change_event_is_valid(context: Context):
    context.change_event = set_opening_times_change_event("pharmacy")
    return context


@given("an opened specified opening time Changed Event is valid", target_fixture="context")
def a_specified_opening_time_change_event_is_valid(context: Context):
    closing_time = datetime.datetime.now().time().strftime("%H:%M")
    context.change_event = set_opening_times_change_event("pharmacy")
    context.change_event.specified_opening_times[-1]["OpeningTime"] = "00:01"
    context.change_event.specified_opening_times[-1]["ClosingTime"] = closing_time
    context.change_event.specified_opening_times[-1]["IsOpen"] = True
    return context


@given("an opened standard opening time Changed Event is valid", target_fixture="context")
def a_standard_opening_time_change_event_is_valid(context: Context):
    closing_time = datetime.datetime.now().time().strftime("%H:%M")
    context.change_event = set_opening_times_change_event("pharmacy")
    context.change_event.standard_opening_times[-1]["Weekday"] = "Monday"
    context.change_event.standard_opening_times[-1]["OpeningTime"] = "00:01"
    context.change_event.standard_opening_times[-1]["ClosingTime"] = closing_time
    context.change_event.standard_opening_times[-1]["IsOpen"] = True
    return context


@given(parse('a "{org_type}" Changed Event is aligned with Dos'), target_fixture="context")
def dos_event_from_scratch(org_type: str, context: Context):
    if org_type.lower() in ["pharmacy", "dentist"]:
        context.change_event = build_same_as_dos_change_event(org_type)
        return context
    else:
        raise ValueError(f"Invalid event type '{org_type}' provided")


@given(parse('a Changed Event to unset "{contact}"'), target_fixture="context")
def a_change_event_is_valid_with_contact_set(contact: str, context: Context):
    context.change_event = ChangeEventBuilder("pharmacy").build_same_as_dos_change_event_by_ods(
        get_odscode_with_contact_data()
    )
    match contact.lower():
        case "website":
            context.change_event.website = None
        case "phone":
            context.change_event.phone = None
        case _:
            raise ValueError(f"Invalid contact '{contact}' provided")
    return context


@given(parse('the field "{field}" is set to "{value}"'), target_fixture="context")
def generic_event_config(context: Context, field: str, value: str):
    match field.lower():
        case "website":
            context.change_event.website = value
        case "phone":
            context.change_event.phone = value
        case "odscode":
            context.change_event.odscode = value
        case "postcode":
            context.change_event.postcode = value
        case "organisationstatus":
            context.change_event.organisation_status = value
        case "organisationtypeid":
            context.change_event.organisation_type_id = value
        case "organisationsubtype":
            context.change_event.organisation_sub_type = value
    return context


@given("the Changed Event has overlapping opening times", target_fixture="context")
def change_event_with_overlapping_opening_times(context: Context):
    context.change_event.standard_opening_times[0]["ClosingTime"] = "12:00"
    context.change_event.standard_opening_times[1]["Weekday"] = "Monday"
    context.change_event.standard_opening_times[1]["OpeningTime"] = "11:00"
    return context


@given("the Changed Event has one break in opening times", target_fixture="context")
def change_event_with_break_in_opening_times(context: Context):
    context.change_event.standard_opening_times[0]["ClosingTime"] = "11:00"
    context.change_event.standard_opening_times[1]["Weekday"] = "Monday"
    context.change_event.standard_opening_times[1]["OpeningTime"] = "12:00"
    return context


@given("the Changed Event has two breaks in opening times", target_fixture="context")
def change_event_with_two_breaks_in_opening_times(context: Context):
    deletions = []
    for count, times in enumerate(context.change_event.standard_opening_times):
        if times["Weekday"] == "Monday":
            deletions.insert(0, count)
    for entries in deletions:
        del context.change_event.standard_opening_times[entries]
    default_openings = {
        "Weekday": "Monday",
        "OpeningTime": "09:00",
        "ClosingTime": "22:00",
        "OffsetOpeningTime": 540,
        "OffsetClosingTime": 780,
        "OpeningTimeType": "General",
        "AdditionalOpeningDate": "",
        "IsOpen": True,
    }
    context.change_event.standard_opening_times.insert(0, copy(default_openings))
    context.change_event.standard_opening_times.insert(1, copy(default_openings))
    context.change_event.standard_opening_times.insert(2, copy(default_openings))
    context.change_event.standard_opening_times[0]["ClosingTime"] = "11:00"
    context.change_event.standard_opening_times[1]["Weekday"] = "Monday"
    context.change_event.standard_opening_times[1]["OpeningTime"] = "12:00"
    context.change_event.standard_opening_times[1]["ClosingTime"] = "14:00"
    context.change_event.standard_opening_times[2]["Weekday"] = "Monday"
    context.change_event.standard_opening_times[2]["OpeningTime"] = "16:00"
    return context


@given(parse('the Changed Event contains a specified opening date that is "{open_closed}"'), target_fixture="context")
def one_off_opening_date_set(context: Context, open_closed: str):
    selected_day = randint(10, 30)
    match open_closed.lower():
        case "open":
            context.change_event.specified_opening_times = [
                {
                    "OpeningTime": "09:00",
                    "ClosingTime": "17:00",
                    "OpeningTimeType": "Additional",
                    "AdditionalOpeningDate": f"Dec {selected_day} 2025",
                    "IsOpen": True,
                }
            ]
        case "closed":
            context.change_event.specified_opening_times = [
                {
                    "OpeningTime": "",
                    "ClosingTime": "",
                    "OpeningTimeType": "Additional",
                    "AdditionalOpeningDate": f"Dec {selected_day} 2025",
                    "IsOpen": False,
                }
            ]
        case _:
            raise ValueError("Invalid opening value provided")
    return context


@given("the Changed Event closes the pharmacy on a bank holiday", target_fixture="context")
def bank_holiday_pharmacy_closed(context: Context):
    next_year = dt.now().year + 1
    context.change_event.specified_opening_times = [
        {
            "OpeningTime": "",
            "ClosingTime": "",
            "OpeningTimeType": "Additional",
            "AdditionalOpeningDate": f"Dec 25 {next_year}",
            "IsOpen": False,
        }
    ]
    return context


# Weekday NOT present on the Opening Time
@given("a Changed Event with the Weekday NOT present in the Opening Times data", target_fixture="context")
def a_change_event_with_no_openingtimes_weekday(context: Context):
    context.change_event = ChangeEventBuilder("pharmacy").build_change_event_from_default()
    del context.change_event.standard_opening_times[0]["Weekday"]
    return context


# OpeningTimeType is NOT "General" or "Additional"
@given("a Changed Event where OpeningTimeType is NOT defined correctly", target_fixture="context")
def a_change_event_with_invalid_openingtimetype(context: Context):
    context.change_event = ChangeEventBuilder("pharmacy").build_change_event_from_default()
    context.change_event.standard_opening_times[0]["OpeningTimeType"] = "F8k3"
    return context


# set correlation id to contain "Bad Request"
@given(parse('the correlation-id is "{custom_correlation}"'), target_fixture="context")
def a_custom_correlation_id_is_set(context: Context, custom_correlation: str):
    context.correlation_id = generate_correlation_id(custom_correlation)
    return context


# isOpen is false AND Times in NOT blank
@given("a Changed Event with the openingTimes IsOpen status set to false", target_fixture="context")
def a_change_event_with_isopen_status_set_to_false(context: Context):
    context.change_event = ChangeEventBuilder("pharmacy").build_change_event_from_default()
    context.change_event.standard_opening_times[0]["IsOpen"] = False
    return context


@given(parse('the Changed Event has equal "{opening_type}" values'), target_fixture="context")
def change_event_same_dual(context: Context, opening_type):
    default_openings = {
        "Weekday": "Monday",
        "OpeningTime": "09:00",
        "ClosingTime": "22:00",
        "OffsetOpeningTime": 540,
        "OffsetClosingTime": 780,
        "OpeningTimeType": opening_type,
        "AdditionalOpeningDate": "",
        "IsOpen": True,
    }
    if opening_type == "Additional":
        default_openings["Weekday"] = ""
        default_openings["AdditionalOpeningDate"] = "Dec 15 2025"
        context.change_event.specified_opening_times.insert(0, copy(default_openings))
        context.change_event.specified_opening_times.insert(1, copy(default_openings))
        context.change_event.specified_opening_times[0]["ClosingTime"] = "14:00"
        context.change_event.specified_opening_times[1]["OpeningTime"] = "14:00"
    else:
        context.change_event.standard_opening_times = remove_opening_days(
            context.change_event.standard_opening_times, "Monday"
        )
        context.change_event.standard_opening_times.insert(0, copy(default_openings))
        context.change_event.standard_opening_times.insert(1, copy(default_openings))
        context.change_event.standard_opening_times[0]["ClosingTime"] = "14:00"
        context.change_event.standard_opening_times[1]["OpeningTime"] = "14:00"
    return context


# Check that the requested ODS code exists in ddb, and create an entry if not
@given("an ODS has an entry in dynamodb", target_fixture="context")
def current_ods_exists_in_ddb(context: Context):
    context.change_event = build_same_as_dos_change_event("pharmacy")
    odscode = context.change_event.odscode
    if get_latest_sequence_id_for_a_given_odscode(odscode) == 0:
        context = the_change_event_is_sent_with_custom_sequence(context, 100)
        context.sequence_number = 100
    context.change_event.unique_key = generate_random_int()
    return context


@given(parse('a Changed Event with changed "{url}" variations is valid'), target_fixture="context")
def a_changed_url_event_is_valid(url: str, context: Context):
    context.change_event = build_same_as_dos_change_event("pharmacy")
    context.change_event.website = url
    context.change_event.postcode = "NG5 2JJ"
    return context


# IsOpen is true AND Times is blank
@when("the OpeningTimes Opening and Closing Times data are not defined", target_fixture="context")
def no_times_data_within_openingtimes(context: Context):
    context.change_event = ChangeEventBuilder("pharmacy").build_change_event_from_default()
    context.change_event.standard_opening_times[0]["OpeningTime"] = ""
    context.change_event.standard_opening_times[0]["ClosingTime"] = ""
    return context


# OpeningTimeType is Additional AND AdditionalOpening Date is Blank
@when(
    "the OpeningTimes OpeningTimeType is Additional and AdditionalOpeningDate is not defined",
    target_fixture="context",
)
def specified_opening_date_not_defined(context: Context):
    context.change_event = ChangeEventBuilder("pharmacy").build_change_event_from_default()
    context.change_event.specified_opening_times[0]["AdditionalOpeningDate"] = ""
    return context


# An OpeningTime is received for the Day or Date where IsOpen is True and IsOpen is false.
@when("an AdditionalOpeningDate contains data with both true and false IsOpen status", target_fixture="context")
def same_specified_opening_date_with_true_and_false_isopen_status(context: Context):
    context.change_event = ChangeEventBuilder("pharmacy").build_change_event_from_default()
    context.change_event.specified_opening_times[0]["AdditionalOpeningDate"] = "Dec 25 2022"
    context.change_event.specified_opening_times[0]["IsOpen"] = False
    return context


@when(
    parse('the Changed Event is sent for processing with "{valid_or_invalid}" api key'),
    target_fixture="context",
)
def the_change_event_is_sent_for_processing(context: Context, valid_or_invalid):
    context.start_time = dt.today().timestamp()
    context.correlation_id = generate_correlation_id()
    context.response = process_payload(context.change_event, valid_or_invalid == "valid", context.correlation_id)
    context.sequence_number = context.response.request.headers["sequence-number"]
    return context


# Request with custom sequence id
@when(
    parse('the Changed Event is sent for processing with sequence id "{seqid}"'),
    target_fixture="context",
)
def the_change_event_is_sent_with_custom_sequence(context: Context, seqid):
    context.start_time = dt.today().timestamp()
    context.correlation_id = generate_correlation_id()
    context.response = process_payload_with_sequence(context.change_event, context.correlation_id, seqid)
    context.sequence_number = seqid
    return context


# Request with no sequence id
@when(
    parse("the Changed Event is sent for processing with no sequence id"),
    target_fixture="context",
)
def the_change_event_is_sent_with_no_sequence(context: Context):
    context.start_time = dt.today().timestamp()
    context.correlation_id = generate_correlation_id()
    context.response = process_payload_with_sequence(context.change_event, context.correlation_id, None)
    return context


# Request with duplicate sequence id
@when(
    parse("the Changed Event is sent for processing with a duplicate sequence id"),
    target_fixture="context",
)
def the_change_event_is_sent_with_duplicate_sequence(context: Context):
    context.start_time = dt.today().timestamp()
    context.correlation_id = generate_correlation_id()
    context.change_event.website = "https://www.test.com"
    odscode = context.change_event.odscode
    seqid = 0
    if context.sequence_number == 100:
        seqid = 100
    else:
        seqid = get_latest_sequence_id_for_a_given_odscode(odscode)
    context.response = process_payload_with_sequence(context.change_event, context.correlation_id, seqid)
    context.sequence_number = seqid
    return context


@when(parse('the change request is sent with "{valid_or_invalid}" api key'), target_fixture="context")
def the_change_request_is_sent(context: Context, valid_or_invalid):
    context.start_time = datetime.today().timestamp()
    context.response = process_change_request_payload(context.change_request, valid_or_invalid == "valid")
    return context


@then("the Changed Event is stored in dynamo db")
def stored_dynamo_db_events_are_pulled(context: Context):
    odscode = context.change_event.odscode
    sequence_num = Decimal(context.sequence_number)
    sleep(15)
    db_event_record = get_stored_events_from_dynamo_db(odscode, sequence_num)
    assert db_event_record is not None, f"ERROR!! Event record with odscode {odscode} NOT found!.."
    assert (
        odscode == db_event_record["ODSCode"]
    ), f"ERROR!!.. Change event record({odscode} - {db_event_record['ODSCode']}) mismatch!!"
    assert sequence_num == db_event_record["SequenceNumber"], "ERROR!!.. Change event record(sequence no) mismatch!!"
    return context


@then("the exception is reported to cloudwatch", target_fixture="context")
def service_exception(context: Context):
    query = (
        f'fields message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
        ' | filter level="ERROR"'
    )
    logs = get_logs(query, "processor", context.start_time)
    assert logs != [], "ERROR!!.. Expected exception not logged."
    return context


@then("the OpeningTimes exception is reported to cloudwatch")
def openingtimes_service_exception(context: Context):
    query = (
        f'fields message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
        ' | filter message like "Changes for nhs"'
    )
    logs = get_logs(query, "processor", context.start_time)
    assert "opening_dates" not in logs, "ERROR!!.. Expected OpeningTimes exception not captured."


@then(parse("the {address} from the changes is not included in the change request"))
def address_change_is_discarded_in_event_sender(context: Context, address: str):
    query = (
        f'fields change_request_body | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
        '| filter message like "Attempting to send change request to DoS"'
    )
    logs = get_logs(query, "sender", context.start_time)
    assert f"{address}" not in logs, "ERROR!!.. Unexpected Address change found in logs."


@then("the processed Changed Request is sent to Dos", target_fixture="context")
def processed_changed_request_sent_to_dos(context: Context):
    cr_received_search_param = "Received change request"
    cr_sent_search_param = "Successfully send change request to DoS"
    cr_received_query = (
        f'fields message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
        f' | filter message like "{cr_received_search_param}"'
    )
    cr_sent_query = (
        f'fields message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
        f' | filter message like "{cr_sent_search_param}"'
    )
    cr_received_logs = get_logs(cr_received_query, "sender", context.start_time)
    assert cr_received_logs != [], "ERROR!!.. Expected Sender logs not found."
    cr_sent_logs = get_logs(cr_sent_query, "sender", context.start_time)
    assert cr_sent_logs != [], "ERROR!!.. Expected sent event confirmation in service logs not found."
    return context


# This step doesn't actually do anything
@then("the Changed Event is not processed any further")
def the_changed_event_is_not_processed(context: Context):
    cr_received_search_param = "Received change request"
    query = f'fields message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
    logs = get_logs(query, "processor", context.start_time)
    assert f"{cr_received_search_param}" not in logs, "ERROR!!.. expected exception logs not found."


@then("the Changed Request is accepted by Dos")
def the_changed_request_is_accepted_by_dos(context: Context):
    """assert dos API response and validate processed record in Dos CR Queue database"""
    response = confirm_changes(context.correlation_id)
    assert response != [], "ERROR!!.. Expected Event confirmation in Dos not found."
    return context


@then(parse('the Changed Request is accepted by Dos with "{contact}" deleted'))
def the_changed_request_is_accepted_by_dos_with_contact_delete(context: Context, contact):
    service_id = get_service_id(context.correlation_id)
    approver_status = confirm_approver_status(context.correlation_id)
    match contact:
        case "phone":
            cms = "cmstelephoneno"
        case "website":
            cms = "cmsurl"
        case _:
            raise ValueError(f"Invalid contact provided: '{contact}'")
    assert approver_status != [], f"Error!.. Dos Change for Serviceid: {service_id} has been REJECTED"
    response = check_contact_delete_in_dos(context.correlation_id, cms)
    assert response is True, "ERROR!!.. Expected Event confirmation in Dos not found."
    return context


@then(parse('the Changed Request with formatted "{expected_url}" is captured by Dos'))
def the_changed_web_address_is_accepted_by_dos(context: Context, expected_url: str):
    """assert dos API response and validate processed record in Dos CR Queue database"""
    cms = "cmsurl"
    correlation_id = context.correlation_id.replace("/", r"\/")
    assert (
        check_received_data_in_dos(correlation_id, cms, expected_url) is True
    ), f"ERROR!.. Dos not updated with web address change: {expected_url}"


@then(parse("the Change is included in the Change request"))
def change_is_included_in_event_sender(context: Context):
    if "/" in context.correlation_id:
        context.correlation_id = context.correlation_id.replace("/", r"\/")
    query = (
        f'fields change_request_body | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
        '| filter message like "Successfully send change request to DoS"'
    )
    logs = get_logs(query, "sender", context.start_time)
    assert logs != [], "ERROR!!.. Expected Change not found in logs."


@then(parse('the Changed Request with changed "{contact}" is captured by Dos'))
def the_changed_contact_is_accepted_by_dos(context: Context, contact):
    """assert dos API response and validate processed record in Dos CR Queue database"""
    match contact:
        case "phone_no":
            cms = "cmstelephoneno"
            changed_data = context.change_event.phone
        case "website":
            cms = "cmsurl"
            changed_data = context.change_event.website
        case "address":
            cms = "postaladdress"
            changed_data = context.change_event.address_line_1
        case _:
            raise ValueError(f"Error!.. Input parameter '{contact}' not compatible")
    assert (
        check_received_data_in_dos(context.correlation_id, cms, changed_data) is True
    ), f"ERROR!.. Dos not updated with {contact} change: {changed_data}"


@then(parse('the Changed Event with changed "{field}" is not captured by Dos'))
def the_changed_contact_is_not_accepted_by_dos(context: Context, field: str):
    """assert dos API response and validate processed record in Dos CR Queue database"""
    match field:
        case "phone_no":
            cms = "cmstelephoneno"
            changed_data = context.change_event.phone
        case "website":
            cms = "cmsurl"
            changed_data = context.change_event.website
        case "organisation_name":
            cms = "cmspublicname"
            changed_data = context.change_event.organisation_name
        case _:
            raise ValueError(f"Error!.. Input parameter '{field}' not compatible")
    assert (
        check_received_data_in_dos(context.correlation_id, cms, changed_data) is False
    ), f"ERROR!.. Dos incorrectly updated with {field} change: {changed_data}"


@then("the Changed Request with changed specified date and time is captured by Dos")
def the_changed_opening_time_is_accepted_by_dos(context: Context):
    """assert dos API response and validate processed record in Dos CR Queue database"""
    open_time = time_to_sec(context.change_event.specified_opening_times[-1]["OpeningTime"])
    closing_time = time_to_sec(context.change_event.specified_opening_times[-1]["ClosingTime"])
    changed_time = f"{open_time}-{closing_time}"
    changed_date = context.change_event.specified_opening_times[-1]["AdditionalOpeningDate"]
    cms = "cmsopentimespecified"
    approver_status = confirm_approver_status(context.correlation_id)
    assert approver_status != [], f"Error!.. Dos Change for correlation id: {context.correlation_id} not COMPLETED"
    assert (
        check_specified_received_opening_times_date_in_dos(context.correlation_id, cms, changed_date) is True
    ), f"ERROR!.. Dos not updated with change: {changed_date}"
    assert (
        check_specified_received_opening_times_time_in_dos(context.correlation_id, cms, changed_time) is True
    ), f"ERROR!.. Dos not updated with change: {changed_time}"
    return context


@then("the Changed Request with changed standard day time is captured by Dos")
def the_changed_opening_standard_time_is_accepted_by_dos(context: Context):
    """assert dos API response and validate processed record in Dos CR Queue database"""
    open_time = time_to_sec(context.change_event.standard_opening_times[-1]["OpeningTime"])
    closing_time = time_to_sec(context.change_event.standard_opening_times[-1]["ClosingTime"])
    changed_time = f"{open_time}-{closing_time}"
    cms = "cmsopentimemonday"
    assert (
        check_standard_received_opening_times_time_in_dos(context.correlation_id, cms, changed_time) is True
    ), f"ERROR!.. Dos not updated with change: {changed_time}"


@then("the Changed Request with changed address is captured by Dos")
def the_changed_address_is_accepted_by_dos(context: Context):
    """assert dos API response and validate processed record in Dos CR Queue database"""
    changed_address = context.change_event.address_line_1
    assert (
        check_received_data_in_dos(context.correlation_id, "postaladdress", changed_address) is True
    ), f"ERROR!.. Dos not updated with address change: {changed_address}"


@then("the Changed Event is not sent to Dos")
def the_changed_event_is_not_sent_to_dos(context: Context):
    response = get_changes(context.correlation_id)
    assert response == [], "ERROR!!.. Event data found in Dos."


@then(parse('the change request has status code "{status}"'))
def step_then_should_transform_into(context: Context, status):
    message = context.response.json
    assert (
        str(context.response.status_code) == status
    ), f"Status code not as expected: {context.response.status_code} != {status} Error: {message} - {status}"


@then("the attributes for invalid opening times report is identified in the logs")
def invalid_opening_times_exception(context: Context):
    query = (
        f'fields @message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
        '| filter report_key="INVALID_OPEN_TIMES"'
    )
    logs = get_logs(query, "processor", context.start_time)
    for item in [
        "nhsuk_odscode",
        "nhsuk_organisation_name",
        "message_received",
        "nhsuk_open_times_payload",
        "dos_services",
    ]:
        assert item in logs


@then("the date for the specified opening time returns an empty list")
def specified_opening_date_closed(context: Context):
    closed_date = context.change_event.specified_opening_times[-1]["AdditionalOpeningDate"]
    date_obj = dt.strptime(closed_date, "%b %d %Y").strftime("%Y-%m-%d")
    query = f'fields @message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
    logs = get_logs(query, "sender", context.start_time)
    assert f'\\"{date_obj}\\":[]' in logs, f"Expected closed date '{closed_date}' not captured"
    return context


@then("the day for the standard opening time returns an empty list")
def standard_opening_day_closed(context: Context):
    closed_day = context.change_event.standard_opening_times[-1]["Weekday"]
    query = f'fields @message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
    logs = get_logs(query, "sender", context.start_time)
    assert f'\\"{closed_day}\\":[]' in logs, f"Expected closed day '{closed_day}' not captured"
    return context


@then("the stored Changed Event is reprocessed in DI")
def replaying_changed_event(context: Context):
    response = re_process_payload(context.change_event.odscode, context.sequence_number)
    assert (
        "The change event has been re-sent successfully" in response
    ), f"Error!.. Failed to re-process Change event. Message: {response}"
    context.correlation_id = ast.literal_eval(loads(response)).get("correlation_id")
    return context


@then("the reprocessed Changed Event is sent to Dos")
def verify_replayed_changed_event(context: Context):
    response = confirm_changes(context.correlation_id)
    assert response != [], "Error!.. Re-processed change event not found in Dos"


@then("the opening times changes are confirmed valid")
def no_opening_times_errors(context: Context):
    response = confirm_changes(context.correlation_id)
    assert "cmsopentime" in str(response), "Error!.. Opening time Change not found in Dos Changes"


@then("the Changed Request with special characters is accepted by DOS")
def the_changed_website_is_accepted_by_dos(context: Context):
    #   the test env uses a 'prod-like' DOS endpoint which rejects these
    current_env = getenv("ENVIRONMENT")
    if "test" in current_env:
        query = (
            "fields response_status_code | sort @timestamp asc"
            f' | filter correlation_id="{context.correlation_id}"'
            ' | filter message like "Failed to send change request to DoS"'
        )
        logs = get_logs(query, "sender", context.start_time)
        assert "400" in logs, "ERROR!!.. 400 response not received from DOS"
    else:
        #       the mock DOS currently accepts the invalid characters
        uri_timestamp = context.uri_timestamp
        complete_uri = f"https:\\\\/\\\\/www.rowlandspharmacy.co.uk\\\\/test?foo={uri_timestamp}"  # noqa: W605
        query = (
            "fields change_request_body.changes.website | sort @timestamp asc"
            f' | filter correlation_id="{context.correlation_id}"'
            ' | filter message like "Attempting to send change request to DoS"'
        )
        logs = get_logs(query, "sender", context.start_time)
        assert complete_uri in logs, "ERROR!!.. website not found in CR."
        success_query = (
            f'fields message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
            ' | filter message like "Successfully send change request to DoS"'
        )
        logs = get_logs(success_query, "sender", context.start_time)
        assert logs != [], "ERROR!!.. successful log messages not showing in cloudwatch."


@then("the Changed Event is replayed with the specified opening date deleted")
def change_event_is_replayed(context: Context):
    target_date = context.change_event.specified_opening_times[-1]["AdditionalOpeningDate"]
    context.change_event.specified_opening_times = []
    context.correlation_id = f"{context.correlation_id}-replay"
    context.response = process_payload(context.change_event, True, context.correlation_id)
    context.other = {"deleted_date": target_date}
    return context


@then("the deleted specified date is confirmed removed from Dos")
def specified_date_is_removed_from_dos(context: Context):
    service_id = get_service_id(context.correlation_id)
    removed_date = dt.strptime(context.other["deleted_date"], "%b %d %Y").strftime("%y-%m-%d")
    approver_status = confirm_approver_status(context.correlation_id)
    assert approver_status != [], f"Error!.. Dos Change for Serviceid: {service_id} has been REJECTED"
    specified_opening_times_from_db = get_change_event_specified_opening_times(service_id)
    assert removed_date not in str(
        specified_opening_times_from_db
    ), f"Error!.. Removed specified date: {removed_date} still exists in Dos"


@then(parse('the Changed Event is replayed with the pharmacy now "{open_or_closed}"'))
def event_replayed_with_pharmacy_closed(context: Context, open_or_closed):
    closing_time = datetime.datetime.now().time().strftime("%H:%M")
    match open_or_closed.upper():
        case "OPEN":
            context.change_event.standard_opening_times[-1]["OpeningTime"] = "00:01"
            context.change_event.standard_opening_times[-1]["ClosingTime"] = closing_time
            context.change_event.standard_opening_times[-1]["IsOpen"] = True
            context.correlation_id = f"{context.correlation_id}_open_replay"
        case "CLOSED":
            context.change_event.standard_opening_times[-1]["OpeningTime"] = ""
            context.change_event.standard_opening_times[-1]["ClosingTime"] = ""
            context.change_event.standard_opening_times[-1]["IsOpen"] = False
            context.correlation_id = f"{context.correlation_id}_closed_replay"
        case _:
            raise ValueError(f'Invalid status input parameter: "{open_or_closed}"')
    context.response = process_payload(context.change_event, True, context.correlation_id)
    return context


@then(parse('the pharmacy is confirmed "{open_or_closed}" for the standard day in Dos'))
def standard_day_confirmed_open(context: Context, open_or_closed):
    approver_status = confirm_approver_status(context.correlation_id)
    assert approver_status != [], "Error!.. Dos Change not Approved or COMPLETED"
    service_id = get_service_id(context.correlation_id)
    opening_time_event = get_change_event_standard_opening_times(service_id)
    week_day = context.change_event.standard_opening_times[-1]["Weekday"]
    match open_or_closed.upper():
        case "CLOSED":
            assert (
                opening_time_event[week_day] == []
            ), f'ERROR!.. Pharmacy is CLOSED but expected to be OPEN for "{week_day}"'
        case "OPEN":
            assert (
                opening_time_event[week_day] != []
            ), f'ERROR!.. Pharmacy is OPEN but expected to be CLOSED for "{week_day}"'
        case _:
            raise ValueError(f'Invalid status input parameter: "{open_or_closed}"')
    return context


@then("the Dentist changes with service type id is captured by Dos")
def dentist_changes_confirmed_in_dos(context: Context):
    change_event_service_type = get_service_type_data(context.change_event.organisation_type_id)["VALID_SERVICE_TYPES"]
    change_request_service_type = get_service_type_from_cr(context.correlation_id)
    assert change_event_service_type[0] == change_request_service_type, "ERROR!.. Service type id mismatch"


@then(parse('the Changed Event finds a matching dentist with ods "{odscode}"'))
def check_logs_for_dentist_match(context: Context, odscode):
    query = (
        f'fields message | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
        ' | filter message like "services with typeid in allowlist"'
    )
    logs = get_logs(query, "processor", context.start_time)
    assert odscode in logs, "ERROR!!.. error processor does not have correct ods."


@then(parse('the Event Sender sends the ods "{odscode}"'))
def check_logs_for_correct_sent_cr(context: Context, odscode):
    query = (
        f'fields message, ods_code | sort @timestamp asc | filter correlation_id="{context.correlation_id}"'
        ' | filter message like "Attempting to send change request to DoS"'
    )
    logs = get_logs(query, "sender", context.start_time)
    assert odscode in logs, "ERROR!!.. error sender does not have correct ods."


@then(parse('the Event "{processor}" shows field "{field}" with message "{message}"'))
def generic_processor_check_function(context: Context, processor, field, message):
    if "/" in context.correlation_id:
        context.correlation_id = context.correlation_id.replace("/", r"\/")
    query = (
        f"fields {field} | sort @timestamp asc"
        f' | filter correlation_id="{context.correlation_id}" | filter {field} like "{message}"'
    )
    logs = get_logs(query, processor, context.start_time)
    assert message in logs, f"ERROR!!.. error event processor did not detect the {field}: {message}."


@then(parse('the Event "{processor}" does not show "{field}" with message "{message}"'))
def generic_processor_negative_check_function(context: Context, processor, field, message):
    find_request_id_query = (
        "fields function_request_id | sort @timestamp asc" f' | filter correlation_id="{context.correlation_id}"'
    )
    find_request_id = loads(get_logs(find_request_id_query, processor, context.start_time))

    request_id = ""
    for x in find_request_id["results"][0]:
        if x["field"] == "function_request_id":
            request_id = x["value"]

    finished_check = f'fields @message | filter @requestId == "{request_id}" | filter @type == "END"'

    get_logs(finished_check, processor, context.start_time, 2)

    query = (
        f"fields {field} | sort @timestamp asc"
        f' | filter correlation_id="{context.correlation_id}" | filter {field} like "{message}"'
    )
    logs_found = negative_log_check(query, processor, context.start_time)

    assert logs_found is True, f"ERROR!!.. error event processor did not detect the {field}: {message}."
