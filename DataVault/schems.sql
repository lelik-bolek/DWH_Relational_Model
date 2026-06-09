/*****************************************************************************************
DATA VAULT 2.0 - УЧЕБНЫЙ ПРОЕКТ (STAGING → HUB → LINK → SATELLITE)

ПРИНЦИПЫ:
1. HUB      = идентичность (Business Keys → Hash Key)
2. LINK     = связи между сущностями (Hub ↔ Hub)
3. SATELLITE= история + атрибуты (изменяемые данные)
4. INSERT ONLY (никаких UPDATE в DV слоях)
5. Hash Diff используется ТОЛЬКО в Satellite
*****************************************************************************************/


/*****************************************************************************************
1. STAGING LAYER
*****************************************************************************************/

-- STAGING = сырые данные из источника (без бизнес-логики DV)

CREATE TABLE stg_orders
(
    customer_id     INTEGER,
    customer_name   VARCHAR(100),
    customer_city   VARCHAR(100),

    order_id        INTEGER,
    order_amount    NUMERIC(12,2),
    order_status    VARCHAR(50),

    product_id      INTEGER,
    product_name    VARCHAR(100),
    product_category VARCHAR(100),

    qty             INTEGER,
    price           NUMERIC(12,2),

    source_system   VARCHAR(50),
    load_dts        TIMESTAMP
);

-- LOAD STAGING (пример тестовых данных)
INSERT INTO stg_orders VALUES
(1,'Ivan','Moscow',100,1100,'NEW',10,'Phone','Electronics',2,500,'CRM','2026-06-01 10:00:00'),
(1,'Ivan','Moscow',100,1100,'NEW',11,'Book','Education',1,100,'CRM','2026-06-01 10:00:00'),
(2,'Alex','Berlin',101,500,'PAID',10,'Phone','Electronics',1,500,'CRM','2026-06-01 10:05:00'),
(3,'Maria','Paris',102,1200,'NEW',12,'Laptop','Electronics',1,1200,'CRM','2026-06-01 10:10:00'),
(4,'John','London',103,300,'PAID',13,'Chair','Furniture',2,150,'CRM','2026-06-01 10:15:00'),
(5,'Anna','Rome',104,50,'NEW',14,'Pen','Office',5,10,'CRM','2026-06-01 10:20:00');


/*****************************************************************************************
2. HUB LAYER (IDENTITY)
*****************************************************************************************/

-- HUB = только бизнес-ключ + hash key + metadata
-- ВАЖНО: никаких бизнес-атрибутов (name, city, status и т.д.)

CREATE TABLE IF NOT EXISTS hub_customer
(
    hk_customer     CHAR(32) PRIMARY KEY,
    customer_id     VARCHAR(100) NOT NULL,
    load_dts        TIMESTAMP NOT NULL,
    record_source   VARCHAR(50) NOT NULL
);

-- INSERT HUB CUSTOMER
-- ПРИНЦИП: INSERT ONLY + ON CONFLICT DO NOTHING
-- HUB не хранит историю, только уникальные бизнес-ключи

INSERT INTO hub_customer
SELECT DISTINCT
    md5(customer_id::varchar) AS hk_customer,
    customer_id,
    current_timestamp,
    source_system
FROM stg_orders
ON CONFLICT (hk_customer) DO NOTHING;


CREATE TABLE IF NOT EXISTS hub_order
(
    hk_order        CHAR(32) PRIMARY KEY,
    order_id        VARCHAR(100) NOT NULL,
    load_dts        TIMESTAMP NOT NULL,
    record_source   VARCHAR(50) NOT NULL
);

INSERT INTO hub_order
SELECT DISTINCT
    md5(order_id::varchar) AS hk_order,
    order_id,
    current_timestamp,
    source_system
FROM stg_orders
ON CONFLICT (hk_order) DO NOTHING;


CREATE TABLE IF NOT EXISTS hub_product
(
    hk_product      CHAR(32) PRIMARY KEY,
    product_id      VARCHAR(100) NOT NULL,
    load_dts        TIMESTAMP NOT NULL,
    record_source   VARCHAR(50) NOT NULL
);

