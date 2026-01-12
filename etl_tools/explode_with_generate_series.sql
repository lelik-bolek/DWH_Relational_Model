/*

## 1. Что делает 

Исходная идея:
у тебя **параллельные списки**, где элементы связаны **по позиции**.

```
courses     = ['Математика', 'Физика']
professors  = ['Петров П.П.', 'Сидоров С.С.']
grades      = ['Математика:A', 'Физика:B']
```

### Шаг 1. `exploded_data`

```
string_to_array(courses, ';')    → TEXT[]
string_to_array(professors, ';') → TEXT[]
string_to_array(grades, ';')     → TEXT[]
```

На выходе **одна строка = три массива**.

---

### Шаг 2. `CROSS JOIN LATERAL generate_series(...)`

Ключевая часть:

```
CROSS JOIN LATERAL generate_series(1, array_length(cours_array, 1)) AS i
```

Смысл:

* `generate_series(1, N)` создаёт числа `1, 2, ..., N`
* `LATERAL` позволяет этой функции **использовать массив из текущей строки**
* В итоге **одна строка превращается в N строк**

Если `cours_array` длиной 2 → будет 2 строки.

---

### Шаг 3. Доступ к элементам массива по индексу

```
cours_array[i]
professor_array[i]
grad_array[i]
```

Это **обычный доступ по индексу** в PostgreSQL (нумерация с 1).

| i | cours_array[i] | professor_array[i] | grad_array[i] |
| - | -------------- | ------------------ | ------------- |
| 1 | Математика     | Петров П.П.        | Математика:A  |
| 2 | Физика         | Сидоров С.С.       | Физика:B      |

Именно поэтому данные «склеиваются» правильно.

---

### Итог

Ты **вручную синхронизируешь массивы через индекс**.
Работает. Ошибок синтаксиса и логики тут нет.

---

## 2. Почему этот способ **не оптимален**

Проблемы не в скорости (она нормальная), а в **устойчивости и семантике**.

### Проблема 1. Нет гарантии одинаковой длины массивов

Если данные будут такими:

```
courses     = 2 элемента
professors  = 1 элемент
grades      = 2 элемента
```

→ `professor_array[2] = NULL`
→ тихая логическая ошибка
→ ты это даже не заметишь

---

### Проблема 2. Лишняя сложность

* `generate_series`
* ручное управление индексом
* зависимость от одного массива (`cours_array`)

Это **низкоуровневый подход**, ближе к procedural SQL.
---
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

-- Инструмент

WITH exploded_data AS (
    SELECT 
        student_record_id,
        student_full_name,
        student_email,
        semester,
        -- Создаем массивы
        string_to_array(courses, ';') as cours_array,
        string_to_array(professors, ';') as professor_array,
        string_to_array(grades, ';') as grad_array
    FROM public.university_0nf
),
unique_data as (
		SELECT
		    student_record_id,
        	student_full_name,
        	student_email,
        	semester,
		    -- Берем элемент по индексу
		    cours_array[i] as cours,
		    professor_array[i] as professor,
		    grad_array[i] as grade,
		    i as item_number
		FROM exploded_data
		CROSS JOIN LATERAL generate_series(1, array_length(cours_array, 1)) as i
		ORDER BY student_record_id, i
)
select
	student_record_id,
    student_full_name,
    student_email,
    cours,
    professor,
    semester,
    grade
from unique_data
order by student_record_id;