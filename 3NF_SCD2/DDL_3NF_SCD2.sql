-- 3NF_SCD2 аналитический слой с историчностью.
/*
Порядок реализации 

cities_3nf_scd2
student_3nf_scd2
teachers_3nf_scd2
courses_3nf_scd2
orders_3nf_fact

Каждая SCD2-таблица обязана содержать:
<entity>_sk — surrogate primary key
<business_key> — бизнес-ключ
атрибуты сущности
valid_from
valid_to
is_current
*/

select * from public.student_2nf limit 3;	


--drop table public.cities_3nf_scd2 CASCADE;
create table public.cities_3nf_scd2 (
	city_sk SERIAL primary key,
	city_name varchar (50) NOT NULL,
	region_name varchar (50),
	valid_from DATE NOT NULL, 
	valid_to DATE NOT NULL DEFAULT '9999-12-31',
	is_current BOOLEAN NOT NULL DEFAULT true,
	UNIQUE (city_name, valid_from)
);
-- Комментарий к таблице
COMMENT ON TABLE public.cities_3nf_scd2 IS 'Таблица хранение истории изменения региона города. Любое изменение → новая версия.';
-- Комментарии к колонкам
COMMENT ON COLUMN cities_3nf_scd2.city_sk IS 'Surrogate key версии города';
COMMENT ON COLUMN cities_3nf_scd2.city_name IS 'Business key города';


-- Частичный уникальный индекс, гарантирует, что среди всех ТЕКУЩИХ записей (is_current = true) city_name будет уникальным. 
CREATE UNIQUE INDEX ux_cities_current
ON cities_3nf_scd2 (city_name)
WHERE is_current = true;

insert into public.cities_3nf_scd2 (city_name,region_name,valid_from)
select distinct
	student_city,student_region,
	CURRENT_DATE as valid_from
from public.student_2nf;	
	
	
--drop table public.student_3nf_scd2;	
CREATE TABLE public.student_3nf_scd2 (
	student_sk SERIAL PRIMARY KEY, 
	student_email varchar(100) not NULL,
	city_sk int not null,
	student_name varchar(100) not NULL,
	student_phone varchar(20) not NULL,
	valid_from DATE NOT NULL, 
	valid_to DATE NOT NULL DEFAULT '9999-12-31',
	is_current BOOLEAN NOT NULL DEFAULT TRUE,
	UNIQUE (student_email, valid_from),
	FOREIGN KEY (city_sk) REFERENCES public.cities_3nf_scd2(city_sk)
);
-- Комментарий к таблице
COMMENT ON TABLE public.student_3nf_scd2 IS 'Таблица хранение истории изменения данных студента. Любое изменение → новая версия студента.';
-- Комментарии к колонкам
COMMENT ON COLUMN student_3nf_scd2.student_sk IS 'Surrogate key версии студента';
COMMENT ON COLUMN student_3nf_scd2.student_email IS 'Business key студента';


-- Частичный уникальный индекс, гарантирует, что среди всех ТЕКУЩИХ записей (is_current = true) email будет уникальным. 
CREATE UNIQUE INDEX ux_student_current
ON student_3nf_scd2 (student_email)
WHERE is_current = true;


insert into public.student_3nf_scd2 (student_email,city_sk,student_name,student_phone,valid_from)
select distinct
	student_email,c.city_sk,student_name,student_phone,
	CURRENT_DATE as valid_from
from public.student_2nf s
join public.cities_3nf_scd2 c on s.student_city = c.city_name
		and c.is_current = true;	

---

--drop table public.teachers_3nf_scd2 CASCADE;	
CREATE TABLE public.teachers_3nf_scd2 (
	teacher_sk SERIAL PRIMARY KEY,
	teacher_email varchar(50) NOT null,
	teacher_name varchar(50) NOT null,
	valid_from DATE NOT NULL, 
	valid_to DATE NOT NULL DEFAULT '9999-12-31',
	is_current BOOLEAN NOT NULL DEFAULT TRUE,
	UNIQUE (teacher_email, valid_from)
);
-- Комментарий к таблице
COMMENT ON TABLE public.teachers_3nf_scd2 IS 'История данных преподавателя. Любое изменение → новая версия.';
-- Комментарии к колонкам
COMMENT ON COLUMN teachers_3nf_scd2.teacher_sk IS 'Surrogate key версии учителя';
COMMENT ON COLUMN teachers_3nf_scd2.teacher_email IS 'Business key учителя';