INSERT INTO hub_product
SELECT DISTINCT
    md5(product_id::varchar) AS hk_product,
    product_id,
    current_timestamp,
    source_system
FROM stg_orders
ON CONFLICT (hk_product) DO NOTHING;


/*****************************************************************************************
3. LINK LAYER (RELATIONSHIPS)
*****************************************************************************************/

-- LINK = связь между HUB'ами
-- НЕ хранит бизнес-атрибуты
-- может содержать только FK на HUB + metadata

CREATE TABLE IF NOT EXISTS link_customer_order
(
    hk_customer_order CHAR(32) PRIMARY KEY,

    hk_customer CHAR(32) NOT NULL,
    hk_order    CHAR(32) NOT NULL,

    load_dts TIMESTAMP NOT NULL,
    record_source VARCHAR(50) NOT NULL
);

-- LINK CUSTOMER ↔ ORDER
-- ПРИНЦИП: связь считается по BUSINESS KEYS

INSERT INTO link_customer_order
SELECT DISTINCT
    md5(
        so.customer_id::varchar || '|' || so.order_id::varchar
    ) AS hk_customer_order,

    hc.hk_customer,
    ho.hk_order,

    current_timestamp,
    so.source_system

FROM stg_orders so

JOIN hub_customer hc
    ON hc.customer_id = so.customer_id::varchar

JOIN hub_order ho
    ON ho.order_id = so.order_id::varchar

ON CONFLICT (hk_customer_order) DO NOTHING;


CREATE TABLE IF NOT EXISTS link_order_product
(
    hk_order_product CHAR(32) PRIMARY KEY,

    hk_order    CHAR(32) NOT NULL,
    hk_product  CHAR(32) NOT NULL,

    load_dts TIMESTAMP NOT NULL,
    record_source VARCHAR(50) NOT NULL
);

-- LINK ORDER ↔ PRODUCT
-- фиксирует факт присутствия продукта в заказе

INSERT INTO link_order_product
SELECT DISTINCT
    md5(
        so.order_id::varchar || '|' || so.product_id::varchar
    ) AS hk_order_product,

    ho.hk_order,
    hp.hk_product,

    current_timestamp,
    so.source_system

FROM stg_orders so

JOIN hub_order ho
    ON ho.order_id = so.order_id::varchar

JOIN hub_product hp
    ON hp.product_id = so.product_id::varchar

ON CONFLICT (hk_order_product) DO NOTHING;


/*****************************************************************************************
4. SATELLITE LAYER (HISTORY + ATTRIBUTES)
*****************************************************************************************/

-- SATELLITE = исторические изменения атрибутов
-- INSERT ONLY
-- hash_diff = контроль изменений

CREATE TABLE IF NOT EXISTS sat_customer
(
    hk_customer CHAR(32) NOT NULL,

    hash_diff CHAR(32) NOT NULL,

    name VARCHAR(200),
    city VARCHAR(200),

    load_dts TIMESTAMP NOT NULL,
    end_date TIMESTAMP DEFAULT 'infinity' NOT NULL,

    PRIMARY KEY (hk_customer, load_dts)
);

-- SAT CUSTOMER
-- фиксирует изменения имени и города клиента

INSERT INTO sat_customer
(
    hk_customer,
    hash_diff,
    name,
    city,
    load_dts
)
WITH src AS
(
    SELECT DISTINCT
        hc.hk_customer,

        md5(
            so.customer_name || '|' || so.customer_city
        ) AS hash_diff,

        so.customer_name AS name,
        so.customer_city AS city

    FROM stg_orders so

    JOIN hub_customer hc
        ON hc.customer_id = so.customer_id::varchar
)
SELECT
    src.hk_customer,
    src.hash_diff,
    src.name,
    src.city,
    current_timestamp
FROM src
WHERE NOT EXISTS
(
    SELECT 1
    FROM sat_customer sc
    WHERE sc.hk_customer = src.hk_customer
      AND sc.hash_diff = src.hash_diff
      AND sc.end_date = 'infinity'
);


