-- user status

select status, count(*) from users group by status order by count(*) desc;

-- Lower priority of abusers

update users set priority = 131072 where id in (
	select user_id from tracks where query='source:twitarmy');
update users set priority = 262144 where id in (
	select user_id from tracks where query='source:identica');
