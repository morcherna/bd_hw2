###Road Safety DWH — ELT pipeline



##1. Вводная часть


Источник: UK Department for Transport, Road Safety Data — Collisions 2025.



Потребитель: аналитик по безопасности дорожного движения.



Основной вопрос:



Как меняются количество ДТП и число пострадавших в зависимости от дня недели и типа дороги?



Дополнительный вопрос:



Какие типы дорог имеют наибольшее количество серьёзных ДТП за контрольный период?


## 2. Исходные данные и контрольный срез



Для воспроизводимости используется небольшой фиксированный срез исходного набора:



```text

data/source/collisions\_2025\_january.csv

```



Период:



```text

01.01.2025 — 31.01.2025

```



Количество записей:



```text

8 163

```



Одна строка исходного набора соответствует одному зарегистрированному ДТП.



Полный исходный датасет использовался для получения контрольного среза, но не включается в проект из-за размера.







\## 3. Модель DWH



\### Grain



Факт `fct\_collisions` имеет grain:



одна строка = одно зарегистрированное ДТП, идентифицируемое `collision\_index`.



Маркет имеет grain:



одна строка = комбинация даты, дня недели и типа дороги.



\### Слои



```text

raw.raw\_collisions

&#x20;       |

&#x20;       v

dbt\_staging.stg\_collisions

&#x20;       |

&#x20;       +--------------------+

&#x20;       |                    |

&#x20;       v                    v

dbt\_dwh.dim\_date       dbt\_dwh.dim\_road

&#x20;       |                    |

&#x20;       +---------+----------+

&#x20;                 |

&#x20;                 v

&#x20;       dbt\_dwh.fct\_collisions

&#x20;                 |

&#x20;                 v

&#x20;       dbt\_mart.mart\_daily\_road

&#x20;                 |

&#x20;                 v

&#x20;       candidate.mart\_daily\_road

&#x20;                 |

&#x20;                 v

&#x20;       published.mart\_daily\_road

```



\### Таблицы



| Таблица                      | Grain                            | Ключ                          |

| ---------------------------- | -------------------------------- | ----------------------------- |

| `raw.raw\_collisions`         | одна исходная запись             | `collision\_index`             |

| `dbt\_staging.stg\_collisions` | одно ДТП                         | `collision\_index`             |

| `dbt\_dwh.dim\_date`           | одна календарная дата            | `date\_key`                    |

| `dbt\_dwh.dim\_road`           | одна комбинация атрибутов дороги | `road\_key`                    |

| `dbt\_dwh.fct\_collisions`     | одно ДТП                         | `collision\_index`             |

| `dbt\_mart.mart\_daily\_road`   | дата × день недели × тип дороги  | составной аналитический grain |

| `published.mart\_daily\_road`  | опубликованная строка mart       | тот же grain                  |



\### Историчность



SCD2 не используется.



Причина: рассматривается фиксированный событийный датасет за январь 2025 года. Изменение исторических версий справочных атрибутов не является предметом задачи. Требуется воспроизводимый аналитический snapshot, а не хранение истории изменений измерений.





\## 4. ELT



Используются:



\* PostgreSQL — хранение данных и выполнение SQL;

\* dbt — модели, трансформации и проверки качества;

\* Airflow — оркестрация;

\* Python loader — загрузка CSV;

\* Python publisher — публикация проверенного mart.



Последовательность DAG:



```text

load\_raw -> dbt\_run -> dbt\_test -> publish

```



Дата запуска DAG не используется как дата события. Период обработки явно задан в staging-модели:



```text

2025-01-01 <= collision\_date < 2025-02-01

```



Для предотвращения параллельных запусков используется:



```text

max\_active\_runs = 1

```





\## 5. Data Quality



В проекте реализованы проверки:



\### Staging



\* `collision\_index` NOT NULL;

\* `collision\_index` UNIQUE;

\* `collision\_date` NOT NULL;

\* `road\_type\_label` NOT NULL.



\### DWH



\* surrogate keys NOT NULL;

\* surrogate keys UNIQUE;

\* `collision\_index` NOT NULL и UNIQUE;

\* foreign key `fct\_collisions.date\_key -> dim\_date.date\_key`;

\* foreign key `fct\_collisions.road\_key -> dim\_road.road\_key`;

\* допустимые значения severity: `Fatal`, `Serious`, `Slight`.



\### Business rule



Отдельный SQL-тест:



```text

dbt/tests/business\_rule\_casualties.sql

```



проверяет, что количество пострадавших не является отрицательным.



Чистая сборка:



```text

PASS=21

WARN=0

ERROR=0

SKIP=0

TOTAL=21

```





\## 6. Четыре DQ-сценария



Каждый сценарий запускался независимо от чистого входа.



| Сценарий      | Изменение                   | Ожидаемый результат             | Фактический результат                            |

| ------------- | --------------------------- | ------------------------------- | ------------------------------------------------ |

| Duplicate key | добавлена копия записи      | `unique` должен упасть          | `unique\_stg\_collisions\_collision\_index` FAILED   |

| NULL          | `road\_type\_label = NULL`    | `not\_null` должен упасть        | `not\_null\_stg\_collisions\_road\_type\_label` FAILED |

