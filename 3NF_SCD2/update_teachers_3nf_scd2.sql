-- обновление всех версий преподавателей, закрытие старых и вставка новых.
-- 1. Выбираем новые и изменившиеся записи из staging (course_2nf)
WITH src AS (
    SELECT DISTINCT
        teacher_email,
        teacher_name
    FROM course_2nf
),
-- 2. Определяем изменения по текущим версиям
changed AS (
    SELECT
        d.teacher_sk,
        s.teacher_email,
        s.teacher_name
    FROM src s
    JOIN teachers_3nf_scd2 d
      ON s.teacher_email = d.teacher_email
     AND d.is_current = true
    WHERE (s.teacher_name) IS DISTINCT FROM (d.teacher_name)
)
-- 3. Закрываем старые версии
UPDATE teachers_3nf_scd2 d
SET valid_to = CURRENT_DATE - 1,
    is_current = false
FROM changed c
WHERE d.teacher_sk = c.teacher_sk;

-- 4. Вставляем новые версии изменившихся преподавателей
INSERT INTO teachers_3nf_scd2
(teacher_email, teacher_name, valid_from)
SELECT
    teacher_email,
    teacher_name,
    CURRENT_DATE
FROM changed;

-- 5. Вставляем новых преподавателей (которых ещё нет)
INSERT INTO teachers_3nf_scd2
(teacher_email, teacher_name, valid_from)
SELECT
    s.teacher_email,
    s.teacher_name,
    CURRENT_DATE
FROM src s
LEFT JOIN teachers_3nf_scd2 d
  ON s.teacher_email = d.teacher_email
WHERE d.teacher_email IS NULL;