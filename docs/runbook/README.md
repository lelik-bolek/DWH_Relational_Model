# Руководство по развертыванию и воспроизведению (Runbook)

Инструкция описывает пошаговый порядок ручного выполнения SQL-скриптов для воспроизведения полного цикла нормализации, построения SCD Type 2 и отдельной ветки Data Vault в СУБД PostgreSQL.

---

## 1. Системные требования
* **PostgreSQL:** версия 14 или выше.
* **Клиент СУБД:** `psql`, DBeaver, pgAdmin или любой совместимый инструмент.
* Доступ к локальной или удаленной базе данных с правами на создание таблиц, индексов и выполнение `COPY`.

---

## 2. Исходные данные
Основной набор сырых данных находится в каталоге `0NF/`:
* `0NF/data.csv` — CSV-файл с составными текстовыми полями (`student_info`, `course_info`, `teacher_info`, `payment_info`).

---

## 3. Регламент и последовательность выполнения

Выполняйте скрипты строго в указанном порядке.

### Шаг 3.1. Загрузка исходных ненормализованных данных (0NF)
1. Выполните скрипт создания таблицы `courses_0nf`:
   ```bash
   psql -d <db_name> -U <user> -f 0NF/0NF.sql

```

2. Загрузите сырые данные из CSV через команду `\copy` (путь к файлу укажите относительно рабочей директории):
```sql
\copy courses_0nf FROM '0NF/data.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');

```



### Шаг 3.2. Переход к 1NF

Выполните скрипт парсинга составных полей и выделения атомарных колонок:

```bash
psql -d <db_name> -U <user> -f 1NF/1NF.sql

```

*Создается и наполняется таблица `courses_1nf` с первичным ключом `(student_email, course_name, order_date)`.*

### Шаг 3.3. Декомпозиция в 2NF

Выполните скрипт устранения частичных функциональных зависимостей:

```bash
psql -d <db_name> -U <user> -f 2NF/2NF.sql

```

*Создаются и наполняются таблицы: `student_2nf`, `course_2nf`, `orders_2nf`.*

### Шаг 3.4. Нормализация до 3NF

Выполните скрипт устранения транзитивных зависимостей и выноса справочников:

```bash
psql -d <db_name> -U <user> -f 3NF/3NF.sql

```

*Создаются сущности: `cities_3nf`, `student_3nf`, `teachers_3nf`, `course_3nf`, `payment_methods_3nf`, `payment_statuses_3nf`, `orders_3nf`.*

### Шаг 3.5. Построение аналитического слоя с SCD Type 2

Выполните скрипт развертывания версионируемых таблиц и таблицы фактов:

```bash
psql -d <db_name> -U <user> -f 3NF_SCD2/DDL_3NF_SCD2.sql

```

*Создаются таблицы `*_3nf_scd2`, частичные уникальные индексы актуальности и витрина `orders_3nf_fact`.*

### Шаг 3.6. Проверка процедур обновления версий (SCD2 Updates)

Для демонстрации изменения атрибутов сущностей и закрытия версий выполните update-скрипты:

* `3NF_SCD2/update_cities_3nf_scd2.sql`
* `3NF_SCD2/update_student_3nf_scd2.sql`
* `3NF_SCD2/update_teachers_3nf_scd2.sql`
* `3NF_SCD2/update_courses_3nf_scd2.sql`

---

## 4. Запуск альтернативной ветки Data Vault 2.0

Скрипты Data Vault изолированы и не требуют предварительного выполнения этапов 1NF–3NF:

```bash
psql -d <db_name> -U <user> -f DataVault/schems.sql

```

*Скрипт развертывает Staging (`stg_orders`), Hubs (`hub_*`), Links (`link_*`) и Satellites (`sat_*`), демонстрируя концепцию Insert-Only моделирования.*

---

## 5. Использование утилит подготовки данных (`etl_tools`)

Скрипты в `etl_tools/` демонстрируют методы разбора составных строковых списков:

* `etl_tools/explode_multivalue_columns.sql` — разделение строк через `unnest(...) WITH ORDINALITY`.
* `etl_tools/explode_with_generate_series.sql` — позиционный разбор через `generate_series`.

Запуск выполняется независимо в среде PostgreSQL для демонстрации работы с массивами.

---

## 6. Проверочные запросы (Verification)

Проверка корректности историзации SCD2 (наличие закрытых и активных версий):

```sql
SELECT student_email, student_name, valid_from, valid_to, is_current 
FROM student_3nf_scd2 
ORDER BY student_email, valid_from;

```

Проверка целостности таблицы фактов:

```sql
SELECT 
    f.order_sk,
    f.order_date,
    s.student_email,
    c.course_name,
    pm.payment_method_name,
    ps.payment_status_name
FROM orders_3nf_fact f
JOIN student_3nf_scd2 s ON f.student_sk = s.student_sk
JOIN courses_3nf_scd2 c ON f.course_sk = c.course_sk
JOIN payment_methods_3nf pm ON f.payment_method_id = pm.payment_method_id
JOIN payment_statuses_3nf ps ON f.payment_status_id = ps.payment_status_id;

```
