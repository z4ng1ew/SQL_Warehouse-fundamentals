WITH last_rates AS (
    SELECT id, name, rate_to_usd
    FROM (
        SELECT id, name, rate_to_usd,
            ROW_NUMBER() OVER(PARTITION BY id ORDER BY updated DESC) AS rn
        FROM currency
    ) t
    WHERE rn = 1
)
SELECT
    COALESCE(u.name, 'not defined') AS name,
    COALESCE(u.lastname, 'not defined') AS lastname,

    b.type,

    SUM(b.money) AS volume,
    COALESCE(lr.name, 'not defined') AS currency_name,
    COALESCE(lr.rate_to_usd, 1) AS last_rate_to_usd,
    SUM(b.money) * COALESCE(lr.rate_to_usd, 1) AS total_volume_in_usd
FROM balance AS b

FULL JOIN
    "user" AS u ON b.user_id = u.id
LEFT JOIN
    last_rates AS lr ON b.currency_id = lr.id
GROUP BY
    u.name, u.lastname, b.type, lr.name, lr.rate_to_usd
ORDER BY
    name DESC, lastname ASC, type ASC;
