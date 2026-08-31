# Архитектурный поток данных (Model Flow)

Документ описывает логическую структуру проекта `DWH_Relational_Model` и взаимосвязь его компонентов.

Проект объединяет три инженерных блока:
1. **Подготовительный слой (ETL utilities):** инструменты преобразования многострочных значений в структурированные строки до этапа нормализации.
2. **Основной реляционный конвейер:** сквозное моделирование от ненормализованного источника (0NF) через 1NF–3NF к историзированной аналитической витрине (SCD Type 2 + Fact table).
3. **Data Vault 2.0:** отдельный учебный блок классического моделирования (Staging → Hubs → Links → Satellites).

```mermaid
flowchart TD
    subgraph S0 ["0. Подготовительные инструменты (ETL Tools)"]
        direction TB
        E1["explode_multivalue_columns.sql<br/>(unnest WITH ORDINALITY)"]
        E2["explode_with_generate_series.sql<br/>(generate_series по индексам)"]
        E_NOTE["Техническая подготовка multivalue data<br/>до логического моделирования"]
        E1 ~~~ E_NOTE
        E2 ~~~ E_NOTE
    end
```

```mermaid
flowchart TD
    subgraph S1 ["1. Реляционное моделирование и аналитический слой"]
        direction TB
        NF0["<b>0NF: Сырой источник</b><br/>courses_0nf<br/>(составные поля: student_info, course_info...)"]
        
        NF1["<b>1NF: Атомарные атрибуты</b><br/>courses_1nf<br/>(split_part, PK: student_email + course_name + order_date)"]
        
        NF2["<b>2NF: Устранение частичных зависимостей</b><br/>student_2nf | course_2nf | orders_2nf"]
        
        NF3["<b>3NF: Устранение транзитивных зависимостей</b><br/>student_3nf | cities_3nf | teachers_3nf<br/>course_3nf | payment_methods_3nf | payment_statuses_3nf<br/>orders_3nf"]
        
        SCD2["<b>SCD Type 2: Историзация измерений</b><br/>student_3nf_scd2 | cities_3nf_scd2<br/>teachers_3nf_scd2 | courses_3nf_scd2<br/>(surrogate keys, valid_from/to, is_current)"]
        
        FACT["<b>Аналитический факт</b><br/>orders_3nf_fact<br/>(FK на SCD2 surrogate keys и payment ref)"]

        NF0 -->|"Парсинг составных строк (split_part)"| NF1
        NF1 -->|"Декомпозиция по составному PK"| NF2
        NF2 -->|"Вынос справочников и транзитивных FK"| NF3
        NF3 -->|"Добавление SK, интервалов версий и partial unique index"| SCD2
        SCD2 -->|"Сборка фактов заказов по суррогатным ключам"| FACT
    end
```

```mermaid
flowchart TD
    subgraph S2 ["2. Data Vault 2.0 (Учебная ветка)"]
        direction TB
        DV_STG["<b>Staging</b><br/>stg_orders"]
        DV_HUB["<b>Hubs (Бизнес-сущности)</b><br/>hub_customer | hub_order | hub_product"]
        DV_LNK["<b>Links (Связи сущностей)</b><br/>link_customer_order | link_order_product"]
        DV_SAT["<b>Satellites (Контекст и история)</b><br/>sat_customer | sat_order<br/>sat_product | sat_order_product"]

        DV_STG -->|"Выделение бизнес-ключей (Hash Key)"| DV_HUB
        DV_STG -->|"Связывание хэш-ключей"| DV_LNK
        DV_STG -->|"Атрибуты + Hash Diff (Insert-Only)"| DV_SAT
    end
```

---

### Особенности реализации

- **Связь ETL Tools и 0NF:** инструменты каталога `etl_tools` демонстрируют техники позиционного разбора списков и строк массивов в PostgreSQL. Они логически предваряют нормализацию, но не связаны с `0NF.sql` через автоматический пайплайн.
- **Изоляция Data Vault:** ветка `DataVault/` представляет собой самостоятельную альтернативную реализацию модели хранилища и не использует таблицы схемы `3NF_SCD2`.
