from unittest.mock import MagicMock, patch

import pytest

from application.service_sync.data_processing.get_data import get_dos_service_and_history

FILE_PATH = "application.service_sync.data_processing.get_data"


@patch(f"{FILE_PATH}.ServiceHistories")
@patch(f"{FILE_PATH}.get_specified_opening_times_from_db")
@patch(f"{FILE_PATH}.get_standard_opening_times_from_db")
@patch(f"{FILE_PATH}.DoSService")
@patch(f"{FILE_PATH}.query_dos_db")
@patch(f"{FILE_PATH}.connect_to_db_writer")
def test_get_dos_service_and_history(
    mock_connect_to_db_writer: MagicMock,
    mock_query_dos_db: MagicMock,
    mock_dos_service: MagicMock,
    mock_get_standard_opening_times_from_db: MagicMock,
    mock_get_specified_opening_times_from_db: MagicMock,
    mock_service_histories: MagicMock,
) -> None:
    # Arrange
    service_id = 12345
    mock_query_dos_db.return_value.fetchall.return_value = [["Test"]]
    # Act
    dos_service, service_history = get_dos_service_and_history(service_id)
    # Assert
    assert mock_dos_service() == dos_service
    mock_get_standard_opening_times_from_db.assert_called_once_with(
        connection=mock_connect_to_db_writer().__enter__(),
        service_id=service_id,
    )
    mock_get_specified_opening_times_from_db.assert_called_once_with(
        connection=mock_connect_to_db_writer().__enter__(),
        service_id=service_id,
    )
    assert mock_service_histories() == service_history
    mock_service_histories.return_value.get_service_history_from_db.assert_called_once_with(
        mock_connect_to_db_writer().__enter__(),
    )
    mock_service_histories.return_value.create_service_histories_entry.assert_called_once_with()


@patch(f"{FILE_PATH}.query_dos_db")
@patch(f"{FILE_PATH}.connect_to_db_writer")
def test_get_dos_service_and_history_no_match(
    mock_connect_to_db_writer: MagicMock,
    mock_query_dos_db: MagicMock,
) -> None:
    # Arrange
    service_id = 12345
    mock_query_dos_db.return_value.fetchone.return_value = None
    # Act
    with pytest.raises(ValueError, match=f"Service ID {service_id} not found"):
        get_dos_service_and_history(service_id)
    mock_connect_to_db_writer.assert_called_once()
