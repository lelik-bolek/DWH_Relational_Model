-- обновление регионов городов, закрытие старых и вставка новых версий.
-- 1. Выбираем новые и изменившиеся записи из staging (student_2nf)
WITH src AS (
    SELECT DISTINCT
        student_city AS city_name,
        student_region AS region_name
    FROM student_2nf
),
-- 2. Определяем изменившиеся записи по текущим версиям
changed AS (
    SELECT
        d.city_sk,
        s.city_name,
        s.region_name
    FROM src s
    JOIN cities_3nf_scd2 d
      ON s.city_name = d.city_name
     AND d.is_current = true
    WHERE (s.region_name) IS DISTINCT FROM (d.region_name)
)
-- 3. Закрываем старые версии
UPDATE cities_3nf_scd2 d
SET valid_to = CURRENT_DATE - 1,
    is_current = false
FROM changed c
WHERE d.city_sk = c.city_sk;

-- 4. Вставляем новые версии изменившихся городов
INSERT INTO cities_3nf_scd2
(city_name, region_name, valid_from)
SELECT
    city_name,
    region_name,
    CURRENT_DATE
FROM changed;

-- 5. Вставляем новые города, которых ещё нет
INSERT INTO cities_3nf_scd2
(city_name, region_name, valid_from)
SELECT
    s.city_name,
    s.region_name,
    CURRENT_DATE
FROM src s
LEFT JOIN cities_3nf_scd2 d
  ON s.city_name = d.city_name
WHERE d.city_name IS NULL;