CREATE TABLE IF NOT EXISTS sat_order
(
    hk_order CHAR(32) NOT NULL,

    hash_diff CHAR(32) NOT NULL,

    amount NUMERIC(12,2),
    status VARCHAR(50),

    load_dts TIMESTAMP NOT NULL,
    end_date TIMESTAMP DEFAULT 'infinity' NOT NULL,

    PRIMARY KEY (hk_order, load_dts)
);

-- SAT ORDER
-- хранит историю статусов и суммы заказа

INSERT INTO sat_order
(
    hk_order,
    hash_diff,
    amount,
    status,
    load_dts
)
WITH src AS
(
    SELECT DISTINCT
        ho.hk_order,

        md5(
            so.order_amount::varchar || '|' || so.order_status
        ) AS hash_diff,

        so.order_amount,
        so.order_status

    FROM stg_orders so

    JOIN hub_order ho
        ON ho.order_id = so.order_id::varchar
)
SELECT
    src.hk_order,
    src.hash_diff,
    src.amount,
    src.status,
    current_timestamp
FROM src
WHERE NOT EXISTS
(
    SELECT 1
    FROM sat_order sc
    WHERE sc.hk_order = src.hk_order
      AND sc.hash_diff = src.hash_diff
      AND sc.end_date = 'infinity'
);


CREATE TABLE IF NOT EXISTS sat_product
(
    hk_product CHAR(32) NOT NULL,

    hash_diff CHAR(32) NOT NULL,

    name VARCHAR(200),
    category VARCHAR(100),

    load_dts TIMESTAMP NOT NULL,
    end_date TIMESTAMP DEFAULT 'infinity' NOT NULL,

    PRIMARY KEY (hk_product, load_dts)
);

-- SAT PRODUCT
-- история изменения продукта

INSERT INTO sat_product
(
    hk_product,
    hash_diff,
    name,
    category,
    load_dts
)
WITH src AS
(
    SELECT DISTINCT
        hp.hk_product,

        md5(
            so.product_name || '|' || so.product_category
        ) AS hash_diff,

        so.product_name,
        so.product_category

    FROM stg_orders so

    JOIN hub_product hp
        ON hp.product_id = so.product_id::varchar
)
SELECT
    src.hk_product,
    src.hash_diff,
    src.name,
    src.category,
    current_timestamp
FROM src
WHERE NOT EXISTS
(
    SELECT 1
    FROM sat_product sp
    WHERE sp.hk_product = src.hk_product
      AND sp.hash_diff = src.hash_diff
      AND sp.end_date = 'infinity'
);


CREATE TABLE IF NOT EXISTS sat_order_product
(
    hk_order_product_link CHAR(32) NOT NULL,

    hash_diff CHAR(32) NOT NULL,

    qty INTEGER,
    price NUMERIC(12,2),

    load_dts TIMESTAMP NOT NULL,

    PRIMARY KEY (hk_order_product_link, load_dts)
);

-- SAT ORDER PRODUCT
-- история изменения позиции заказа (Order Line)

INSERT INTO sat_order_product
(
    hk_order_product_link,
    hash_diff,
    qty,
    price,
    load_dts
)
WITH src AS
(
    SELECT DISTINCT
        lp.hk_order_product AS hk_order_product_link,

        md5(
            so.qty::varchar || '|' || so.price::varchar
        ) AS hash_diff,

        so.qty,
        so.price

    FROM stg_orders so

    JOIN hub_order ho
        ON ho.order_id = so.order_id::varchar

    JOIN hub_product hp
        ON hp.product_id = so.product_id::varchar

    JOIN link_order_product lp
        ON lp.hk_order = ho.hk_order
       AND lp.hk_product = hp.hk_product
)
SELECT
    src.hk_order_product_link,
    src.hash_diff,
    src.qty,
    src.price,
    current_timestamp
FROM src
WHERE NOT EXISTS
(
    SELECT 1
    FROM sat_order_product sp
    WHERE sp.hk_order_product_link = src.hk_order_product_link
      AND sp.hash_diff = src.hash_diff
);