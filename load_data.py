"""
Load all Olist CSV files into a PostgreSQL database.

Expected database schema:
    product_category_name_translation
    customers
    sellers
    products
    orders
    order_items
    order_payments
    order_reviews
    geolocation

Installation:
    pip install pandas sqlalchemy psycopg2-binary python-dotenv

Create a .env file in the project root:

    DB_HOST=localhost
    DB_PORT=5432
    DB_NAME=olist_retail_analytics
    DB_USER=postgres
    DB_PASSWORD=your_password
    DATA_DIR=data/raw

Run:
    python load_data.py
"""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path
from typing import Final

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.types import (
    BigInteger,
    DateTime,
    Integer,
    Numeric,
    String,
    Text,
)


# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

load_dotenv()

DB_HOST: Final[str] = os.getenv("DB_HOST", "localhost")
DB_PORT: Final[str] = os.getenv("DB_PORT", "5432")
DB_NAME: Final[str] = os.getenv("DB_NAME", "olist_retail_analytics")
DB_USER: Final[str] = os.getenv("DB_USER", "postgres")
DB_PASSWORD: Final[str | None] = os.getenv("DB_PASSWORD")
DATA_DIR: Final[Path] = Path(os.getenv("DATA_DIR", "data/raw"))

# Adjust this value if memory is limited.
CHUNK_SIZE: Final[int] = 10_000

DATABASE_URL: Final[str] = (
    f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------
# Source-file and table definitions
# ---------------------------------------------------------------------

LOAD_PLAN: Final[list[dict[str, object]]] = [
    {
        "file": "product_category_name_translation.csv",
        "table": "product_category_name_translation",
        "date_columns": [],
        "dtype": {
            "product_category_name": String(100),
            "product_category_name_english": String(100),
        },
    },
    {
        "file": "olist_customers_dataset.csv",
        "table": "customers",
        "date_columns": [],
        "dtype": {
            "customer_id": String(32),
            "customer_unique_id": String(32),
            "customer_zip_code_prefix": Integer(),
            "customer_city": String(100),
            "customer_state": String(2),
        },
    },
    {
        "file": "olist_sellers_dataset.csv",
        "table": "sellers",
        "date_columns": [],
        "dtype": {
            "seller_id": String(32),
            "seller_zip_code_prefix": Integer(),
            "seller_city": String(100),
            "seller_state": String(2),
        },
    },
    {
        "file": "olist_products_dataset.csv",
        "table": "products",
        "date_columns": [],
        "rename_columns": {
            # These mappings make the loader work whether the original CSV
            # spelling has been corrected or not.
            "product_name_lenght": "product_name_length",
            "product_description_lenght": "product_description_length",
        },
        "dtype": {
            "product_id": String(32),
            "product_category_name": String(100),
            "product_name_length": Integer(),
            "product_description_length": Integer(),
            "product_photos_qty": Integer(),
            "product_weight_g": Numeric(10, 2),
            "product_length_cm": Numeric(10, 2),
            "product_height_cm": Numeric(10, 2),
            "product_width_cm": Numeric(10, 2),
        },
    },
    {
        "file": "olist_orders_dataset.csv",
        "table": "orders",
        "date_columns": [
            "order_purchase_timestamp",
            "order_approved_at",
            "order_delivered_carrier_date",
            "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ],
        "dtype": {
            "order_id": String(32),
            "customer_id": String(32),
            "order_status": String(30),
            "order_purchase_timestamp": DateTime(),
            "order_approved_at": DateTime(),
            "order_delivered_carrier_date": DateTime(),
            "order_delivered_customer_date": DateTime(),
            "order_estimated_delivery_date": DateTime(),
        },
    },
    {
        "file": "olist_order_items_dataset.csv",
        "table": "order_items",
        "date_columns": ["shipping_limit_date"],
        "dtype": {
            "order_id": String(32),
            "order_item_id": Integer(),
            "product_id": String(32),
            "seller_id": String(32),
            "shipping_limit_date": DateTime(),
            "price": Numeric(12, 2),
            "freight_value": Numeric(12, 2),
        },
    },
    {
        "file": "olist_order_payments_dataset.csv",
        "table": "order_payments",
        "date_columns": [],
        "dtype": {
            "order_id": String(32),
            "payment_sequential": Integer(),
            "payment_type": String(30),
            "payment_installments": Integer(),
            "payment_value": Numeric(12, 2),
        },
    },
    {
        "file": "olist_order_reviews_dataset.csv",
        "table": "order_reviews",
        "date_columns": [
            "review_creation_date",
            "review_answer_timestamp",
        ],
        "dtype": {
            "review_id": String(32),
            "order_id": String(32),
            "review_score": Integer(),
            "review_comment_title": Text(),
            "review_comment_message": Text(),
            "review_creation_date": DateTime(),
            "review_answer_timestamp": DateTime(),
        },
    },
    {
        "file": "olist_geolocation_dataset.csv",
        "table": "geolocation",
        "date_columns": [],
        "dtype": {
            # geolocation_id is generated by PostgreSQL and is deliberately
            # omitted from the CSV insert.
            "geolocation_zip_code_prefix": Integer(),
            "geolocation_lat": Numeric(10, 7),
            "geolocation_lng": Numeric(10, 7),
            "geolocation_city": String(100),
            "geolocation_state": String(2),
        },
    },
]


# ---------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------

def create_database_engine() -> Engine:
    """Create and test the PostgreSQL connection."""
    if not DB_PASSWORD:
        raise ValueError(
            "DB_PASSWORD is missing. Add it to the .env file."
        )

    engine = create_engine(
        DATABASE_URL,
        future=True,
        pool_pre_ping=True,
    )

    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))

    logger.info("Connected to PostgreSQL database '%s'.", DB_NAME)
    return engine


