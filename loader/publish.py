import os

import psycopg2


def main():
    connection = psycopg2.connect(
        host=os.getenv("DB_HOST", "postgres"),
        port=5432,
        dbname=os.getenv("DB_NAME", "road_safety"),
        user=os.getenv("DB_USER", "dwh"),
        password=os.getenv("DB_PASSWORD", "dwh_password"),
    )

    sql = """
    BEGIN;

    DROP TABLE IF EXISTS candidate.mart_daily_road;

    CREATE TABLE candidate.mart_daily_road AS
    SELECT *
    FROM dbt_mart.mart_daily_road;

    DROP TABLE IF EXISTS published.mart_daily_road;

    CREATE TABLE published.mart_daily_road AS
    SELECT *
    FROM candidate.mart_daily_road;

    COMMIT;
    """

    try:
        with connection:
            with connection.cursor() as cursor:
                cursor.execute(sql)

        print("Publication completed successfully.")

    finally:
        connection.close()


if __name__ == "__main__":
    main()