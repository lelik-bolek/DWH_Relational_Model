-- 2NF
/*
Таблица студентов
— PK: student_email
— атрибуты: почта, имя, телефон, город, регион

Таблица курсов
— PK: course_name
— атрибуты: категория, цена, преподаватель, почта

Таблица заказов / фактов
— PK: (student_email, course_name, order_date)
— атрибуты: payment_method, payment_status
— внешние ключи на студентов и курсы
 */


--drop table public.student_2nf;
CREATE TABLE IF NOT EXISTS public.student_2nf(
	student_email VARCHAR(100) primary key,
    student_name VARCHAR(100),
    student_phone VARCHAR(20),
    student_city VARCHAR(50),
    student_region VARCHAR(50)
);

insert into public.student_2nf
select distinct 
	student_email,
    student_name,
    student_phone,
    student_city,
    student_region
from public.courses_1nf;

	

--drop table public.course_2nf CASCADE;    
CREATE TABLE IF NOT EXISTS public.course_2nf(
    course_name VARCHAR(100) primary key,
    course_category VARCHAR(50),
    course_price DECIMAL(10, 2),
    teacher_name VARCHAR(100),
    teacher_email VARCHAR(100)
);

insert into public.course_2nf
select distinct 
	course_name,
    course_category,
    course_price,
    teacher_name,
    teacher_email
from public.courses_1nf;

--drop table public.orders_2nf CASCADE;
CREATE TABLE IF NOT EXISTS public.orders_2nf(
	order_date DATE NOT NULL,
   	student_email VARCHAR(100), --FK
	course_name VARCHAR(100), --FK
    payment_method VARCHAR(50),
    payment_status VARCHAR(50),
    primary KEY(student_email, course_name, order_date),
	FOREIGN KEY (student_email) REFERENCES public.student_2nf (student_email),
	FOREIGN KEY (course_name) REFERENCES public.course_2nf (course_name)
);

insert into public.orders_2nf
select 
	order_date,
   	student_email, --FK
	course_name, --FK
    payment_method,
    payment_status
from public.courses_1nf;

select * from public.orders_2nf limit 3;
/*
2024-01-10	ivan.petrov@mail.com	SQL для начинающих	Карта	Оплачено
2024-01-11	anna.smirnova@mail.com	Python ETL	Карта	Оплачено
2024-01-11	ivan.petrov@mail.com	Python ETL	Карта	Оплачено
*/