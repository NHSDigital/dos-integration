from datetime import datetime, date
from typing import List, Dict
from itertools import groupby
from logging import getLogger

from opening_times import OpenPeriod, StandardOpeningTimes, SpecifiedOpeningTime, WEEKDAYS

logger = getLogger("lambda")


class NHSEntity:
    """This is an object to store an NHS Entity data

    When passed in a payload (dict) with the NHS data, it will
    pass those fields in to the object as attributes.

    This object may be added to with methods to make the
    comparions with services easier in future tickets.

    """

    def __init__(self, entity_data: dict):
        # Set attributes for each value in dict
        self.data = entity_data
        for key, value in entity_data.items():
            setattr(self, key, value)

        self._standard_opening_times = None
        self._specified_opening_times = None

    def __repr__(self):
        return f"<NHSEntity: name={self.OrganisationName} odscode={self.ODSCode}>:"

    def standard_opening_times(self) -> StandardOpeningTimes:
        if self._standard_opening_times is None:
            self._standard_opening_times = self._get_standard_opening_times("General")
        return self._standard_opening_times

    def specified_opening_times(self) -> List[SpecifiedOpeningTime]:
        if self._specified_opening_times is None:
            self._specified_opening_times = self._get_specified_opening_times("General")
        return self._specified_opening_times

    def _get_standard_opening_times(self, opening_time_type) -> StandardOpeningTimes:
        """Filters the raw opening times data for standard weekly opening
        times and returns it in a StandardOpeningTimes object.
        """
        std_opening_times = StandardOpeningTimes()
        for opentime in self.OpeningTimes:
            # Skips unwanted open times
            if not (
                opentime["Weekday"].lower() in WEEKDAYS
                and opentime["AdditionalOpeningDate"] == ""
                and opentime["OpeningTimeType"] == opening_time_type
                and opentime["IsOpen"]
            ):
                continue

            weekday = opentime["Weekday"].lower()
            start, end = [datetime.strptime(time_str, "%H:%M").time() for time_str in opentime["Times"].split("-")]

            open_period = OpenPeriod(start, end)
            std_opening_times.add_open_period(open_period, weekday)

        return std_opening_times

    def _get_specified_opening_times(self, opening_time_type: str) -> List[SpecifiedOpeningTime]:
        """Get all the Specified Opening Times
        Args:
            opening_time_type  (str): OpeningTimeType to filter the data
            e.g General for pharmacy
        Returns:
            dict: key=date and value = List[OpenPeriod] objects  in a sort
            order
        """

        # Filter
        def specified_opening_times_filter(specified):

            return specified["OpeningTimeType"] == opening_time_type and specified["AdditionalOpeningDate"] != ""

        specified_times_list = list(filter(specified_opening_times_filter, self.OpeningTimes))

        # Sort the openingtimes  data
        sort_specifiled = sorted(specified_times_list, key=lambda item: (item["AdditionalOpeningDate"], item["Times"]))
        specified_opening_time_dict: Dict[datetime, List[OpenPeriod]] = {}

        # Grouping data by date
        key: date
        for key, value in groupby(sort_specifiled, lambda item: (item["AdditionalOpeningDate"])):
            op_list: List[OpenPeriod] = []
            for item in list(value):
                start, end = [datetime.strptime(time_str, "%H:%M").time() for time_str in item["Times"].split("-")]
                op_list.append(OpenPeriod(start, end))
                specified_opening_time_dict[key] = op_list

        specified_opening_times = [
            SpecifiedOpeningTime(value, datetime.strptime(key, "%b  %d  %Y").date())
            for key, value in specified_opening_time_dict.items()
        ]

        return specified_opening_times
