# Upload 60 monthly CSV files to BigQuery raw layer

import os
import glob
import json
import logging
import csv
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
from google.cloud import bigquery
from tqdm import tqdm

# Configuration
PROJECT_ID   = "us-aviation-analytics"
DATASET_ID   = "raw"
TABLE_ID     = "on_time_performance"
RAW_PATH     = "data/raw/on_time/"
LOG_PATH     = "bigquery/logs/"
YEARS        = range(2019, 2024)

# Logging Setup
os.makedirs(LOG_PATH, exist_ok=True)

log_filename = os.path.join(
    LOG_PATH,
    f"upload_ontime_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s',
    handlers=[
        logging.FileHandler(log_filename),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

# Schema Definition
# Dtype map untuk pandas — penting agar kolom numerik tidak
# di-infer secara salah oleh pandas.
DTYPE_MAP = {
    'YEAR':                  'Int32',
    'QUARTER':               'Int8',
    'MONTH':                 'Int8',
    'DAY_OF_MONTH':          'Int8',
    'DAY_OF_WEEK':           'Int8',
    'OP_UNIQUE_CARRIER':     'str',
    'OP_CARRIER':            'str',
    'TAIL_NUM':              'str',
    'OP_CARRIER_FL_NUM':     'Int64',
    'ORIGIN_AIRPORT_ID':     'Int64',
    'ORIGIN':                'str',
    'ORIGIN_CITY_NAME':      'str',
    'ORIGIN_STATE_ABR':      'str',
    'DEST_AIRPORT_ID':       'Int64',
    'DEST':                  'str',
    'DEST_CITY_NAME':        'str',
    'DEST_STATE_ABR':        'str',
    'CRS_DEP_TIME':          'Int64',
    'CRS_ARR_TIME':          'Int64',
    'DISTANCE_GROUP':        'Int64',
    'CANCELLATION_CODE':     'str',
}

# Kolom yang ada di CSV
EXPECTED_COLS = [
    'YEAR',
    'QUARTER',
    'MONTH',
    'DAY_OF_MONTH',
    'DAY_OF_WEEK',
    'FL_DATE',

    'OP_UNIQUE_CARRIER',
    'OP_CARRIER',
    'TAIL_NUM',
    'OP_CARRIER_FL_NUM',

    'ORIGIN_AIRPORT_ID',
    'ORIGIN',
    'ORIGIN_CITY_NAME',
    'ORIGIN_STATE_ABR',

    'DEST_AIRPORT_ID',
    'DEST',
    'DEST_CITY_NAME',
    'DEST_STATE_ABR',

    'CRS_DEP_TIME',
    'DEP_TIME',
    'DEP_DELAY',
    'DEP_DELAY_MINUTES',
    'DEP_DEL15',
    'DEP_DELAY_GROUPS',
    'TAXI_OUT',
    'WHEELS_OFF',
    'WHEELS_ON',
    'TAXI_IN',

    'CRS_ARR_TIME',
    'ARR_TIME',
    'ARR_DELAY',
    'ARR_DELAY_MINUTES',
    'ARR_DEL15',
    'ARR_DELAY_GROUPS',

    'CANCELLED',
    'CANCELLATION_CODE',
    'DIVERTED',

    'CRS_ELAPSED_TIME',
    'ACTUAL_ELAPSED_TIME',
    'AIR_TIME',

    'FLIGHTS',
    'DISTANCE',
    'DISTANCE_GROUP',

    'CARRIER_DELAY',
    'WEATHER_DELAY',
    'NAS_DELAY',
    'SECURITY_DELAY',
    'LATE_AIRCRAFT_DELAY'
]


def load_csv_to_dataframe(filepath: str) -> pd.DataFrame:
    """
    Load one monthly CSV file into a pandas DataFrame.
    Adds metadata columns for lineage tracking.
    """
    filename = os.path.basename(filepath)
    loaded_at = datetime.now(timezone.utc)

    df = pd.read_csv(
        filepath,
        dtype=DTYPE_MAP,
        parse_dates=['FL_DATE'],
        low_memory=False
    )

    # Remove BTS trailing empty column (they sometimes add one)
    df = df.loc[:, ~df.columns.str.startswith('Unnamed')]

    # Subset to expected columns only (defensive: ignore any extra BTS cols)
    available_cols = [c for c in EXPECTED_COLS if c in df.columns]
    df = df[available_cols]

    # Add metadata columns for data lineage
    df['_loaded_at']   = loaded_at
    df['_source_file'] = filename

    return df


def upload_dataframe_to_bigquery(
    client: bigquery.Client,
    df: pd.DataFrame,
    table_ref: str,
    year: int,
    month: int
) -> int:
    """
    Upload a pandas DataFrame to BigQuery using load_table_from_dataframe.
    Uses WRITE_APPEND to add to existing partitions.
    Returns number of rows uploaded.
    """
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        # Schema is auto-detected from existing table
        # Partitioning already defined on the table
    )

    job = client.load_table_from_dataframe(
        df,
        table_ref,
        job_config=job_config
    )

    job.result()

    # Verify by querying the count for this specific partition
    query = f"""
        SELECT COUNT(*) as row_count
        FROM `{table_ref}`
        WHERE FL_DATE BETWEEN '{year}-{month:02d}-01'
          AND DATE_TRUNC(
                DATE_ADD(
                    DATE('{year}-{month:02d}-01'),
                    INTERVAL 1 MONTH
                ),
                MONTH
              ) - INTERVAL 1 DAY
    """

    result = client.query(query).result()
    bq_count = list(result)[0].row_count

    return bq_count


def log_result(
    log_records: list,
    year: int,
    month: int,
    filename: str,
    csv_rows: int,
    bq_rows: int,
    status: str,
    error: str = ""
):
    """Append a result record to the tracking log."""
    log_records.append({
        'year':        year,
        'month':       month,
        'filename':    filename,
        'csv_rows':    csv_rows,
        'bq_rows':     bq_rows,
        'match':       csv_rows == bq_rows,
        'status':      status,
        'error':       error,
        'uploaded_at': datetime.now(timezone.utc).isoformat()
    })


def save_log(log_records: list):
    """Save upload log to CSV for audit purposes."""
    log_df = pd.DataFrame(log_records)

    log_file = os.path.join(
        LOG_PATH,
        f"upload_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    )

    log_df.to_csv(log_file, index=False)

    logger.info(f"Upload log saved: {log_file}")

    return log_file


def main():
    logger.info("=" * 65)
    logger.info(" US Aviation Analytics — BigQuery Raw Layer Upload")
    logger.info("=" * 65)
    logger.info(f" Project  : {PROJECT_ID}")
    logger.info(f" Table    : {PROJECT_ID}.{DATASET_ID}.{TABLE_ID}")
    logger.info(f" Period   : {min(YEARS)}-01 → {max(YEARS)}-12")
    logger.info("=" * 65)

    # Initialize BigQuery client
    client = bigquery.Client(project=PROJECT_ID)

    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"

    # Collect all files to process
    all_files = []

    for year in YEARS:
        for month in range(1, 13):

            pattern = os.path.join(
                RAW_PATH,
                f"ontime_{year}_{month:02d}.csv"
            )

            files = glob.glob(pattern)

            if files:
                all_files.append(
                    (year, month, files[0])
                )
            else:
                logger.warning(
                    f"File not found: "
                    f"ontime_{year}_{month:02d}.csv"
                )

    logger.info(
        f" Files found: {len(all_files)} / 60 expected"
    )

    logger.info("")

    if not all_files:
        logger.error(
            "No files found. Check RAW_PATH and filename format."
        )
        return

    # Main Upload Loop
    log_records = []
    success_count = 0
    fail_count = 0

    for year, month, filepath in tqdm(
        all_files,
        desc="Uploading",
        unit="file"
    ):

        filename = os.path.basename(filepath)

        logger.info(
            f"Processing: {filename}"
        )

        try:

            # Load CSV
            df = load_csv_to_dataframe(filepath)

            csv_rows = len(df)

            logger.info(
                f"  CSV rows loaded: {csv_rows:,}"
            )

            # Upload to BigQuery
            bq_rows = upload_dataframe_to_bigquery(
                client,
                df,
                table_ref,
                year,
                month
            )

            # Reconciliation check
            if csv_rows == bq_rows:

                status = "SUCCESS"

                logger.info(
                    f"   {filename}: "
                    f"{csv_rows:,} rows → "
                    f"BQ verified {bq_rows:,} rows"
                )

                success_count += 1

            else:

                status = "ROW_MISMATCH"

                logger.warning(
                    f"   ROW MISMATCH: "
                    f"CSV={csv_rows:,}, "
                    f"BQ={bq_rows:,}"
                )

                fail_count += 1

            log_result(
                log_records,
                year,
                month,
                filename,
                csv_rows,
                bq_rows,
                status
            )

        except Exception as e:

            logger.error(
                f"   FAILED: "
                f"{filename} — {str(e)}"
            )

            log_result(
                log_records,
                year,
                month,
                filename,
                0,
                0,
                "FAILED",
                str(e)
            )

            fail_count += 1

    # Final Summary
    logger.info("")

    logger.info("=" * 65)
    logger.info(" Upload Complete")
    logger.info(
        f"    Success : {success_count} files"
    )
    logger.info(
        f"    Failed  : {fail_count} files"
    )
    logger.info("=" * 65)

    log_file = save_log(log_records)

    logger.info(
        f" Log saved : {log_file}"
    )

    if fail_count > 0:

        logger.warning(
            "  Some files failed. "
            "Review log and re-run failed files."
        )

    else:

        logger.info(
            " 🎉 All files uploaded successfully!"
        )


if __name__ == "__main__":
    main()