| Invalid value | severity = `Unknown`        | `accepted\_values` должен упасть | accepted-values test FAILED                      |

| Business rule | `number\_of\_casualties = -1` | business-rule должен упасть     | `business\_rule\_casualties` FAILED                |



После каждого сценария данные восстанавливались из чистого CSV.



SQL для сценариев находится в:



```text

sql/dq\_scenarios.sql

```





\## 7. Candidate / Published



Публикация отделена от построения candidate.



Схема:



```text

dbt\_mart.mart\_daily\_road

&#x20;         |

&#x20;         v

candidate.mart\_daily\_road

&#x20;         |

&#x20;         v

published.mart\_daily\_road

```



`publish` является последним task DAG и запускается только после успешного `dbt\_test`.



Следовательно, если DQ-проверка завершается ошибкой:



```text

dbt\_test = failed

publish = upstream\_failed

```



и предыдущая опубликованная версия остаётся доступной потребителю.





\## 8. Финальный результат



Финальная опубликованная таблица:



| Метрика            | Значение |

| ------------------ | -------: |

| rows               |      186 |

| collisions         |    8 163 |

| casualties         |   10 116 |

| serious collisions |    1 867 |

| vehicles           |   14 506 |



Размеры DWH:



| Таблица           |  Rows |

| ----------------- | ----: |

| `dim\_date`        |    31 |

| `dim\_road`        |   171 |

| `fct\_collisions`  | 8 163 |

| `mart\_daily\_road` |   186 |





\## 9. Повторяемость



Один и тот же чистый вход был обработан дважды.



Результаты:



| Метрика            |  Run 1 |  Run 2 |

| ------------------ | -----: | -----: |

| Mart rows          |    186 |    186 |

| Collisions         |  8 163 |  8 163 |

| Casualties         | 10 116 | 10 116 |

| Serious collisions |  1 867 |  1 867 |

| Vehicles           | 14 506 | 14 506 |



Сравнение строк через `EXCEPT` в обе стороны:



```text

rows\_only\_in\_run1 = 0

rows\_only\_in\_run2 = 0

```



Следовательно, одинаковый вход даёт одинаковый результат.





\## 10. Независимый контроль



Количество строк исходного control slice:



```text

8 163

```



Количество строк raw:



```text

8 163

```



Количество строк fact:



```text

8 163

```



Таким образом, количество зарегистрированных ДТП сохраняется между raw и fact.



Важно: проверка уникальности ключа не доказывает полноту источника и отсутствие пропущенных записей.





\## 11. Ограничения



1\. Контрольный срез содержит только январь 2025 года.

2\. Проверка UNIQUE обнаруживает дубликаты, но не доказывает полноту источника.

3\. Airflow настроен локально через SequentialExecutor и SQLite metadata database; это учебная локальная конфигурация, а не production deployment.

4\. Историзация SCD2 не реализована, поскольку источник представляет фиксированный событийный snapshot.

5\. Candidate/published разделение защищает публикацию от проваливших DQ данных, но не заменяет контроль полноты исходного источника.





\## 12. Версии



Используемые версии:



```text

PostgreSQL 16

dbt-postgres 1.9.0

Airflow 2.10.5

Python 3.12

```





\## 13. Запуск



Из корня проекта:



```cmd

docker compose up -d postgres airflow

```



Загрузить контрольный срез:



```cmd

docker compose run --rm loader

```



Собрать модели и выполнить проверки:



```cmd

docker compose run --rm dbt build --project-dir /app/dbt --profiles-dir /app/dbt

```



Запустить полный ELT через Airflow:



```cmd

docker exec hw2-airflow airflow dags trigger road\_safety\_elt

```



Проверить запуск:



```cmd

docker exec hw2-airflow airflow dags list-runs -d road\_safety\_elt

```



Ожидаемая последовательность:



```text

load\_raw -> dbt\_run -> dbt\_test -> publish

```





\## 14. Структура проекта



```text

student-Mukovozova-hw2/

├── airflow/

│   └── dags/

│       └── road\_safety\_elt.py

├── data/

│   ├── source/

│   │   └── collisions\_2025\_january.csv

│   └── test\_cases/

├── dbt/

│   ├── dbt\_project.yml

│   ├── profiles.yml

│   ├── models/

│   │   ├── staging/

│   │   ├── dwh/

│   │   └── marts/

│   └── tests/

│       └── business\_rule\_casualties.sql

├── loader/

│   ├── load\_raw.py

│   └── publish.py

├── report/

├── screenshots/

├── sql/

├── docker-compose.yml

└── README.md

```





\## 15. Итог



Проект реализует воспроизводимый локальный ELT-процесс:



```text

CSV

&#x20;↓

PostgreSQL raw

&#x20;↓

dbt staging

&#x20;↓

DWH dimensions + fact

&#x20;↓

mart

&#x20;↓

DQ checks

&#x20;↓

candidate

&#x20;↓

published

```



Для чистого входа все проверки проходят, одинаковый вход даёт одинаковый результат, а не прошедшие DQ данные не заменяют предыдущую публикацию.



