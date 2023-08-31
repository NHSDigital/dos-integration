from dataclasses import dataclass

from requests import Response


@dataclass(init=True)
class Context:
    """Test context object for storing data between steps."""

    change_event: dict | None = None
    service_id: str | None = None
    service_uid: str | None = None
    correlation_id: str | None = None
    response: Response | None = None
    sequence_number: int | None = None
    start_time: str | None = None
    previous_value: str = "unknown"
    ods_code: str | None = None
    website: str | None = None
    phone: str | None = None
    other: dict | None = None
    generator_data: dict | None = None
    # Other used as a catch all for any other data that is not covered by the above and only used in a couple tests

    def __repr__(self) -> str:
        """Return a string representation of the object.

        Returns:
            str: String representation of the object.
        """
        return (
            f"Context(correlation_id={self.correlation_id}, sequence_number={self.sequence_number}"
            f", service_id={self.service_id}, previous_value={self.previous_value}, change_event={self.change_event}"
            f", other={self.other}, service_uid={self.service_uid}, website={self.website}, phone={self.phone}"
            f", query={self.generator_data}"
        )
