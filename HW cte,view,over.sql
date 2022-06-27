--=============== МОДУЛЬ 6. POSTGRESQL =======================================
--= ПОМНИТЕ, ЧТО НЕОБХОДИМО УСТАНОВИТЬ ВЕРНОЕ СОЕДИНЕНИЕ И ВЫБРАТЬ СХЕМУ PUBLIC===========
SET search_path TO public;

--======== ОСНОВНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Напишите SQL-запрос, который выводит всю информацию о фильмах 
--со специальным атрибутом "Behind the Scenes".

--1. Каким оператором или функцией языка SQL, используемых при выполнении домашнего задания, 
--   поиск значения в массиве происходит быстрее
--2. какой вариант вычислений работает быстрее: 
--   с использованием CTE или с использованием подзапроса
explain analyze --68.84 Execution Time: 0.569 ms
SELECT 
	film_id ,
	initcap(title) ,
	special_features 
FROM film f 
where special_features @> '{Behind the Scenes}';


--ЗАДАНИЕ №2
--Напишите еще 2 варианта поиска фильмов с атрибутом "Behind the Scenes",
--используя другие функции или операторы языка SQL для поиска значения в массиве.
explain analyze --68.84 Execution Time: 13.493 ms
select 
	film_id, 
	initcap(title), 
	special_features
from film f 
where array_position(special_features, 'Behind the Scenes') > 0;

explain analyze --68.84 Execution Time: 0.603 ms
SELECT 
	film_id ,
	initcap(title) ,
	special_features 
FROM film f 
where '{Behind the Scenes}' && special_features;

--ЗАДАНИЕ №3
--Для каждого покупателя посчитайте сколько он брал в аренду фильмов 
--со специальным атрибутом "Behind the Scenes.
--Обязательное условие для выполнения задания: используйте запрос из задания 1, 
--помещенный в CTE. CTE необходимо использовать для решения задания.
explain analyze --675.48 Execution Time: 12.314 ms
with cte as (
	SELECT 
		film_id ,
		initcap(title) ,
		special_features 
	FROM film f 
	where special_features @> '{Behind the Scenes}')
select 
	r.customer_id,
	count(cte.film_id) 
from cte
join inventory i on i.film_id = cte.film_id
join rental r on r.inventory_id = i.inventory_id 
group by r.customer_id
order by r.customer_id ;

--ЗАДАНИЕ №4
--Для каждого покупателя посчитайте сколько он брал в аренду фильмов
-- со специальным атрибутом "Behind the Scenes".
--Обязательное условие для выполнения задания: используйте запрос из задания 1,
--помещенный в подзапрос, который необходимо использовать для решения задания.
explain analyze --675.48 Execution Time: 10.206 ms
select 
	r.customer_id,
	count(cte.film_id) 
from (
	SELECT 
		film_id ,
		initcap(title) ,
		special_features 
	FROM film f 
	where special_features @> '{Behind the Scenes}') cte
join inventory i on i.film_id = cte.film_id
join rental r on r.inventory_id = i.inventory_id 
group by r.customer_id
order by r.customer_id ;

--ЗАДАНИЕ №5
--Создайте материализованное представление с запросом из предыдущего задания
--и напишите запрос для обновления материализованного представления
create materialized view view_name as
select 
	r.customer_id,
	count(cte.film_id) 
from (
	SELECT 
		film_id ,
		initcap(title) ,
		special_features 
	FROM film f 
	where special_features @> '{Behind the Scenes}') cte
join inventory i on i.film_id = cte.film_id
join rental r on r.inventory_id = i.inventory_id 
group by r.customer_id
order by r.customer_id ;

REFRESH MATERIALIZED view view_name;

--ЗАДАНИЕ №6
--С помощью explain analyze проведите анализ скорости выполнения запросов
-- из предыдущих заданий и ответьте на вопросы:

