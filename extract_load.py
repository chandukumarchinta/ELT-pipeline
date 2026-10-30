"""Part 1: Extract and Load (Python).

Extracts raw Titanic data from seaborn, appends ELT audit metadata
(load_timestamp, batch_id), and loads into MySQL table `raw_titanic`
without altering any raw values or dropping nulls.
Idempotent: uses if_exists='replace' so repeated runs do not duplicate rows.
"""

from datetime import datetime
import uuid
import pandas as pd
import seaborn as sns
from config import get_sqlalchemy_engine


def extract_and_load(table_name: str = "raw_titanic") -> str:
    """Extract raw Titanic dataset from seaborn and load into MySQL raw layer.

    Returns the generated batch_id for tracking.
    """
    print("[ELT Extract] Loading raw Titanic dataset from seaborn...")
    df = sns.load_dataset("titanic")
    extracted_rows, extracted_cols = df.shape
    print(f"[ELT Extract] Successfully extracted {extracted_rows} rows and {extracted_cols} columns.")

    # Rule: Keep all raw data unchanged; add strictly two audit columns
    batch_id = f"batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:6]}"
    load_timestamp = pd.Timestamp.now()

    df["load_timestamp"] = load_timestamp
    df["batch_id"] = batch_id

    print(f"[ELT Load] Loading into MySQL table `{table_name}` (Batch ID: {batch_id})...")
    engine = get_sqlalchemy_engine()

    # Rule: Running twice must NOT cause duplicate rows.
    # if_exists='replace' drops and recreates raw_titanic cleanly.
    df.to_sql(table_name, con=engine, if_exists="replace", index=False)
    print(f"[ELT Load] Successfully loaded {len(df)} records into `{table_name}` table.")

    return batch_id


if __name__ == "__main__":
    batch_id = extract_and_load()
    print(f"Extraction and Load finished successfully with batch: {batch_id}")

