--3NF

/*
students
PK: student_email
student_name
student_phone
city_name (FK)

cities
PK: city_name
region_name

courses
PK: course_name
course_category
course_price
teacher_email (FK)

teachers
PK: teacher_email
teacher_name

payment_methods
PK: payment_method

payment_statuses
PK: payment_status

Факт

orders_fact
PK: (student_email, course_name, order_date)
FK:
student_email → students
course_name → courses
payment_method → payment_methods
payment_status → payment_statuses

 */
--drop table public.cities_3nf;
CREATE TABLE IF NOT EXISTS public.cities_3nf(
	student_city VARCHAR(50)  primary key,
    student_region VARCHAR(50)
);

insert into public.cities_3nf
select distinct 
    student_city,
    student_region
from public.student_2nf;

select * from public.cities_3nf;

--drop table public.student_3nf;
CREATE TABLE IF NOT EXISTS public.student_3nf(
	student_email VARCHAR(100) primary key,
    student_name VARCHAR(100),
    student_phone VARCHAR(20),
    student_city VARCHAR(50),
    FOREIGN KEY (student_city) REFERENCES public.cities_3nf (student_city)
);

insert into public.student_3nf
select 
	student_email,
    student_name,
    student_phone,
    c.student_city
from public.student_2nf s 
join public.cities_3nf c on s.student_city = c.student_city;

select * from public.student_3nf;
	

--drop table public.teachers_3nf CASCADE;    
CREATE TABLE IF NOT EXISTS public.teachers_3nf(
	teacher_email VARCHAR(100) primary key,
	teacher_name VARCHAR(100)
);

insert into public.teachers_3nf
select distinct 
	teacher_email,
    teacher_name
from public.course_2nf;


--drop table public.course_3nf CASCADE;    
CREATE TABLE IF NOT EXISTS public.course_3nf(
    course_name VARCHAR(100) primary key,
    course_category VARCHAR(50),
    course_price DECIMAL(10, 2),
    teacher_email VARCHAR(100),
    FOREIGN KEY (teacher_email) REFERENCES public.teachers_3nf (teacher_email)
);

insert into public.course_3nf
select 
	course_name,
    course_category,
    course_price,
    t.teacher_email
from public.course_2nf c
join public.teachers_3nf t on c.teacher_email = t.teacher_email;

select * from public.course_3nf;


CREATE TABLE IF NOT EXISTS public.payment_methods_3nf(
payment_method VARCHAR(50) primary key
);

insert into public.payment_methods_3nf
select distinct
payment_method
from public.orders_2nf;

CREATE TABLE IF NOT EXISTS public.payment_statuses_3nf(
payment_status VARCHAR(50) primary key
);

insert into public.payment_statuses_3nf
select distinct
payment_status
from public.orders_2nf;


--drop table public.orders_3nf CASCADE;
CREATE TABLE IF NOT EXISTS public.orders_3nf(
	order_date DATE NOT NULL,
   	student_email VARCHAR(100), --FK
	course_name VARCHAR(100), --FK
    payment_method VARCHAR(50), --FK
    payment_status VARCHAR(50), --FK
    primary KEY(student_email, course_name, order_date),
	FOREIGN KEY (student_email) REFERENCES public.student_3nf (student_email),
	FOREIGN KEY (course_name) REFERENCES public.course_3nf (course_name),
	FOREIGN KEY (payment_method) REFERENCES public.payment_methods_3nf (payment_method),
	FOREIGN KEY (payment_status) REFERENCES public.payment_statuses_3nf (payment_status)
);

insert into public.orders_3nf
select 
	o.order_date,
	s.student_email,
	c.course_name,
    pm.payment_method,
    ps.payment_status
from public.orders_2nf o
join public.student_3nf s on o.student_email = s.student_email
join public.course_3nf c on o.course_name = c.course_name
join public.payment_methods_3nf pm on o.payment_method = pm.payment_method
join payment_statuses_3nf ps on o.payment_status = ps.payment_status
;