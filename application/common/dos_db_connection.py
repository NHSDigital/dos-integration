from collections.abc import Generator
from contextlib import contextmanager
from os import environ
from time import time_ns
from typing import Any

from aws_lambda_powertools.logging import Logger
from psycopg import Connection, Cursor, connect
from psycopg.rows import DictRow, dict_row
from typing_extensions import LiteralString

from common.secretsmanager import get_secret

logger = Logger(child=True)
db_connection = None


@contextmanager
def connect_to_dos_db_replica() -> Generator[Connection, None, None]:
    """Creates a new connection to the DoS DB Replica.

    Yields:
        Generator[connection, None, None]: Connection to the database
    """
    # Use AWS secret values, or failing that check env for DB password
    if "DB_REPLICA_SECRET_NAME" in environ and "DB_REPLICA_SECRET_KEY" in environ:
        db_secret = get_secret(environ["DB_REPLICA_SECRET_NAME"])
        db_password = db_secret[environ["DB_REPLICA_SECRET_KEY"]]
    else:
        db_password = environ["DB_SECRET"]

    # Before the context manager is entered, the connection is created
    db_connection = connection_to_db(
        server=environ["DB_REPLICA_SERVER"],
        port=environ["DB_PORT"],
        db_name=environ["DB_NAME"],
        db_schema=environ["DB_SCHEMA"],
        db_user=environ["DB_READ_ONLY_USER_NAME"],
        db_password=db_password,
    )
    # Yield the connection object to the context manager
    yield db_connection
    # After the context manager is exited, the connection is closed
    db_connection.close()


@contextmanager
def connect_to_dos_db() -> Generator[Connection[DictRow], None, None]:
    """Creates a new connection to the DoS DB.

    Yields:
        Generator[connection, None, None]: Connection to the database
    """
    # Before the context manager is entered, the connection is created
    db_secret = get_secret(environ["DB_SECRET_NAME"])
    db_connection = connection_to_db(
        server=environ["DB_SERVER"],
        port=environ["DB_PORT"],
        db_name=environ["DB_NAME"],
        db_schema=environ["DB_SCHEMA"],
        db_user=environ["DB_READ_AND_WRITE_USER_NAME"],
        db_password=db_secret[environ["DB_SECRET_KEY"]],
    )
    # Yield the connection object to the context manager
    yield db_connection
    # After the context manager is exited, the connection is closed
    db_connection.close()


def connection_to_db(  # noqa: PLR0913
    server: str,
    port: str,
    db_name: str,
    db_schema: str,
    db_user: str,
    db_password: str,
) -> Connection:
    """Creates a new connection to a database.

    Args:
        server (str): Database server to connect to
        port (str): Database port to connect to
        db_name (str): Database name to connect to
        db_schema (str): Database schema to connect to
        db_user (str): Database user to connect as
        db_password (str): Database password for the user

    Returns:
        connection: Connection to the database
    """
    logger.info(f"Attempting connection to database '{server}'")
    logger.debug(f"host={server}, port={port}, dbname={db_name}, schema={db_schema}, user={db_user}")
    return connect(
        host=server,
        port=port,
        dbname=db_name,
        user=db_user,
        password=db_password,
        connect_timeout=2,
        options=f"-c search_path=dbo,{db_schema}",
        application_name="DOS INTEGRATION <psycopg>",
    )


def query_dos_db(
    connection: Connection,
    query: LiteralString,
    query_vars: dict[str, Any] | None = None,
    log_vars: bool = True,
) -> Cursor[DictRow]:
    """Queries the database given in the connection object.

    Args:
        connection (Connection): Connection to the database
        query (str): Query to execute
        query_vars (Optional[Dict[str, Any]], optional): Variables to use in the query. Defaults to None.
        log_vars (bool, optional): Whether to log the query variables. Defaults to True.

    Returns:
        DictRow: Cursor to the query results
    """
    cursor = connection.cursor(row_factory=dict_row)

    logger.info(
        "Query to execute", extra={"query": query, "vars": query_vars if log_vars else "Vars have been redacted."},
    )

    time_start = time_ns() // 1000000
    cursor.execute(query=query, params=query_vars)
    logger.info(f"DoS DB query completed in {(time_ns() // 1000000) - time_start}ms")
    return cursor
