/*

## Разбор строки целиком

```
unnest(
    string_to_array(u.courses, ';'),
    string_to_array(u.professors, ';'),
    string_to_array(u.grades, ';')
)
WITH ORDINALITY
AS t(course, professor, grade, pos)
```

Разберём по слоям.

---

### Шаг 1. `unnest(...)`

```
unnest(array1, array2, array3)
```

Работает **параллельно по позициям**:

| array1     | array2       | array3       |
| ---------- | ------------ | ------------ |
| Математика | Петров П.П.  | Математика:A |
| Физика     | Сидоров С.С. | Физика:B     |

Результат — **набор строк**, а не массив.

---

### Шаг 2. `WITH ORDINALITY`

PostgreSQL автоматически добавляет **служебную колонку**:

| col1       | col2         | col3         | ordinality |
| ---------- | ------------ | ------------ | ---------- |
| Математика | Петров П.П.  | Математика:A | 1          |
| Физика     | Сидоров С.С. | Физика:B     | 2          |

Важно:

* нумерация **строго по порядку элементов**
* начинается **с 1**
* не зависит от внешнего `ORDER BY`

---

### Шаг 3. `AS t(course, professor, grade, pos)`

Это **алиас результата `unnest`**.

Соответствие позиционное:

```
t.course     ← 1-й массив
t.professor  ← 2-й массив
t.grade      ← 3-й массив
t.pos        ← ordinality
```

Фактически ты даёшь имена колонкам временной таблицы `t`.

---

## 3. Зачем нужен `pos`

### Для стабильной сортировки

```
ORDER BY u.student_record_id, pos
```

Гарантирует:

* строки одного студента идут подряд
* порядок соответствует исходной строке:

  * 1-й курс → 1-й профессор → 1-я оценка
  * 2-й курс → 2-й профессор → 2-я оценка

Без `pos` PostgreSQL **не обязан сохранять порядок**.

---

## 4. Почему `ORDER BY` именно так

```
ORDER BY u.student_record_id, pos
```

Смысл:

* `student_record_id` — группировка логической сущности
* `pos` — порядок элементов внутри одной записи

Это **детерминированный результат**, пригодный для:

* загрузки в HUB / LINK
* повторяемых ETL
* hash-ключей и hashdiff

---

## Итог

`WITH ORDINALITY` — это встроенный способ PostgreSQL **пронумеровать результат `unnest`**, чтобы ты мог **сохранить и контролировать исходный порядок элементов**, не управляя индексами вручную.

*/

-- Создадим Источник данных
create table if not exists university_0nf (
student_record_id int,
student_full_name text,
student_email text,
courses text,
professors text,
semester text,
grades text
);

INSERT INTO public.university_0nf (student_record_id, student_full_name, student_email, courses, professors, semester, grades) VALUES
(1, 'Иванов Иван', 'ivanov@mail.com', 'Математика;Физика', 'Петров П.П.;Сидоров С.С.', '2024-осень', 'Математика:A;Физика:B'),
(2, 'Петров Алексей', 'petrov@mail.com', 'Математика', 'Петров П.П.', '2024-осень', 'Математика:C'),
(3, 'Смирнова Анна', 'smirnova@mail.com', 'Физика;Программирование', 'Сидоров С.С.;Кузнецов К.К.', '2024-осень', 'Физика:A;Программирование:A'),
(4, 'Иванов Иван', 'ivanov@mail.com', 'Программирование', 'Кузнецов К.К.', '2025-весна', 'Программирование:B'),
(5, 'Кузнецов Михаил', 'kuz@mail.com', 'Математика;Программирование', 'Петров П.П.;Кузнецов К.К.', '2025-весна', 'Математика:B;Программирование:C'),
(6, 'Смирнова Анна', 'smirnova@mail.com', 'Математика', 'Петров П.П.', '2025-весна', 'Математика:A'),
(7, 'Орлова Мария', 'orlova@mail.com', 'Физика', 'Сидоров С.С.', '2024-осень', 'Физика:B'),
(8, 'Петров Алексей', 'petrov@mail.com', 'Программирование', 'Кузнецов К.К.', '2025-весна', 'Программирование:A'),
(9, 'Орлова Мария', 'orlova@mail.com', 'Математика;Физика', 'Петров П.П.;Сидоров С.С.', '2025-весна', 'Математика:C;Физика:B'),
(10, 'Кузнецов Михаил', 'kuz@mail.com', 'Физика', 'Сидоров С.С.', '2024-осень', 'Физика:A');

select * from public.university_0nf limit 3;

/*
Цель:
Сделать так, чтобы:
в каждой ячейке было одно значение, а не список;
каждая строка описывала один факт, а не «всё сразу».

Если совсем просто:
«Одна строка — одно событие.
Одна колонка — одно значение.»
*/

-- Инструмент
SELECT
    u.student_record_id,
    u.student_full_name,
    u.student_email,
    t.course,
    t.professor,
    u.semester,
    t.grade
FROM public.university_0nf u
CROSS JOIN LATERAL unnest(
    string_to_array(u.courses, ';'),
    string_to_array(u.professors, ';'),
    string_to_array(u.grades, ';')
) WITH ORDINALITY AS t(course, professor, grade, pos)
ORDER BY u.student_record_id, t.pos;