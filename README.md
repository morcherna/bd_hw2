# Road Safety DWH — ELT pipeline

## 1. Вводная часть

Источник: UK Department for Transport, Road Safety Data — Collisions 2025.

Потребитель: аналитик по безопасности дорожного движения.

Основной вопрос:

Как меняются количество ДТП и число пострадавших в зависимости от дня недели и типа дороги?

Дополнительный вопрос:

Какие типы дорог имеют наибольшее количество серьёзных ДТП за контрольный период?

## 2. Исходные данные и контрольный срез

Для воспроизводимости используется небольшой фиксированный срез исходного набора:

    data/source/collisions_2025_january.csv

Период:

    01.01.2025 — 31.01.2025

Количество записей:

    8 163

Одна строка исходного набора соответствует одному зарегистрированному ДТП.

Полный исходный датасет использовался для получения контрольного среза, но не включается в проект из-за размера.

## 3. Модель DWH

### Grain

Факт `fct_collisions` имеет grain:

одна строка = одно зарегистрированное ДТП, идентифицируемое `collision_index`.

Маркет имеет grain:

одна строка = комбинация даты, дня недели и типа дороги.

### Слои

    raw.raw_collisions
            |
            v
    dbt_staging.stg_collisions
            |
            +--------------------+
            |                    |
            v                    v
    dbt_dwh.dim_date       dbt_dwh.dim_road
            |                    |
            +---------+----------+
                      |
                      v
            dbt_dwh.fct_collisions
                      |
                      v
            dbt_mart.mart_daily_road
                      |
                      v
            candidate.mart_daily_road
                      |
                      v
            published.mart_daily_road

### Таблицы

| Таблица | Grain | Ключ |
| --- | --- | --- |
| `raw.raw_collisions` | одна исходная запись | `collision_index` |
| `dbt_staging.stg_collisions` | одно ДТП | `collision_index` |
| `dbt_dwh.dim_date` | одна календарная дата | `date_key` |
| `dbt_dwh.dim_road` | одна комбинация атрибутов дороги | `road_key` |
| `dbt_dwh.fct_collisions` | одно ДТП | `collision_index` |
| `dbt_mart.mart_daily_road` | дата × день недели × тип дороги | составной аналитический grain |
| `published.mart_daily_road` | опубликованная строка mart | тот же grain |

### Историчность

SCD2 не используется.

Причина: рассматривается фиксированный событийный датасет за январь 2025 года. Изменение исторических версий справочных атрибутов не является предметом задачи. Требуется воспроизводимый аналитический snapshot, а не хранение истории изменений измерений.

## 4. ELT

Используются:

- PostgreSQL — хранение данных и выполнение SQL;
- dbt — модели, трансформации и проверки качества;
- Airflow — оркестрация;
- Python loader — загрузка CSV;
- Python publisher — публикация проверенного mart.

Последовательность DAG:

    load_raw -> dbt_run -> dbt_test -> publish

Дата запуска DAG не используется как дата события. Период обработки явно задан в staging-модели:

    2025-01-01 <= collision_date < 2025-02-01

Для предотвращения параллельных запусков используется:

    max_active_runs = 1

## 5. Data Quality

В проекте реализованы проверки:

### Staging

- `collision_index` NOT NULL;
- `collision_index` UNIQUE;
- `collision_date` NOT NULL;
- `road_type_label` NOT NULL.

### DWH

- surrogate keys NOT NULL;
- surrogate keys UNIQUE;
- `collision_index` NOT NULL и UNIQUE;
- foreign key `fct_collisions.date_key -> dim_date.date_key`;
- foreign key `fct_collisions.road_key -> dim_road.road_key`;
- допустимые значения severity: `Fatal`, `Serious`, `Slight`.

### Business rule

Отдельный SQL-тест:

    dbt/tests/business_rule_casualties.sql

проверяет, что количество пострадавших не является отрицательным.

Чистая сборка:

    PASS=21
    WARN=0
    ERROR=0
    SKIP=0
    TOTAL=21

## 6. Четыре DQ-сценария

Каждый сценарий запускался независимо от чистого входа.

| Сценарий | Изменение | Ожидаемый результат | Фактический результат |
| --- | --- | --- | --- |
| Duplicate key | добавлена копия записи | `unique` должен упасть | `unique_stg_collisions_collision_index` FAILED |
| NULL | `road_type_label = NULL` | `not_null` должен упасть | `not_null_stg_collisions_road_type_label` FAILED |
| Invalid value | severity = `Unknown` | `accepted_values` должен упасть | accepted-values test FAILED |
| Business rule | `number_of_casualties = -1` | business-rule должен упасть | `business_rule_casualties` FAILED |

