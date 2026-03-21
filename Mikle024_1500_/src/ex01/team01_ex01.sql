INSERT INTO currency VALUES (100, 'EUR', 0.85, '2022-01-01 13:29');
INSERT INTO currency VALUES (100, 'EUR', 0.79, '2022-01-08 13:29');

CREATE OR REPLACE FUNCTION nearest_rate(p_cur_id bigint, p_date timestamp)
RETURNS numeric AS $$
DECLARE
    res numeric;
BEGIN
    SELECT rate_to_usd INTO res FROM (
        (SELECT rate_to_usd, (updated - p_date) AS time_diff
        FROM currency
        WHERE id = p_cur_id AND updated > p_date
        ORDER BY time_diff ASC LIMIT 1)
        UNION ALL
        (SELECT rate_to_usd, (p_date - updated) AS time_diff
        FROM currency
        WHERE id = p_cur_id AND updated < p_date
        ORDER BY time_diff ASC LIMIT 1)
    ) AS rates
    ORDER BY time_diff ASC LIMIT 1;

    RETURN res;
END;
$$ LANGUAGE plpgsql;

SELECT
    COALESCE(u.name, 'not defined') AS name,
    COALESCE(u.lastname, 'not defined') AS lastname,
    c.name AS currency_name,
    b.money * nearest_rate(b.currency_id, b.updated) AS currency_in_usd
FROM
    balance AS b
LEFT JOIN
    "user" AS u ON b.user_id = u.id
LEFT JOIN
    (SELECT DISTINCT id, name FROM currency) AS c ON b.currency_id = c.id
WHERE
    c.name IS NOT NULL
ORDER BY
    name DESC, lastname ASC, currency_name ASC;
