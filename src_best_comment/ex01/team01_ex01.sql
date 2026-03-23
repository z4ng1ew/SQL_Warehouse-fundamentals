WITH rated_balance AS (
    SELECT
        b.user_id,
        b.money,
        c.name AS currency_name,
        COALESCE(
            (SELECT rate_to_usd FROM currency
             WHERE id = b.currency_id AND updated < b.updated
             ORDER BY updated DESC LIMIT 1),
            (SELECT rate_to_usd FROM currency
             WHERE id = b.currency_id AND updated > b.updated
             ORDER BY updated ASC LIMIT 1)
        ) AS rate
    FROM balance b
    INNER JOIN (SELECT DISTINCT id, name FROM currency) c ON c.id = b.currency_id
)
SELECT
    COALESCE(u.name, 'not defined')     AS name,
    COALESCE(u.lastname, 'not defined') AS lastname,
    rb.currency_name,
    trim_scale(rb.money * rb.rate)      AS currency_in_usd
FROM rated_balance rb
LEFT JOIN "user" u ON u.id = rb.user_id
ORDER BY 1 DESC, 2, 3;











-- В задании 00 мы брали последний курс валюты для всех транзакций. Тут сложнее — нужно для каждой транзакции найти свой курс, ближайший по времени.





-- CTE rated_balance: подготавливаем данные — для каждой транзакции
-- из balance находим ближайший курс валюты
WITH rated_balance AS (
    SELECT
        -- ID пользователя для последующего JOIN с таблицей user
        b.user_id,

        -- Сумма денег в транзакции
        b.money,

        -- Название валюты из уникального списка валют
        c.name AS currency_name,

        -- Ищем ближайший курс через COALESCE:
        -- первый аргумент — курс в прошлом, второй — в будущем.
        -- Если в прошлом нашёлся (не NULL) — берём его.
        -- Если NULL — COALESCE переходит ко второму аргументу (будущее).
        COALESCE(
            -- t1: ищем ближайший курс В ПРОШЛОМ.
            -- updated < b.updated — только курсы ДО транзакции.
            -- ORDER BY updated DESC — сортируем от новых к старым.
            -- LIMIT 1 — берём самый ближний к моменту транзакции.
            (SELECT rate_to_usd FROM currency
             WHERE id = b.currency_id AND updated < b.updated
             ORDER BY updated DESC LIMIT 1),

            -- t2: если в прошлом ничего нет — ищем ближайший В БУДУЩЕМ.
            -- updated > b.updated — только курсы ПОСЛЕ транзакции.
            -- ORDER BY updated ASC — сортируем от старых к новым.
            -- LIMIT 1 — берём самый ближний к моменту транзакции.
            (SELECT rate_to_usd FROM currency
             WHERE id = b.currency_id AND updated > b.updated
             ORDER BY updated ASC LIMIT 1)
        ) AS rate

    -- Основа — таблица balance (все транзакции)
    FROM balance b

    -- INNER JOIN с уникальным списком валют.
    -- INNER, а не LEFT — по заданию: «игнорируйте валюты,
    -- для которых нет ключа в таблице Currency».
    -- Поэтому currency_id=210 (Петр) отбрасывается.
    -- SELECT DISTINCT id, name — убираем дубликаты курсов,
    -- оставляя уникальные пары (id, name) валют.
    INNER JOIN (SELECT DISTINCT id, name FROM currency) c ON c.id = b.currency_id
)

-- Основной SELECT: подтягиваем имена пользователей и выводим результат
SELECT
    -- Имя пользователя. NULL → 'not defined'
    COALESCE(u.name, 'not defined')     AS name,

    -- Фамилия пользователя. NULL → 'not defined'
    COALESCE(u.lastname, 'not defined') AS lastname,

    -- Название валюты из CTE
    rb.currency_name,

    -- Итоговая сумма в USD = money * rate.
    -- trim_scale убирает незначащие нули (17.00 → 17, 150.10 → 150.1)
    trim_scale(rb.money * rb.rate)      AS currency_in_usd

-- Берём данные из CTE
FROM rated_balance rb

-- LEFT JOIN с user: сохраняем транзакции без пользователя (user_id=4).
-- У них name и lastname будут NULL → COALESCE подставит 'not defined'.
LEFT JOIN "user" u ON u.id = rb.user_id

