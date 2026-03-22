SELECT
    COALESCE(u.name, 'not defined') AS name,
    COALESCE(u.lastname, 'not defined') AS lastname,
    t1.type,
    t1.volume,
    COALESCE(c.name, 'not defined') AS currency_name,
    COALESCE(
        (SELECT rate_to_usd
         FROM currency c1
         WHERE c1.id = c.id
           AND c1.updated = c.last_updated),
        1
    ) AS last_rate_to_usd,
    trim_scale(t1.volume::numeric * COALESCE(
        (SELECT rate_to_usd
         FROM currency c1
         WHERE c1.id = c.id
           AND c1.updated = c.last_updated),
        1
    )) AS total_volume_in_usd
FROM (
    SELECT user_id, type, currency_id, SUM(money) AS volume
    FROM balance b
    GROUP BY user_id, type, currency_id
) AS t1
FULL JOIN "user" u ON u.id = t1.user_id
FULL JOIN (
    SELECT id, name, MAX(updated) AS last_updated
    FROM currency c
    GROUP BY id, name
) AS c ON c.id = t1.currency_id
ORDER BY 1 DESC, 2, 3;















-- Главный SELECT: формируем итоговую таблицу с 7 столбцами
SELECT
    -- Имя пользователя. Если NULL — заменяем на 'not defined'
    COALESCE(u.name, 'not defined') AS name,

    -- Фамилия пользователя. Если NULL — заменяем на 'not defined'
    COALESCE(u.lastname, 'not defined') AS lastname,

    -- Тип баланса (0, 1, 2...) — берём из агрегированной таблицы t1
    t1.type,

    -- Суммарный объём денег по группе (user + type + currency)
    t1.volume,

    -- Название валюты. Если валюта не найдена (NULL) — 'not defined'
    COALESCE(c.name, 'not defined') AS currency_name,

    -- Последний курс валюты к USD.
    -- Коррелированный подзапрос: для каждой строки ищет rate_to_usd
    -- в таблице currency, где id совпадает и updated = максимальному.
    -- Если курс не найден (NULL) — подставляем 1
    COALESCE(
        (SELECT rate_to_usd
         FROM currency c1
         WHERE c1.id = c.id
           AND c1.updated = c.last_updated),
        1
    ) AS last_rate_to_usd,

    -- Итоговый объём в USD = volume * last_rate_to_usd.
    -- volume::numeric — приведение типа к numeric для точного умножения.
    -- trim_scale() — убирает незначащие нули (369.0 → 369, 4.3500 → 4.35)
    trim_scale(t1.volume::numeric * COALESCE(
        (SELECT rate_to_usd
         FROM currency c1
         WHERE c1.id = c.id
           AND c1.updated = c.last_updated),
        1
    )) AS total_volume_in_usd

-- Подзапрос t1: агрегация таблицы balance.
-- Группируем по user_id, type, currency_id и считаем SUM(money).
-- Это делается ДО джоинов, чтобы группировка шла по ID,
-- а не по именам (что было бы ненадёжно при NULL-именах)
FROM (
    SELECT user_id, type, currency_id, SUM(money) AS volume
    FROM balance b
    GROUP BY user_id, type, currency_id
) AS t1

-- FULL JOIN с таблицей user: сохраняем ВСЕ строки из обеих таблиц.
-- Если есть баланс без пользователя (user_id=4) — строка сохранится.
-- Если есть пользователь без баланса — тоже сохранится.
FULL JOIN "user" u ON u.id = t1.user_id

-- FULL JOIN с подзапросом по currency:
-- Внутри подзапроса находим MAX(updated) для каждой валюты —
-- это timestamp последнего обновления курса.
-- FULL JOIN сохраняет строки, даже если currency_id из balance
-- не найден в currency (например, currency_id=210 не существует)
FULL JOIN (
    SELECT id, name, MAX(updated) AS last_updated
    FROM currency c
    GROUP BY id, name
) AS c ON c.id = t1.currency_id

-- Сортировка:
-- 1 DESC = name по убыванию (Петр > Иван > not defined)
-- 2 = lastname по возрастанию
-- 3 = type по возрастанию
ORDER BY 1 DESC, 2, 3;