-- Частичный уникальный индекс, гарантирует, что среди всех ТЕКУЩИХ записей (is_current = true) teacher_email будет уникальным. 
CREATE UNIQUE INDEX ux_teacher_current
ON teachers_3nf_scd2 (teacher_email)
WHERE is_current = true;

insert into public.teachers_3nf_scd2 (teacher_email,teacher_name,valid_from)
select distinct 
	teacher_email,
	teacher_name,
	CURRENT_DATE as valid_from
from public.course_2nf;


--drop table public.courses_3nf_scd2;	
CREATE TABLE public.courses_3nf_scd2(
	course_sk SERIAL PRIMARY KEY,
	course_name varchar(50) NOT null,
	course_category varchar(50) NOT null,
	course_price numeric(10, 2) NOT null,
	teacher_sk int NOT null,
	valid_from DATE NOT NULL, 
	valid_to DATE NOT NULL DEFAULT '9999-12-31',
	is_current BOOLEAN NOT NULL DEFAULT TRUE,
	UNIQUE (course_name, valid_from),
	FOREIGN KEY (teacher_sk) REFERENCES public.teachers_3nf_scd2(teacher_sk)
);

-- Комментарий к таблице
COMMENT ON TABLE public.courses_3nf_scd2 IS 'История продукта «курс». Смена любого атрибута → новая версия курса';
-- Комментарии к колонкам
COMMENT ON COLUMN courses_3nf_scd2.course_sk IS 'Surrogate key версии курса';
COMMENT ON COLUMN courses_3nf_scd2.course_name IS 'Business key курса';


-- Частичный уникальный индекс, гарантирует, что среди всех ТЕКУЩИХ записей (is_current = true) course_name будет уникальным. 
CREATE UNIQUE INDEX ux_course_current
ON courses_3nf_scd2 (course_name)
WHERE is_current = true;

insert into public.courses_3nf_scd2 (course_name,course_category,course_price,teacher_sk,valid_from)
select
	c.course_name,c.course_category,c.course_price,t.teacher_sk,
	CURRENT_DATE as valid_from
from public.course_2nf c
join public.teachers_3nf_scd2 t on c.teacher_email = t.teacher_email
		and t.is_current = true;

-- Справочники
--drop table public.payment_methods_3nf_ref;
CREATE TABLE IF NOT EXISTS public.payment_methods_3nf_ref(
payment_method VARCHAR(50) primary key
);

insert into public.payment_methods_3nf_ref
select distinct
payment_method
from public.orders_2nf;

--drop table public.payment_statuses_3nf_ref;
CREATE TABLE IF NOT EXISTS public.payment_statuses_3nf_ref(
payment_status VARCHAR(50) primary key
);

insert into public.payment_statuses_3nf_ref
select distinct
payment_status
from public.orders_2nf;

---
-- Таблица фактов

select * from public.orders_2nf;

--drop table public.orders_3nf_fact;
CREATE TABLE IF NOT EXISTS public.orders_3nf_fact(
	order_sk  SERIAL PRIMARY key,
	order_date DATE NOT NULL,
   	student_sk int, --FK
	course_sk int, --FK
    payment_method VARCHAR(50), --FK
    payment_status VARCHAR(50), --FK
	FOREIGN KEY (student_sk) REFERENCES public.student_3nf_scd2 (student_sk),
	FOREIGN KEY (course_sk) REFERENCES public.courses_3nf_scd2 (course_sk),
	FOREIGN KEY (payment_method) REFERENCES public.payment_methods_3nf_ref (payment_method),
	FOREIGN KEY (payment_status) REFERENCES public.payment_statuses_3nf_ref (payment_status)
);

insert into public.orders_3nf_fact (order_date,student_sk,course_sk,payment_method,payment_status)
select 
	o.order_date,
	s.student_sk,
	c.course_sk,
    pm.payment_method,
    ps.payment_status
from public.orders_2nf o
join public.student_3nf_scd2 s on o.student_email = s.student_email and s.is_current = true
join public.courses_3nf_scd2 c on o.course_name = c.course_name and c.is_current = true
join public.payment_methods_3nf_ref pm on o.payment_method = pm.payment_method
join payment_statuses_3nf_ref ps on o.payment_status = ps.payment_status;

select * from public.orders_3nf_fact;