После каждого сценария данные восстанавливались из чистого CSV.

SQL для сценариев находится в:

    sql/dq_scenarios.sql

## 7. Candidate / Published

Публикация отделена от построения candidate.

Схема:

    dbt_mart.mart_daily_road
             |
             v
    candidate.mart_daily_road
             |
             v
    published.mart_daily_road

`publish` является последним task DAG и запускается только после успешного `dbt_test`.

Следовательно, если DQ-проверка завершается ошибкой:

    dbt_test = failed
    publish = upstream_failed

и предыдущая опубликованная версия остаётся доступной потребителю.

## 8. Финальный результат

Финальная опубликованная таблица:

| Метрика | Значение |
| --- | ---: |
| rows | 186 |
| collisions | 8 163 |
| casualties | 10 116 |
| serious collisions | 1 867 |
| vehicles | 14 506 |

Размеры DWH:

| Таблица | Rows |
| --- | ---: |
| `dim_date` | 31 |
| `dim_road` | 171 |
| `fct_collisions` | 8 163 |
| `mart_daily_road` | 186 |

## 9. Повторяемость

Один и тот же чистый вход был обработан дважды.

Результаты:

| Метрика | Run 1 | Run 2 |
| --- | ---: | ---: |
| Mart rows | 186 | 186 |
| Collisions | 8 163 | 8 163 |
| Casualties | 10 116 | 10 116 |
| Serious collisions | 1 867 | 1 867 |
| Vehicles | 14 506 | 14 506 |

Сравнение строк через `EXCEPT` в обе стороны:

    rows_only_in_run1 = 0
    rows_only_in_run2 = 0

Следовательно, одинаковый вход даёт одинаковый результат.

## 10. Независимый контроль

Количество строк исходного control slice:

    8 163

Количество строк raw:

    8 163

Количество строк fact:

    8 163

Таким образом, количество зарегистрированных ДТП сохраняется между raw и fact.

Важно: проверка уникальности ключа не доказывает полноту источника и отсутствие пропущенных записей.

## 11. Ограничения

1. Контрольный срез содержит только январь 2025 года.
2. Проверка UNIQUE обнаруживает дубликаты, но не доказывает полноту источника.
3. Airflow настроен локально через SequentialExecutor и SQLite metadata database; это учебная локальная конфигурация, а не production deployment.
4. Историзация SCD2 не реализована, поскольку источник представляет фиксированный событийный snapshot.
5. Candidate/published разделение защищает публикацию от проваливших DQ данных, но не заменяет контроль полноты исходного источника.

## 12. Версии

Используемые версии:

    PostgreSQL 16
    dbt-postgres 1.9.0
    Airflow 2.10.5
    Python 3.12

## 13. Запуск

Из корня проекта:

    docker compose up -d postgres airflow

Загрузить контрольный срез:

    docker compose run --rm loader

Собрать модели и выполнить проверки:

    docker compose run --rm dbt build --project-dir /app/dbt --profiles-dir /app/dbt

Запустить полный ELT через Airflow:

    docker exec hw2-airflow airflow dags trigger road_safety_elt

Проверить запуск:

    docker exec hw2-airflow airflow dags list-runs -d road_safety_elt

Ожидаемая последовательность:

    load_raw -> dbt_run -> dbt_test -> publish

## 14. Структура проекта

    student-Mukovozova-hw2/
    ├── airflow/
    │   └── dags/
    │       └── road_safety_elt.py
    ├── data/
    │   ├── source/
    │   │   └── collisions_2025_january.csv
    │   └── test_cases/
    ├── dbt/
    │   ├── dbt_project.yml
    │   ├── profiles.yml
    │   ├── models/
    │   │   ├── staging/
    │   │   ├── dwh/
    │   │   └── marts/
    │   └── tests/
    │       └── business_rule_casualties.sql
    ├── loader/
    │   ├── load_raw.py
    │   └── publish.py
    ├── report/
    ├── screenshots/
    ├── sql/
    ├── docker-compose.yml
    └── README.md

## 15. Итог

Проект реализует воспроизводимый локальный ELT-процесс:

    CSV
     ↓
    PostgreSQL raw
     ↓
    dbt staging
     ↓
    DWH dimensions + fact
     ↓
    mart
     ↓
    DQ checks
     ↓
    candidate
     ↓
    published

Для чистого входа все проверки проходят, одинаковый вход даёт одинаковый результат, а не прошедшие DQ данные не заменяют предыдущую публикацию.
