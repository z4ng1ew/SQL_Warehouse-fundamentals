WITH last_rates AS (
    SELECT id, name, rate_to_usd
    FROM (
        SELECT id, name, rate_to_usd,
               ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated DESC) AS rn
        FROM currency
    ) sub
    WHERE rn = 1
),
aggregated_balance AS (
    SELECT user_id, type, currency_id,
           SUM(money) AS volume
    FROM balance
    GROUP BY user_id, type, currency_id
)
SELECT
    COALESCE(u.name, 'not defined')        AS name,
    COALESCE(u.lastname, 'not defined')    AS lastname,
    ab.type,
    ab.volume,
    COALESCE(lr.name, 'not defined')       AS currency_name,
    COALESCE(lr.rate_to_usd, 1)            AS last_rate_to_usd,
    ab.volume * COALESCE(lr.rate_to_usd, 1) AS total_volume_in_usd
FROM aggregated_balance AS ab
FULL JOIN "user"     AS u  ON ab.user_id = u.id
LEFT JOIN last_rates AS lr ON ab.currency_id = lr.id
ORDER BY name DESC, lastname ASC, type ASC;