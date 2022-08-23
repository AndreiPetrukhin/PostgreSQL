--Task Создайте в базе таблицу с названием source_systems, в которой вы будете вести справочник всех систем-источников. 
--Источники будут такие же, как в этом справочнике:
create table source_systems (
  id integer unique,
  code char(3),
  name varchar(100),
  "desc" varchar(255)
  );

insert into source_systems (id, code, name, "desc")
values
(1,'001','Moscow CRM' ,'Система по работе с клиентами в офисе в Москве'),
(2,'002','SPB CRM' ,'Система по работе с клиентами в офисе в Санкт-Петербурге'),
(3,'003','Online shop' ,'Онлайн-магазин компании');

select * from source_systems;

select * from "002_BUFF_clients";

create table "002_DM_clients" (
    client_id integer primary key, 
    client_firstname varchar(100), 
    client_lastname varchar(100), 
    client_email varchar(100), 
    client_phone text, 
    client_city varchar(100)
); 

COPY "002_DM_clients"(client_id, client_firstname, client_lastname, client_email, 
					  client_phone, client_city)
FROM '/lessons/3. Витрина наносит ответный удар/5. Как загрузить новый источник данных/Задание 2/clients.csv'
DELIMITER ','
CSV HEADER;

--Прежде чем рассчитывать статистику по возрастным группам, необходимо обновить информацию в текущей таблице. Файл с новым 
--полем age загружен в таблицу 002_BUFF_clients.
--Создайте в существующей таблице поле age.
--Заполните значения поля age соответствующей информацией из файла 002_BUFF_clients с помощью команды UPDATE.
--Проверьте, что записи обновились корректно, сравнив данные двух таблиц.
--Если все записи были обновлены, удалите таблицу 002_BUFF_clients — она уже не нужна.
alter table "002_DM_clients" 
add column "age" integer;

update "002_DM_clients"
SET age = "002_BUFF_clients".age
FROM  "002_BUFF_clients"
WHERE "002_DM_clients".client_id =  "002_BUFF_clients".client_id;

drop table "002_BUFF_clients";

--Task Посчитайте, какая возрастная категория тратит больше всего денег. Категории — 18–25, 26–30, 31–40, 41–55, 55+.
select 
	dmc.category,
	sum(uapd.total_payment_amount) as summa
from user_activity_payment_datamart uapd
join (
	select
		client_id,
		age,
		case 
		when age >= 18 and age <=25 then '18–25'
		when age >= 26 and age <=30 then '26–30'
		when age >= 31 and age <=40 then '31–40'
		when age >= 41 and age <=55 then '41–55'
		when age > 55 then '55+'
		end as category
	from "002_DM_clients"
	) dmc on dmc.client_id = uapd.client_id
group by dmc.category
order by sum(uapd.total_payment_amount) desc;

--Чтобы обновить витрину (добавив предыдущий запрос), удалите старое материализованное представление и создайте новое.
DROP materialized VIEW IF EXISTS user_activity_payment_datamart;
CREATE materialized view user_activity_payment_datamart AS (
WITH ual AS (
	SELECT client_id,
				 DATE(MIN(CASE WHEN action = 'visit' THEN hitdatetime ELSE NULL END)) AS fst_visit_dt,
				 DATE(MIN(CASE WHEN action = 'registration' THEN hitdatetime ELSE NULL END)) AS registration_dt,
				 MAX(CASE WHEN action = 'registration' THEN 1 ELSE 0 END) AS is_registration
	FROM user_activity_log
	GROUP BY client_id
),
upl AS (
  SELECT client_id,
			   SUM(payment_amount) AS total_payment_amount
  FROM user_payment_log
	GROUP BY client_id
)
SELECT ua.client_id,
       ua.utm_campaign,
       ual.fst_visit_dt,
       ual.registration_dt,
       ual.is_registration,
       upl.total_payment_amount,
  		dmc.category
FROM user_attributes AS ua
LEFT JOIN ual ON ua.client_id = ual.client_id
LEFT JOIN upl ON ua.client_id = upl.client_id
JOIN (
	select
		client_id,
		age,
		case 
		when age >= 18 and age <=25 then '18–25'
		when age >= 26 and age <=30 then '26–30'
		when age >= 31 and age <=40 then '31–40'
		when age >= 41 and age <=55 then '41–55'
		when age > 55 then '55+'
		end as category
	from "002_DM_clients"
	) dmc on dmc.client_id = ua.client_id
);
select * from user_activity_payment_datamart uapd;