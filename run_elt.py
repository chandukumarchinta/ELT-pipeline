"""Part 6: Automation Orchestrator for Titanic ELT Pipeline.

File: run_elt.py
Steps:
1. Runs extract and load (Python -> raw_titanic)
2. Runs the SQL transformation and analytics files in sequence:
   - sql/01_staging.sql
   - sql/02_transformation.sql
   - sql/03_analytics.sql
   - sql/04_data_quality.sql
3. Queries `dq_results` table and prints 'PASS' or 'FAIL' for each quality check.
"""

import os
import sys
from config import get_connection
from extract_load import extract_and_load

SQL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql")
SQL_PIPELINE_FILES = [
    "01_staging.sql",
    "02_transformation.sql",
    "03_analytics.sql",
    "04_data_quality.sql",
]


def split_sql_script(script_text: str):
    """Split a SQL script into executable individual statements.

    Strips inline and block comments and splits by semicolon delimiter.
    """
    cleaned_lines = []
    for line in script_text.splitlines():
        trimmed = line.strip()
        if trimmed.startswith("--"):
            continue
        cleaned_lines.append(line)
    cleaned_content = "\n".join(cleaned_lines)

    statements = []
    for raw_stmt in cleaned_content.split(";"):
        stmt = raw_stmt.strip()
        if stmt:
            statements.append(stmt)
    return statements


def execute_sql_file(conn, file_path: str):
    """Read and execute all statements in a SQL script file."""
    base_name = os.path.basename(file_path)
    print(f"[SQL Runner] Executing `{base_name}`...")

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    statements = split_sql_script(content)
    cursor = conn.cursor()

    for idx, stmt in enumerate(statements, 1):
        try:
            cursor.execute(stmt)
        except Exception as e:
            conn.rollback()
            print(f"[ERROR] Failed executing statement #{idx} in `{base_name}`:")
            print(f"Statement:\n{stmt}\nError: {e}")
            raise e

    conn.commit()
    cursor.close()
    print(f"[SQL Runner] Successfully executed `{base_name}` ({len(statements)} statements).")


def run_data_quality_report(conn):
    """Fetch and print the PASS / FAIL status for each data quality check."""
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT check_name, status, checked_at FROM dq_results ORDER BY id ASC;")
    results = cursor.fetchall()
    cursor.close()

    print("\n" + "=" * 70)
    print("                    DATA QUALITY CHECK RESULTS")
    print("=" * 70)

    all_passed = True
    for r in results:
        status = r["status"]
        name = r["check_name"]
        timestamp = r["checked_at"]

        if status != "PASS":
            all_passed = False

        print(f"[{status}] {name} (Checked at: {timestamp})")

    print("=" * 70)
    if all_passed:
        print(">> ALL DATA QUALITY CHECKS PASSED!\n")
    else:
        print(">> WARNING: ONE OR MORE DATA QUALITY CHECKS FAILED!\n")

    return all_passed


def display_analytics_summary(conn):
    """Display quick summary rows from analytical views."""
    cursor = conn.cursor(dictionary=True)

    print("-" * 70)
    print("ANALYTICS PREVIEW: Survival Rate by Class and Sex")
    print("-" * 70)
    cursor.execute("SELECT passenger_class, sex_label, total_passengers, survived_passengers, survival_rate_pct FROM vw_survival_by_class_sex;")
    for row in cursor.fetchall():
        print(f"Class {row['passenger_class']} | {row['sex_label']:<6} | Total: {row['total_passengers']:>3} | Survived: {row['survived_passengers']:>3} | Rate: {row['survival_rate_pct']:>6.2f}%")

    print("\n" + "-" * 70)
    print("ANALYTICS PREVIEW: Survival Rate by Age Group")
    print("-" * 70)
    cursor.execute("SELECT age_group, total_passengers, survived_passengers, survival_rate_pct FROM vw_survival_by_age_group;")
    for row in cursor.fetchall():
        print(f"Age Group: {row['age_group']:<7} | Total: {row['total_passengers']:>3} | Survived: {row['survived_passengers']:>3} | Rate: {row['survival_rate_pct']:>6.2f}%")

    print("\n" + "-" * 70)
    print("ANALYTICS PREVIEW: Top 3 Highest Fares in Each Class")
    print("-" * 70)
    cursor.execute("SELECT passenger_class, fare_rank, passenger_id, sex_label, age, fare, fare_category FROM vw_top_3_fares_by_class;")
    for row in cursor.fetchall():
        print(f"Class {row['passenger_class']} | Rank #{row['fare_rank']} | ID: {row['passenger_id']:>3} | {row['sex_label']:<6} | Age: {float(row['age']):>5.1f} | Fare: ${float(row['fare']):>8.2f} | Category: {row['fare_category']}")

    cursor.close()


def main():
    print("=" * 70)
    print("           STARTING TITANIC ELT PIPELINE EXECUTION")
    print("=" * 70)

    # 1. Part 1: Extract and Load
    batch_id = extract_and_load(table_name="raw_titanic")

    # 2. Run SQL files in strict order
    conn = get_connection()
    try:
        for sql_file in SQL_PIPELINE_FILES:
            file_path = os.path.join(SQL_DIR, sql_file)
            execute_sql_file(conn, file_path)

        # 3. Part 5: Quality checks report
        all_passed = run_data_quality_report(conn)

        # 4. Display analytics preview
        display_analytics_summary(conn)

        if not all_passed:
            sys.exit(1)

    finally:
        conn.close()

    print("\n[Pipeline Complete] ELT pipeline finished successfully.")


if __name__ == "__main__":
    main()
