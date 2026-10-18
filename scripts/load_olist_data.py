"""Load the Olist CSVs from archive/ into PostgreSQL and verify row counts.

Run after scripts/create_tables.sql. Re-runnable: empties the tables first, and
the whole load is one transaction, so a failure leaves the tables unchanged.

Usage: python scripts/load_olist_data.py
"""

import csv
import os
import sys
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from psycopg import sql

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "archive"

# (table, CSV file, expected row count), parents before children for foreign keys.
TABLES = [
    ("product_category_name_translation", "product_category_name_translation.csv", 71),
    ("customers", "olist_customers_dataset.csv", 99_441),
    ("sellers", "olist_sellers_dataset.csv", 3_095),
    ("products", "olist_products_dataset.csv", 32_951),
    ("orders", "olist_orders_dataset.csv", 99_441),
    ("order_items", "olist_order_items_dataset.csv", 112_650),
    ("order_payments", "olist_order_payments_dataset.csv", 103_886),
    ("order_reviews", "olist_order_reviews_dataset.csv", 99_224),
    ("geolocation", "olist_geolocation_dataset.csv", 1_000_163),
]


def read_header(path: Path) -> list[str]:
    # utf-8-sig strips the byte-order mark some of the CSVs start with.
    with path.open(encoding="utf-8-sig", newline="") as f:
        return next(csv.reader(f))


def copy_csv(cur: psycopg.Cursor, table: str, path: Path) -> None:
    """Stream a CSV into a table with COPY, matching columns by the CSV header."""
    columns = read_header(path)
    statement = sql.SQL("COPY {} ({}) FROM STDIN WITH (FORMAT csv, HEADER true)").format(
        sql.Identifier(table),
        sql.SQL(", ").join(map(sql.Identifier, columns)),
    )
    with path.open("rb") as f, cur.copy(statement) as copy:
        while chunk := f.read(1 << 20):
            copy.write(chunk)


def main() -> int:
    load_dotenv(ROOT / ".env")
    url = os.environ.get("ADMIN_DATABASE_URL")
    if not url:
        print("ADMIN_DATABASE_URL is not set. Copy .env.example to .env and fill it in.")
        return 1

    table_names = [table for table, _, _ in TABLES]
    mismatches = []

    with psycopg.connect(url, client_encoding="utf8") as conn, conn.cursor() as cur:
        cur.execute(
            sql.SQL("TRUNCATE {} CASCADE").format(
                sql.SQL(", ").join(map(sql.Identifier, table_names))
            )
        )

        for table, filename, expected in TABLES:
            print(f"Loading {table:<35}", end="", flush=True)
            copy_csv(cur, table, DATA_DIR / filename)
            cur.execute(sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier(table)))
            actual = cur.fetchone()[0]
            status = "ok" if actual == expected else f"MISMATCH (expected {expected:,})"
            print(f"{actual:>10,} rows  {status}")
            if actual != expected:
                mismatches.append(table)

        if mismatches:
            conn.rollback()
            print(f"\nRow counts differ for: {', '.join(mismatches)}. Rolled back; nothing was loaded.")
            return 1

    # Refresh planner statistics after a bulk load (must run outside a transaction).
    with psycopg.connect(url, autocommit=True) as conn:
        conn.execute("ANALYZE")

    print("\nAll tables loaded and verified.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
