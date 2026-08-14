
WITH users_no_phone AS (
  SELECT id, row_number() over() as position_id
  FROM users
  WHERE phone is NULL
),
phone_sim AS (
  SELECT 
    row_number() over() as position_id,
    '+57 ' 
    || (ARRAY['300','310','315','321'])[floor(random() * 4 + 1)] 
    || lpad(floor(random() * 10000000)::text, 7, '0') AS new_phone
  FROM generate_series(1, (SELECT count(1) FROM users WHERE phone is NULL))
)
UPDATE users AS u
SET phone = ps.new_phone
FROM users_no_phone AS unp
JOIN phone_sim AS ps
  ON unp.position_id = ps.position_id
WHERE u.id = unp.id;
