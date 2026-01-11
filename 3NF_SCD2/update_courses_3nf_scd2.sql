-- обновление всех версий курсов, с учётом текущих преподавателей, закрытие старых и вставка новых.
-- 1. Выбираем новые и изменившиеся записи из staging (course_2nf)
WITH src AS (
    SELECT
        c.course_name,
        c.course_category,
        c.course_price,
        t.teacher_sk
    FROM course_2nf c
    JOIN teachers_3nf_scd2 t
      ON c.teacher_email = t.teacher_email
     AND t.is_current = true
),
-- 2. Определяем изменения по текущим версиям
changed AS (
    SELECT
        d.course_sk,
        s.course_name,
        s.course_category,
        s.course_price,
        s.teacher_sk
    FROM src s
    JOIN courses_3nf_scd2 d
      ON s.course_name = d.course_name
     AND d.is_current = true
    WHERE (s.course_category, s.course_price, s.teacher_sk)
          IS DISTINCT FROM
          (d.course_category, d.course_price, d.teacher_sk)
)
-- 3. Закрываем старые версии
UPDATE courses_3nf_scd2 d
SET valid_to = CURRENT_DATE - 1,
    is_current = false
FROM changed c
WHERE d.course_sk = c.course_sk;

-- 4. Вставляем новые версии изменившихся курсов
INSERT INTO courses_3nf_scd2
(course_name, course_category, course_price, teacher_sk, valid_from)
SELECT
    course_name,
    course_category,
    course_price,
    teacher_sk,
    CURRENT_DATE
FROM changed;

-- 5. Вставляем новые курсы (которые ещё не существовали)
INSERT INTO courses_3nf_scd2
(course_name, course_category, course_price, teacher_sk, valid_from)
SELECT
    s.course_name,
    s.course_category,
    s.course_price,
    s.teacher_sk,
    CURRENT_DATE
FROM src s
LEFT JOIN courses_3nf_scd2 d
  ON s.course_name = d.course_name
WHERE d.course_name IS NULL;