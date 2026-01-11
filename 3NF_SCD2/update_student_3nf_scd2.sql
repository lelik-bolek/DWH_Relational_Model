-- обновление всех версий студентов, закрытие старых и вставка новых.
-- 1. Выбираем новые и изменившиеся записи из staging (student_2nf)
WITH src AS (
    SELECT
        s.student_email,
        s.student_name,
        s.student_phone,
        c.city_sk
    FROM student_2nf s
    JOIN cities_3nf_scd2 c
      ON s.student_city = c.city_name
),
-- 2. Определяем изменения по текущим версиям
changed AS (
    SELECT
        d.student_sk,
        s.student_email,
        s.student_name,
        s.student_phone,
        s.city_sk
    FROM src s
    JOIN student_3nf_scd2 d
      ON s.student_email = d.student_email
     AND d.is_current = true
    WHERE 
        (s.student_name, s.student_phone, s.city_sk) 
        IS DISTINCT FROM
        (d.student_name, d.student_phone, d.city_sk)
)
-- 3. Закрываем старые версии
UPDATE student_3nf_scd2 d
SET valid_to = CURRENT_DATE - 1,
    is_current = false
FROM changed c
WHERE d.student_sk = c.student_sk;

-- 4. Вставляем новые версии
INSERT INTO student_3nf_scd2
(student_email, student_name, student_phone, city_sk, valid_from)
SELECT
    student_email,
    student_name,
    student_phone,
    city_sk,
    CURRENT_DATE
FROM changed;

-- 5. Вставка новых студентов (которые ещё не существовали)
INSERT INTO student_3nf_scd2
(student_email, student_name, student_phone, city_sk, valid_from)
SELECT
    s.student_email,
    s.student_name,
    s.student_phone,
    s.city_sk,
    CURRENT_DATE
FROM src s
LEFT JOIN student_3nf_scd2 d
  ON s.student_email = d.student_email
WHERE d.student_email IS NULL;