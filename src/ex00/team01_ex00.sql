
  select coalesce(u.name,'not defined') as name,
  coalesce(u.lastname,'not defined') as lastname,
  t1.type,
  t1.volume,
  coalesce(c.name,'not defined') as currency_name,
  coalesce((select rate_to_usd from currency c1 where c1.id = c.id and c1.updated = c.l
  ast_updated),

1) as last_rate_to_usd,
   t1.volume::numeric * coalesce((select rate_to_usd
   from currency c1 where c1.id = c.id and c1.updated = c.last_updated),1) as total_volu
   me_in_usd
   from (
   select user_id, type, currency_id, sum(money) as volume
   from balance b
   group by user_id,type, currency_id) as t1
   full join "user" u on u.id = t1.user_id
   full join (select id,name,max(updated) as last_updated from currency c group by id, na
   me) as c on c.id = t1.currency_id
   order by 1 desc,2,3;