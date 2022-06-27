--=============== МОДУЛЬ 5. РАБОТА С POSTGRESQL =======================================
--= ПОМНИТЕ, ЧТО НЕОБХОДИМО УСТАНОВИТЬ ВЕРНОЕ СОЕДИНЕНИЕ И ВЫБРАТЬ СХЕМУ PUBLIC===========
SET search_path TO public;

--======== ОСНОВНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Сделайте запрос к таблице payment и с помощью оконных функций добавьте вычисляемые колонки согласно условиям:
--Пронумеруйте все платежи от 1 до N по дате
--Пронумеруйте платежи для каждого покупателя, сортировка платежей должна быть по дате
--Посчитайте нарастающим итогом сумму всех платежей для каждого покупателя, сортировка должна 
--быть сперва по дате платежа, а затем по сумме платежа от наименьшей к большей
--Пронумеруйте платежи для каждого покупателя по стоимости платежа от наибольших к меньшим 
--так, чтобы платежи с одинаковым значением имели одинаковое значение номера.
--Можно составить на каждый пункт отдельный SQL-запрос, а можно объединить все колонки в одном запросе.
select
	customer_id, 
	payment_id, 
	payment_date,
	row_number () over (order by payment_date) as "Номер по дате", --Сортируем по дате
	row_number () over (partition by customer_id order by payment_date) as "Номер по покупателям + дата", --Разделяем по покупателям, сортируем по дате
	sum(amount) over(partition by customer_id order by payment_date::date, amount) as "Наростающая сумма", --Разделяем по покупателям, сортируем по дате без времени, далее сортируем по стоимости
	dense_rank () over(partition by customer_id order by amount desc) as "Номера по стоимости" --Разделяем по покупателям, сортируем по оплате от большего к меньшему
from payment p ;

--ЗАДАНИЕ №2
--С помощью оконной функции выведите для каждого покупателя стоимость платежа и стоимость 
--платежа из предыдущей строки со значением по умолчанию 0.0 с сортировкой по дате.

--explain analyze --(cost=1400.53..1721.51 rows=16049 width=52) (actual time=9.123..21.879 rows=16049 loops=1)
select
	customer_id,
	payment_id,
	payment_date,
	amount,
	(case 
		when lag(amount) over(partition by customer_id order by payment_date) is null then 0.0 --Если null, то присвоить значение 0.0
	else 
		lag(amount) over(partition by customer_id order by payment_date) --Если не null, то оставить значение lag(amount)
	end) as last_amount
from payment p ;

--или более оптимальный по actual time

--explain analyze --(cost=1400.53..1721.51 rows=16049 width=52) (actual time=4.715..13.768 rows=16049 loops=1)
select
	customer_id,
	payment_id,
	payment_date,
	amount,
	lag(amount, 1, 0.0) over(partition by customer_id order by payment_date) as last_amount --lag(значение, шаг, первое значение)
from payment p ;

--ЗАДАНИЕ №3
--С помощью оконной функции определите, на сколько каждый следующий платеж покупателя больше или меньше текущего.
--не понимаю, почему в ответе указаны значения с противоположным знаком. Ведь в условии сказано "на сколько каждый 
--следующий платеж покупателя больше или меньше текущего", то есть следующий платеж минус текущий. Разве нет?

--explain analyze --(cost=1400.53..1922.12 rows=16049 width=52) (actual time=4.631..15.935 rows=16049 loops=1)
select 
	customer_id,
	payment_id,
	payment_date,
	amount,
	fin.last_amount - fin.amount as difference
from (
	select
		customer_id,
		payment_id,
		payment_date,
		amount,
		lead(amount, 1, 0.0) over(partition by customer_id order by payment_date) as last_amount --lead(значение, шаг, последнее значение)
	from payment p ) fin;

--или

--explain analyze --(cost=1400.53..1761.63 rows=16049 width=52) (actual time=4.851..15.615 rows=16049 loops=1)
select
	customer_id,
	payment_id,
	payment_date,
	amount,
	(lead(amount, 1, 0.0) over(partition by customer_id order by payment_date) - amount) as difference --lead(значение, шаг, последнее значение)
from payment p;

--ЗАДАНИЕ №4
--С помощью оконной функции для каждого покупателя выведите данные о его последней оплате аренды.
select 
	customer_id,
	payment_id,
	payment_date,
	amount
from (
	select 
		*,
		dense_rank() over(partition by customer_id order by payment_date desc) as numbs --Найдем все оплаты последние по дате, присваивая им ранк 1. Используем dense_rank, так как может быть несколько оплат (оплата+ошибки) в одно время 
	from payment p) fin
where fin.numbs = 1 and amount != 0; -- фильтруем самые последние даты по ранку и убираем "ошибочные" полаты с стоимостью 0

--======== ДОПОЛНИТЕЛЬНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--С помощью оконной функции выведите для каждого сотрудника сумму продаж за август 2005 года 
--с нарастающим итогом по каждому сотруднику и по каждой дате продажи (без учёта времени) 
--с сортировкой по дате.
select
	fin.staff_id,
	fin.payment as "payment_date",
	fin.sum_amount,
	sum(sum_amount) over(partition by fin.staff_id order by fin.payment) as "sum"
from (
	select 
		staff_id,
		to_char(payment_date, 'DD.MM.YYYY') as payment,
		sum(amount) as sum_amount
	from payment p
	where payment_date::date between '2005-08-01' and '2005-08-31'
	group by staff_id, to_char(payment_date, 'DD.MM.YYYY') ) fin;


--ЗАДАНИЕ №2
--20 августа 2005 года в магазинах проходила акция: покупатель каждого сотого платежа получал
--дополнительную скидку на следующую аренду. С помощью оконной функции выведите всех покупателей,
--которые в день проведения акции получили скидку
select
	fin.customer_id,
	fin.payment_date,
	fin.payment_number
from (
	select
		*,
		row_number() over(order by payment_date) as payment_number --Не совсем понимаю, почему здесь лучше использовать row_number. Ведь так мы не учитываем оплаты произведенные в одно время...
	from payment p
	where payment_date::date = '2005-08-20') fin
where fin.payment_number % 100 = 0;


--ЗАДАНИЕ №3
--Для каждой страны определите и выведите одним SQL-запросом покупателей, которые попадают под условия:
-- 1. покупатель, арендовавший наибольшее количество фильмов
-- 2. покупатель, арендовавший фильмов на самую большую сумму
-- 3. покупатель, который последним арендовал фильм
--не рабочая
select 
	fin.country,
	case 
		when fin.count = max(fin.count) then fin.name
	end
from
	(select
		c3.country,
		concat_ws(' ', c.first_name, c.last_name) as "name",
		count(i.film_id) as "count",
		sum(p.amount) as "sum",
		max(p.payment_date) as "max"
	from payment p 
	left join customer c on c.customer_id = p.customer_id 
	left join address a on a.address_id = c.address_id 
	left join city c2 on c2.city_id = a.city_id 
	left join country c3 on c3.country_id = c2.country_id 
	left join rental r on r.rental_id = p.rental_id 
	left join inventory i on i.inventory_id = r.inventory_id 
	group by c3.country, c.customer_id
	order by c3.country, c.customer_id) fin
group by fin.country;