# ER-диаграмма реляционной модели (3NF + SCD2 + Fact)

Диаграмма отражает фактическую структуру и связи целевой модели данных, реализованной в скриптах `3NF/3NF.sql` и `3NF_SCD2/DDL_3NF_SCD2.sql`.

```mermaid
erDiagram
    cities_3nf_scd2 ||--o{ student_3nf_scd2 : "contains"
    teachers_3nf_scd2 ||--o{ courses_3nf_scd2 : "leads"
    
    student_3nf_scd2 ||--o{ orders_3nf_fact : "places"
    courses_3nf_scd2 ||--o{ orders_3nf_fact : "includes"
    payment_methods_3nf ||--o{ orders_3nf_fact : "paid_via"
    payment_statuses_3nf ||--o{ orders_3nf_fact : "status"

    cities_3nf_scd2 {
        serial city_sk PK "Surrogate Key"
        varchar city_name "Business Key"
        varchar region
        date valid_from
        date valid_to
        boolean is_current
    }

    student_3nf_scd2 {
        serial student_sk PK "Surrogate Key"
        varchar student_email "Business Key"
        varchar student_name
        varchar student_phone
        integer city_sk FK
        date valid_from
        date valid_to
        boolean is_current
    }

    teachers_3nf_scd2 {
        serial teacher_sk PK "Surrogate Key"
        varchar teacher_email "Business Key"
        varchar teacher_name
        date valid_from
        date valid_to
        boolean is_current
    }

    courses_3nf_scd2 {
        serial course_sk PK "Surrogate Key"
        varchar course_name "Business Key"
        varchar course_category
        numeric course_price
        integer teacher_sk FK
        date valid_from
        date valid_to
        boolean is_current
    }

    payment_methods_3nf {
        serial payment_method_id PK
        varchar payment_method_name UK
    }

    payment_statuses_3nf {
        serial payment_status_id PK
        varchar payment_status_name UK
    }

    orders_3nf_fact {
        serial order_sk PK "Surrogate Key"
        date order_date
        integer student_sk FK
        integer course_sk FK
        integer payment_method_id FK
        integer payment_status_id FK
    }

```

---

### Архитектурные детали реализации

1. **Разделение ключей (SK vs BK):**
* В таблицах измерений используются целочисленные суррогатные ключи (`*_sk`), формирующие первичный ключ версии записи.
* Бизнес-ключи (`student_email`, `course_name`, `teacher_email`, `city_name`) сохраняются для идентификации бизнес-объекта во времени.


2. **Контроль актуальности версий:**
* Каждая историзированная таблица использует атрибуты версионирования: `valid_from`, `valid_to` (значение `9999-12-31` для активной версии) и флаг `is_current`.
* Для предотвращения дублирования активных записей применяется частичный уникальный индекс:
```sql
CREATE UNIQUE INDEX ... ON <table> (business_key) WHERE is_current = true;

```

3. **Целостность связей факта:**
* Таблица `orders_3nf_fact` связывается непосредственно с версиями сущностей через внешние ключи на `student_sk` и `course_sk`, фиксируя срез данных на момент оформления заказа.

