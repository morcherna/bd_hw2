import csv
import os
from datetime import datetime

import psycopg2


CSV_PATH = "/app/data/source/collisions_2025_january.csv"


def main():
    connection = psycopg2.connect(
        host=os.getenv("DB_HOST", "postgres"),
        port=5432,
        dbname="road_safety",
        user="dwh",
        password="dwh_password",
    )

    with connection:
        with connection.cursor() as cursor:
            cursor.execute("TRUNCATE TABLE raw.raw_collisions;")

            with open(CSV_PATH, encoding="utf-8-sig", newline="") as file:
                reader = csv.DictReader(file)

                for row in reader:
                    cursor.execute(
                        """
                        INSERT INTO raw.raw_collisions (
                            collision_index,
                            collision_year,
                            collision_ref_no,
                            longitude,
                            latitude,
                            collision_severity,
                            number_of_vehicles,
                            number_of_casualties,
                            date,
                            day_of_week,
                            time,
                            first_road_class,
                            first_road_number,
                            road_type,
                            speed_limit,
                            urban_or_rural_area,
                            collision_severity_label,
                            day_of_week_label,
                            road_type_label,
                            urban_or_rural_area_label
                        )
                        VALUES (
                            %s, %s, %s, %s, %s,
                            %s, %s, %s, %s, %s,
                            %s, %s, %s, %s, %s,
                            %s, %s, %s, %s, %s
                        )
                        """,
                        (
                            row["collision_index"],
                            int(row["collision_year"]),
                            row["collision_ref_no"],
                            float(row["longitude"]) if row["longitude"] else None,
                            float(row["latitude"]) if row["latitude"] else None,
                            int(row["collision_severity"])
                            if row["collision_severity"]
                            else None,
                            int(row["number_of_vehicles"])
                            if row["number_of_vehicles"]
                            else None,
                            int(row["number_of_casualties"])
                            if row["number_of_casualties"]
                            else None,
                            datetime.strptime(
                                row["date"], "%d/%m/%Y"
                            ).date(),
                            int(row["day_of_week"])
                            if row["day_of_week"]
                            else None,
                            datetime.strptime(
                                row["time"], "%H:%M"
                            ).time()
                            if row["time"]
                            else None,
                            int(row["first_road_class"])
                            if row["first_road_class"]
                            else None,
                            int(row["first_road_number"])
                            if row["first_road_number"]
                            else None,
                            int(row["road_type"])
                            if row["road_type"]
                            else None,
                            int(row["speed_limit"])
                            if row["speed_limit"]
                            else None,
                            int(row["urban_or_rural_area"])
                            if row["urban_or_rural_area"]
                            else None,
                            row["collision_severity_label"],
                            row["day_of_week_label"],
                            row["road_type_label"],
                            row["urban_or_rural_area_label"],
                        ),
                    )

            cursor.execute(
                "SELECT COUNT(*) FROM raw.raw_collisions;"
            )
            count = cursor.fetchone()[0]

            print(f"Loaded rows: {count}")


if __name__ == "__main__":
    main()