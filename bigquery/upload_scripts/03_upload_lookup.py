# PURPOSE : Upload airline and airport lookup tables to BigQuery

import os
import logging
from datetime import datetime, timezone

import pandas as pd
from google.cloud import bigquery

# Configuration
PROJECT_ID  = "us-aviation-analytics"
DATASET_ID  = "raw"
LOOKUP_PATH = "data/raw/lookup/"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s'
)
logger = logging.getLogger(__name__)


LOOKUPS = [
    {
        "file":       "L_AIRLINE_ID.csv",
        "table":      "airline_lookup",
        "columns":    ["Code", "Description"],
        "dtypes":     {"Code": "str", "Description": "str"},
        "desc":       "BTS Airline ID → full name lookup"
    },
    {
        "file":       "L_AIRPORT.csv",
        "table":      "airport_lookup",
        "columns":    ["Code", "Description"],
        "dtypes":     {"Code": "str", "Description": "str"},
        "desc":       "IATA Airport code → city/airport name lookup"
    }
]


def upload_lookup(client, filepath, table_id, columns, dtypes, desc):
    """Upload a lookup CSV to BigQuery, replacing existing data."""
    loaded_at = datetime.now(timezone.utc)

    df = pd.read_csv(filepath, dtype=dtypes)

    df = df[[c for c in columns if c in df.columns]]
    df['_loaded_at']   = loaded_at
    df['_source_file'] = os.path.basename(filepath)

    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{table_id}"

    job_config = bigquery.LoadJobConfig(
        # WRITE_TRUNCATE: Menggantikan lookup data yang ketika di  re-run
        # Lookup sizenya kecil dan sebaiknya refleksi dari versi terbaru
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    job = client.load_table_from_dataframe(df, table_ref, job_config=job_config)
    job.result()

    return len(df)


def main():
    logger.info("=" * 55)
    logger.info(" Uploading Lookup Tables")
    logger.info("=" * 55)

    client = bigquery.Client(project=PROJECT_ID)

    for lookup in LOOKUPS:
        filepath = os.path.join(LOOKUP_PATH, lookup["file"])

        if not os.path.exists(filepath):
            logger.warning(f"File not found: {filepath}")
            continue

        logger.info(f"  Processing: {lookup['file']}")

        try:
            rows = upload_lookup(
                client, filepath,
                lookup["table"],
                lookup["columns"],
                lookup["dtypes"],
                lookup["desc"]
            )
            logger.info(
                f"{lookup['table']}: {rows:,} rows uploaded "
                f"(WRITE_TRUNCATE)"
            )
        except Exception as e:
            logger.error(f"FAILED: {lookup['file']} — {e}")

    logger.info("=" * 55)
    logger.info(" Lookup upload complete.")
    logger.info("=" * 55)


if __name__ == "__main__":
    main()