-- Сортировка:
-- 1 DESC = name по убыванию (Иван > not defined)
-- 2 = lastname по возрастанию
-- 3 = currency_name по возрастанию
ORDER BY 1 DESC, 2, 3;
```

## Краткая шпаргалка для защиты

**«Почему CTE, а не вложенный подзапрос?»** — читаемость. CTE готовит данные (находит курс для каждой транзакции), основной SELECT только соединяет с user и выводит. Каждый блок можно объяснить отдельно.

**«Как работает поиск ближайшего курса?»** — два коррелированных подзапроса внутри COALESCE. Первый ищет в прошлом (updated < balance.updated, DESC, LIMIT 1). Если вернул NULL — COALESCE берёт второй (будущее, ASC, LIMIT 1). Это точно соответствует схеме t1/t2 из задания.

**«Почему INNER JOIN с currency?»** — задание прямо говорит «игнорируйте валюты, которых нет в Currency». У Петра currency_id=210, его нет в currency — INNER JOIN его отсеивает.

**«Почему LEFT JOIN с user?»** — user_id=4 есть в balance, но нет в таблице user. LEFT JOIN сохраняет эту строку, COALESCE подставляет 'not defined'.

**«Почему DISTINCT в подзапросе currency?»** — в currency одна валюта (EUR id=100) имеет много строк (разные курсы). DISTINCT оставляет одну пару (100, EUR) для JOIN, чтобы balance не дублировался.

























## Порядок выполнения запроса

### Шаг 1 — CTE `rated_balance`

PostgreSQL первым делом выполняет WITH-блок.

#### Шаг 1.1 — Подзапрос для INNER JOIN

```sql
SELECT DISTINCT id, name FROM currency
```

Берёт таблицу currency (10 строк) и оставляет уникальные пары (id, name):

```
id=100, EUR
id=200, USD
id=300, JPY
```

#### Шаг 1.2 — INNER JOIN с balance

```sql
FROM balance b
INNER JOIN (...) c ON c.id = b.currency_id
```

Соединяет balance (10 строк) с уникальными валютами. Строки с currency_id=210 (Петр) **отбрасываются**, потому что такого id нет в currency. Остаётся **8 строк**.

#### Шаг 1.3 — Для каждой из 8 строк ищется курс

```sql
COALESCE(
    (SELECT ... WHERE updated < b.updated ORDER BY updated DESC LIMIT 1),
    (SELECT ... WHERE updated > b.updated ORDER BY updated ASC LIMIT 1)
)
```

Для **каждой строки** выполняются два коррелированных подзапроса.

Пример для Ивана (money=200, currency_id=100, updated=2022-01-09 13:31):

**Первый подзапрос** — курсы EUR **в прошлом** (updated < 2022-01-09 13:31):

```
EUR 0.85 — 2022-01-01 13:29
EUR 0.79 — 2022-01-08 13:29  ← DESC, LIMIT 1 = ближайший
```

Нашёл 0.79. COALESCE получил не-NULL → **второй подзапрос не нужен**.

Пример для user_id=4 (money=120, currency_id=200, updated=2022-01-01 01:31):

**Первый подзапрос** — курсы USD **в прошлом** (updated < 2022-01-01 01:31):

```
ничего нет → NULL
```

**Второй подзапрос** — курсы USD **в будущем** (updated > 2022-01-01 01:31):

```
USD 1 — 2022-03-02 12:31  ← ASC, LIMIT 1 = ближайший
USD 1 — 2022-03-03 13:31
```

Нашёл 1.

#### Результат CTE rated_balance — 8 строк:

```
user_id=1, money=20,  currency_name=EUR, rate=0.85
user_id=1, money=200, currency_name=EUR, rate=0.79
user_id=1, money=190, currency_name=EUR, rate=0.79
user_id=4, money=120, currency_name=JPY, rate=0.0079
user_id=4, money=120, currency_name=USD, rate=1
user_id=3, money=50,  currency_name=EUR, rate=0.79
user_id=3, money=500, currency_name=USD, rate=1
user_id=3, money=500, currency_name=JPY, rate=0.0079
```

### Шаг 2 — LEFT JOIN с user

```sql
FROM rated_balance rb
LEFT JOIN "user" u ON u.id = rb.user_id
```

К каждой из 8 строк подтягиваются имя и фамилия пользователя. user_id=4 не найден в user → `u.name` и `u.lastname` будут NULL.

### Шаг 3 — SELECT (вычисление столбцов)

```sql
COALESCE(u.name, 'not defined')     → подстановка имён
COALESCE(u.lastname, 'not defined') → подстановка фамилий
rb.currency_name                    → название валюты
trim_scale(rb.money * rb.rate)      → конвертация в USD + убрать нули
```

Пример вычислений:

```
Иван:  200 * 0.79 = 158    → trim_scale → 158
Иван:  20  * 0.85 = 17     → trim_scale → 17
Иван:  190 * 0.79 = 150.1  → trim_scale → 150.1
```

### Шаг 4 — ORDER BY (сортировка)

```sql
ORDER BY 1 DESC, 2, 3
```

Сортирует готовые 8 строк: name по убыванию, lastname по возрастанию, currency_name по возрастанию.

### Итоговый результат

```
Иван,        Иванов,      EUR, 150.1
Иван,        Иванов,      EUR, 17
Иван,        Иванов,      EUR, 158
not defined, not defined,  JPY, 0.948
not defined, not defined,  USD, 120
not defined, Сидоров,      EUR, 39.5
not defined, Сидоров,      JPY, 3.95
not defined, Сидоров,      USD, 500
```

8 строк, полностью совпадает с чеклистом.