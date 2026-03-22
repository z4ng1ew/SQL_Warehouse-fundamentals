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