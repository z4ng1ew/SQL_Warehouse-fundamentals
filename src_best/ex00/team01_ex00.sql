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
    COALESCE(u.name, 'not defined')         AS name,
    COALESCE(u.lastname, 'not defined')     AS lastname,
    v.type,
    v.volume,
    COALESCE(lr.name, 'not defined')        AS currency_name,
    COALESCE(lr.rate_to_usd, 1)             AS last_rate_to_usd,
    v.volume * COALESCE(lr.rate_to_usd, 1)  AS total_volume_in_usd
FROM volumes AS v
FULL JOIN "user"     AS u  ON v.user_id = u.id
LEFT JOIN last_rates AS lr ON v.currency_id = lr.id
ORDER BY 1 DESC, 2, 3;