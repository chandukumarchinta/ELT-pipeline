"""Database Configuration for Titanic ELT Pipeline.

Configures connection parameters and helper functions for MySQL / MariaDB.
Allows environment variable overrides with sensible local defaults.
"""

import os
import urllib.parse
import mysql.connector
from sqlalchemy import create_engine

DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", "chandu@17@07"),
    "database": os.getenv("MYSQL_DATABASE", "titanic_db"),
    "port": int(os.getenv("MYSQL_PORT", 3306)),
}


def get_connection():
    """Establish and return a raw mysql.connector connection."""
    return mysql.connector.connect(**DB_CONFIG)


def get_sqlalchemy_engine():
    """Build and return a SQLAlchemy engine for bulk loading."""
    encoded_password = urllib.parse.quote_plus(DB_CONFIG["password"])
    url = (
        f"mysql+mysqlconnector://{DB_CONFIG['user']}:{encoded_password}@"
        f"{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
    )
    return create_engine(url)

