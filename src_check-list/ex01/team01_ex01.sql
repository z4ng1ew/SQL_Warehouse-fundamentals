SELECT
    t1.name,
    t1.lastname,
    t1.currency_name,
    trim_scale(t1.money * t1.rate_to_usd) AS currency_in_usd
FROM (
    SELECT
        COALESCE(u.name, 'not defined') AS name,
        COALESCE(u.lastname, 'not defined') AS lastname,
        c.name AS currency_name,
        b.money,
        COALESCE(
            (SELECT rate_to_usd
             FROM currency c1
             WHERE b.currency_id = c1.id
               AND c1.updated < b.updated
             ORDER BY c1.updated DESC
             LIMIT 1),
            (SELECT rate_to_usd
             FROM currency c2
             WHERE b.currency_id = c2.id
               AND c2.updated > b.updated
             ORDER BY c2.updated ASC
             LIMIT 1)
        ) AS rate_to_usd
    FROM balance b
    INNER JOIN (
        SELECT c.id, c.name
        FROM currency c
        GROUP BY c.id, c.name
    ) AS c ON c.id = b.currency_id
    LEFT JOIN "user" u ON u.id = b.user_id
) AS t1
ORDER BY 1 DESC, 2, 3;