--1. Каким оператором или функцией языка SQL, используемых при выполнении домашнего задания, 
--   поиск значения в массиве происходит быстрее
-- Поиски значения затрачивают одинаковое количество операционных единиц. Быстрее отработал вариант с "@>"

--2. какой вариант вычислений работает быстрее: 
--   с использованием CTE или с использованием подзапроса
-- Вычисления затрачивают одинаковое количество операционных единиц. Быстрее отработал вариант с подзапросом


--======== ДОПОЛНИТЕЛЬНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Выполняйте это задание в форме ответа на сайте Нетологии
--explain analyze
select distinct cu.first_name  || ' ' || cu.last_name as name, 
	count(ren.iid) over (partition by cu.customer_id)
from customer cu
full outer join 
	(select *, r.inventory_id as iid, inv.sf_string as sfs, r.customer_id as cid
	from rental r 
	full outer join 
		(select *, unnest(f.special_features) as sf_string -- фун-ция unnest приведет к увеличению кол-ва строк -> избыточность данных
		from inventory i
		full outer join film f on f.film_id = i.film_id) as inv -- будет достаточно использовать join. 
		on r.inventory_id = inv.inventory_id) as ren 
	on ren.cid = cu.customer_id 
where ren.sfs like '%Behind the Scenes%'
order by count desc;


--ЗАДАНИЕ №2
--Используя оконную функцию выведите для каждого сотрудника
--сведения о самой первой продаже этого сотрудника.
select 
	staff_id ,
	film_id ,
	title ,
	amount ,
	payment_date ,
	last_name as customer_last_name,
	first_name as customer_first_name
from (
select 
	row_number () over(partition by p.staff_id order by p.staff_id, p.payment_date) as numb,
	p.staff_id ,
	f.film_id ,
	f.title ,
	p.amount ,
	p.payment_date ,
	c.last_name ,
	c.first_name
from payment p 
join rental r on r.rental_id = p.rental_id 
join inventory i on i.inventory_id = r.inventory_id 
join film f on f.film_id = i.film_id 
join customer c on c.customer_id = p.customer_id ) fin 
where fin.numb = 1;

--ЗАДАНИЕ №3
--Для каждого магазина определите и выведите одним SQL-запросом следующие аналитические показатели:
-- 1. день, в который арендовали больше всего фильмов (день в формате год-месяц-день)
-- 2. количество фильмов взятых в аренду в этот день
-- 3. день, в который продали фильмов на наименьшую сумму (день в формате год-месяц-день)
-- 4. сумму продажи в этот день
with fin_cte as (
with f_cte as (
select -- выбор дня с максимальным количеством фильмов
	*
from (
select -- подсчет количества фильмов в день и проставления номеров в порядке убывания
	row_number () over(partition by i.store_id order by count(i.film_id) desc) as numb_count,
	count(i.film_id) as f_count,
	i.store_id, p.payment_date::date as film_day
from payment p 
join rental r on r.rental_id = p.rental_id 
join inventory i on i.inventory_id = r.inventory_id
group by i.store_id, p.payment_date::date) fin_count
where numb_count = 1)
select -- выбор дня с минимальной суммой
	fin_sum.store_id,
	numb_count,
	f_count,
	film_day,
	numb_sum,
	a_sum,
	amount_day
from (
select -- подсчет сумм проданных фильмов за каждый день
	row_number () over(partition by s.store_id order by sum(p.amount)) as numb_sum,
	sum(p.amount) as a_sum,
	s.store_id, p.payment_date::date as amount_day
from payment p 
join staff s on s.staff_id = p.staff_id 
group by s.store_id, p.payment_date::date) fin_sum
join f_cte on f_cte.store_id = fin_sum.store_id
where numb_sum = 1)
select
	store_id as "ID магазина",
	film_day as "день, в который арендовали больше всего фильмов",
	f_count as "количество фильмов взятых в аренду",
	amount_day as "день, в который продали фильмов на наименьшую сумму",
	a_sum as "сумму продажи "
from fin_cte;