def verify_source_files() -> None:
    """Confirm that all required CSV files are present."""
    missing_files = [
        str(DATA_DIR / str(item["file"]))
        for item in LOAD_PLAN
        if not (DATA_DIR / str(item["file"])).exists()
    ]

    if missing_files:
        missing_text = "\n".join(f"  - {path}" for path in missing_files)
        raise FileNotFoundError(
            "The following source files were not found:\n"
            f"{missing_text}\n"
            "Check DATA_DIR in the .env file."
        )


def verify_tables_exist(engine: Engine) -> None:
    """Confirm that schema.sql was executed before loading data."""
    expected_tables = {str(item["table"]) for item in LOAD_PLAN}

    query = text(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        """
    )

    with engine.connect() as connection:
        existing_tables = {
            row[0] for row in connection.execute(query)
        }

    missing_tables = expected_tables - existing_tables

    if missing_tables:
        raise RuntimeError(
            "The following tables do not exist: "
            + ", ".join(sorted(missing_tables))
            + ". Run schema.sql before running this loader."
        )


def clear_existing_data(engine: Engine) -> None:
    """
    Remove existing rows while preserving the table definitions.

    TRUNCATE uses CASCADE because the tables have foreign-key relationships.
    The identity sequence for geolocation_id is restarted.
    """
    table_names = ", ".join(
        str(item["table"]) for item in reversed(LOAD_PLAN)
    )

    statement = text(
        f"TRUNCATE TABLE {table_names} RESTART IDENTITY CASCADE"
    )

    with engine.begin() as connection:
        connection.execute(statement)

    logger.info("Existing table data cleared.")


def prepare_chunk(
    chunk: pd.DataFrame,
    rename_columns: dict[str, str],
    date_columns: list[str],
) -> pd.DataFrame:
    """Rename columns, convert timestamps, and normalize null values."""
    if rename_columns:
        chunk = chunk.rename(columns=rename_columns)

    for column in date_columns:
        if column in chunk.columns:
            chunk[column] = pd.to_datetime(
                chunk[column],
                errors="coerce",
            )

    # SQLAlchemy/pandas will translate Python None into SQL NULL.
    return chunk.astype(object).where(pd.notna(chunk), None)


def add_missing_category_translations(engine: Engine) -> int:
    """
    Insert category names found in products but absent from the translation CSV.

    The original Olist translation file omits a small number of categories.
    Without this step, the products foreign key can reject those rows.
    The Portuguese category name is retained as the fallback English value.
    """
    products_path = DATA_DIR / "olist_products_dataset.csv"
    translations_path = DATA_DIR / "product_category_name_translation.csv"

    products = pd.read_csv(
        products_path,
        usecols=["product_category_name"],
    )
    translations = pd.read_csv(
        translations_path,
        usecols=["product_category_name"],
    )

    product_categories = set(
        products["product_category_name"].dropna().unique()
    )
    translated_categories = set(
        translations["product_category_name"].dropna().unique()
    )
    missing_categories = sorted(
        product_categories - translated_categories
    )

    if not missing_categories:
        return 0

    fallback_rows = pd.DataFrame(
        {
            "product_category_name": missing_categories,
            "product_category_name_english": missing_categories,
        }
    )

    fallback_rows.to_sql(
        name="product_category_name_translation",
        con=engine,
        if_exists="append",
        index=False,
        method="multi",
    )

    logger.warning(
        "Added %d missing category translation row(s): %s",
        len(missing_categories),
        ", ".join(missing_categories),
    )
    return len(missing_categories)


def load_csv_to_table(
    engine: Engine,
    config: dict[str, object],
) -> int:
    """Load one CSV file into its corresponding PostgreSQL table."""
    filename = str(config["file"])
    table_name = str(config["table"])
    source_path = DATA_DIR / filename
    date_columns = list(config.get("date_columns", []))
    rename_columns = dict(config.get("rename_columns", {}))
    sql_types = dict(config.get("dtype", {}))

    inserted_rows = 0

    logger.info("Loading %s into %s...", filename, table_name)

    for chunk in pd.read_csv(
        source_path,
        chunksize=CHUNK_SIZE,
        low_memory=False,
    ):
        chunk = prepare_chunk(
            chunk=chunk,
            rename_columns=rename_columns,
            date_columns=date_columns,
        )

        expected_columns = list(sql_types.keys())
        missing_columns = [
            column
            for column in expected_columns
            if column not in chunk.columns
        ]

        if missing_columns:
            raise ValueError(
                f"{filename} is missing expected column(s): "
                + ", ".join(missing_columns)
            )

        # Select and order only the columns expected by the database.
        chunk = chunk[expected_columns]

        chunk.to_sql(
            name=table_name,
            con=engine,
            if_exists="append",
            index=False,
            chunksize=2_000,
            method="multi",
            dtype=sql_types,
        )

        inserted_rows += len(chunk)
        logger.info(
            "%s: inserted %,d rows so far.",
            table_name,
            inserted_rows,
        )

    logger.info(
        "Completed %s: %,d rows inserted.",
        table_name,
        inserted_rows,
    )
    return inserted_rows


def validate_row_counts(
    engine: Engine,
    inserted_counts: dict[str, int],
) -> None:
    """Compare inserted row counts with rows stored in PostgreSQL."""
    logger.info("Validating row counts...")

    with engine.connect() as connection:
        for table_name, expected_count in inserted_counts.items():
            actual_count = connection.execute(
                text(f"SELECT COUNT(*) FROM {table_name}")
            ).scalar_one()

            if actual_count != expected_count:
                raise RuntimeError(
                    f"Row-count mismatch for {table_name}: "
                    f"expected {expected_count}, found {actual_count}."
                )

            logger.info(
                "%s: %,d rows verified.",
                table_name,
                actual_count,
            )


# ---------------------------------------------------------------------
# Main process
# ---------------------------------------------------------------------

def main() -> None:
    """Execute the complete Olist loading workflow."""
    engine: Engine | None = None

    try:
        verify_source_files()
        engine = create_database_engine()
        verify_tables_exist(engine)

        # Set this to False if data should be appended rather than replaced.
        REPLACE_EXISTING_DATA = True

        if REPLACE_EXISTING_DATA:
            clear_existing_data(engine)

        inserted_counts: dict[str, int] = {}

        for config in LOAD_PLAN:
            table_name = str(config["table"])

            inserted_counts[table_name] = load_csv_to_table(
                engine=engine,
                config=config,
            )

            # The source translation file omits some product categories.
            # Add fallback rows before inserting the products table.
            if table_name == "product_category_name_translation":
                inserted_counts[table_name] += add_missing_category_translations(engine)

        validate_row_counts(engine, inserted_counts)

        logger.info("All Olist CSV files were loaded successfully.")

    except (
        FileNotFoundError,
        ValueError,
        RuntimeError,
        SQLAlchemyError,
    ) as error:
        logger.exception("Data loading failed: %s", error)
        sys.exit(1)

    finally:
        if engine is not None:
            engine.dispose()


if __name__ == "__main__":
    main()
