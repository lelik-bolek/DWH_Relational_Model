--1NF
/*
Каждое поле содержит только атомарные (неделимые) значения

Что нужно сделать:
- Убрать повторяющиеся группы
- Убрать массивы и списки в ячейках
- Каждому атрибуту присвоить уникальное имя
- Определить первичный ключ
 */

select * from public.courses_0nf limit 3;

--drop table public.courses_1nf;
CREATE TABLE IF NOT EXISTS public.courses_1nf (
    order_date DATE NOT NULL,
    student_email VARCHAR(100),
    student_name VARCHAR(100),
    student_phone VARCHAR(20),
    student_city VARCHAR(50),
    student_region VARCHAR(50),
    course_name VARCHAR(100),
    course_category VARCHAR(50),
    course_price DECIMAL(10, 2),
    teacher_name VARCHAR(100),
    teacher_email VARCHAR(100),
    payment_method VARCHAR(50),
    payment_status VARCHAR(50),
    primary KEY(student_email, course_name, order_date)
);

-- Комментарий к таблице
COMMENT ON TABLE public.courses_1nf IS 'Таблица заказов онлайн-курсов в 1НФ. Хранит информацию о покупках онлайн-курсов. Составной PK: студент + курс + дата.';

-- Комментарии к колонкам
COMMENT ON COLUMN public.courses_1nf.order_date IS 'Дата оформления заказа. Формат: YYYY-MM-DD.';
COMMENT ON COLUMN public.courses_1nf.student_email IS 'Email студента. Основной контакт и идентификатор.';
COMMENT ON COLUMN public.courses_1nf.student_name IS 'Полное имя студента. Формат: "Имя Фамилия".';
COMMENT ON COLUMN public.courses_1nf.student_phone IS 'Контактный телефон студента в международном формате.';
COMMENT ON COLUMN public.courses_1nf.student_city IS 'Город проживания студента.';
COMMENT ON COLUMN public.courses_1nf.student_region IS 'Регион/федеральный округ.';
COMMENT ON COLUMN public.courses_1nf.course_name IS 'Название образовательного курса.';
COMMENT ON COLUMN public.courses_1nf.course_category IS 'Профессиональная категория курса (Data, BI, т.д.).';
COMMENT ON COLUMN public.courses_1nf.course_price IS 'Стоимость курса в рублях. Формат: XXXXX.00';
COMMENT ON COLUMN public.courses_1nf.teacher_name IS 'ФИО преподавателя ведущего курс.';
COMMENT ON COLUMN public.courses_1nf.teacher_email IS 'Контактный email преподавателя.';
COMMENT ON COLUMN public.courses_1nf.payment_method IS 'Способ проведения платежа: Карта или СБП.';
COMMENT ON COLUMN public.courses_1nf.payment_status IS 'Текущий статус платежной транзакции.';


insert into public.courses_1nf
SELECT 
    order_date,
    -- Разбор student_info
    split_part(student_info, ';', 1) as student_email,
    split_part(student_info, ';', 2) as student_name,
    split_part(student_info, ';', 3) as student_phone,
    split_part(split_part(student_info, ';', 4), '|', 1) as student_city,
    split_part(split_part(student_info, ';', 4), '|', 2) as student_region,
    -- Разбор course_info
    split_part(course_info, '|', 1) as course_name,
    split_part(course_info, '|', 2) as course_category,
    split_part(course_info, '|', 3)::DECIMAL as course_price,
    -- Разбор teacher_info
    split_part(teacher_info, '<', 1) as teacher_name,
    trim(trailing '>' from split_part(teacher_info, '<', 2)) as teacher_email,
    -- Разбор payment_info
    split_part(payment_info, '|', 1) as payment_method,
    split_part(payment_info, '|', 2) as payment_status
FROM courses_0nf
ORDER BY order_date;

select * from public.courses_1nf limit 3;
/*
2024-01-10	ivan.petrov@mail.com	Иван Петров	+79990001122	Москва	Центральный	SQL для начинающих	Data	15000.00	Сергей Иванов	s.ivanov@mail.com	Карта	Оплачено
2024-01-11	anna.smirnova@mail.com	Анна Смирнова	+79990002233	Санкт-Петербург	Северо-Западный	Python ETL	Data	20000.00	Олег Кузнецов	o.kuz@mail.com	Карта	Оплачено
2024-01-11	ivan.petrov@mail.com	Иван Петров	+79990001122	Москва	Центральный	Python ETL	Data	20000.00	Олег Кузнецов	o.kuz@mail.com	Карта	Оплачено
*/