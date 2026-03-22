WITH last_rates AS (
    SELECT DISTINCT ON (id) id, name, rate_to_usd
    FROM currency
    ORDER BY id, updated DESC
),
volumes AS (
    SELECT user_id, type, currency_id, SUM(money) AS volume
    FROM balance
    GROUP BY user_id, type, currency_id
)
SELECT
    COALESCE(u.name, 'not defined')                    AS name,
    COALESCE(u.lastname, 'not defined')                AS lastname,
    v.type,
    v.volume,
    COALESCE(lr.name, 'not defined')                   AS currency_name,
    COALESCE(lr.rate_to_usd, 1)                        AS last_rate_to_usd,
    trim_scale(v.volume * COALESCE(lr.rate_to_usd, 1)) AS total_volume_in_usd
FROM volumes AS v
FULL JOIN "user"     AS u  ON v.user_id = u.id
LEFT JOIN last_rates AS lr ON v.currency_id = lr.id
ORDER BY 1 DESC, 2, 3;







-- CTE (Common Table Expression) — "подготовительный блок" last_rates:
-- Находим последний (самый свежий) курс для каждой валюты.
-- DISTINCT ON (id) — PostgreSQL-идиома: оставляет только ОДНУ строку
-- на каждый уникальный id. Какую именно — определяет ORDER BY.
-- ORDER BY id, updated DESC — для каждого id строки отсортированы
-- по updated от новых к старым, значит DISTINCT ON возьмёт первую,
-- то есть самую свежую. Результат: одна строка на валюту с последним курсом.
WITH last_rates AS (
    SELECT DISTINCT ON (id) id, name, rate_to_usd
    FROM currency
    ORDER BY id, updated DESC
),

-- CTE volumes: агрегация таблицы balance.
-- Группируем по user_id, type, currency_id и считаем SUM(money).
-- Это делается ДО джоинов, чтобы группировка шла по ID,
-- а не по именам (что было бы ненадёжно при одинаковых NULL-именах).
volumes AS (
    SELECT user_id, type, currency_id, SUM(money) AS volume
    FROM balance
    GROUP BY user_id, type, currency_id
)

-- Главный SELECT: соединяем подготовленные данные и формируем вывод
SELECT
    -- Имя пользователя. Если NULL — заменяем на 'not defined'
    COALESCE(u.name, 'not defined')                    AS name,

    -- Фамилия пользователя. Если NULL — заменяем на 'not defined'
    COALESCE(u.lastname, 'not defined')                AS lastname,

    -- Тип баланса (0, 1, 2...) из агрегированной таблицы volumes
    v.type,

    -- Суммарный объём денег по группе (user + type + currency)
    v.volume,

    -- Название валюты из last_rates. Если не найдена — 'not defined'
    COALESCE(lr.name, 'not defined')                   AS currency_name,

    -- Последний курс к USD. Если валюта не найдена — подставляем 1
    COALESCE(lr.rate_to_usd, 1)                        AS last_rate_to_usd,

    -- Итоговый объём в USD = volume * курс.
    -- trim_scale() убирает незначащие нули (369.0 → 369, 4.3500 → 4.35)
    trim_scale(v.volume * COALESCE(lr.rate_to_usd, 1)) AS total_volume_in_usd

-- Основа запроса — агрегированные балансы
FROM volumes AS v

-- FULL JOIN с user: сохраняем ВСЕ строки из обеих таблиц.
-- Баланс без пользователя (user_id=4) — сохранится с NULL-именами.
-- Пользователь без баланса — тоже сохранится.
FULL JOIN "user" AS u ON v.user_id = u.id

-- LEFT JOIN с last_rates: подтягиваем последний курс валюты.
-- LEFT, а не FULL, потому что нам не нужны валюты,
-- на которые никто не ссылается из balance (они не нужны в выводе).
-- Если currency_id не найден в last_rates (например, 210) —
-- lr.name и lr.rate_to_usd будут NULL, и COALESCE подставит значения.
LEFT JOIN last_rates AS lr ON v.currency_id = lr.id

-- Сортировка:
-- 1 DESC = name по убыванию (Петр > Иван > not defined)
-- 2 = lastname по возрастанию
-- 3 = type по возрастанию
ORDER BY 1 DESC, 2, 3;
```

## Краткая шпаргалка для защиты

**«Чем это лучше решения из чеклиста?»** — убран дублирующийся коррелированный подзапрос (в чеклисте один и тот же подзапрос для `rate_to_usd` написан дважды). `DISTINCT ON` заменяет подзапрос с `MAX(updated)` + коррелированный `SELECT` одной конструкцией. Код короче (18 строк вместо 30), читается сверху вниз.

**«Что такое CTE и зачем?»** — WITH-блоки подготавливают данные заранее: `last_rates` — последние курсы, `volumes` — суммы по группам. Основной SELECT только соединяет и выводит. Каждый блок можно объяснить и проверить отдельно.

**«Почему FULL JOIN с user, но LEFT JOIN с last_rates?»** — FULL JOIN с user нужен по заданию: показываем и пользователей без баланса, и балансы без пользователя. А LEFT JOIN с last_rates — потому что нам не нужны «бесхозные» валюты, на которые никто не ссылается.

**«Что такое DISTINCT ON?»** — это PostgreSQL-конструкция: из группы строк с одинаковым значением в скобках (id) оставляет только первую по ORDER BY. Аналог `ROW_NUMBER() = 1`, но короче.