
--1. В каких городах больше одного аэропорта?
select 
	city as "Название города", --(4) выводим список городов у которых более одного аэропорта
	count(airport_code) as "Число аэропортов" --(5) подсчитываем количество аэропортов через агрегирующую функцию
from airports a -- (1) из таблицы Аэропорты
group by city -- (2) группируем по колонке города, чтобы посчитать количество аэропортов в каждом
having count(airport_code) > 1; --(3) подсчитываем количество аэропортов через агрегирующую функцию, убираем города у которых меньше или один аэропорт


--2. В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета? 
-- Подзапрос

select distinct -- (3) выводим значения без повторов
	departure_airport as "Аэропорт" -- (4) выводим аэропорты
from flights f -- (1) таблицы полеты
where aircraft_code = ( -- (2) фильтруем самолет с самым большой дальностью
	select 
		aircraft_code -- (2.4) выводим сод самолета с максимальной дальностью перелета 
	from aircrafts a -- (2.1) из таблицы самолеты
	order by "range" desc -- (2.2) сортируем по дальности полета в обратном порядеке, что бы найти самолеты с максимальной дальностью перелета в начале списка
	limit 1); -- (2.3) выбираем только один самолет с максимальной дальностью перелета

--3. Вывести 10 рейсов с максимальным временем задержки вылета (10 место могут занимать несколько рейсов. выводить их все?) 
-- Оператор LIMIT
select 
	flight_id as "Идентификатор рейса", --(5) выводим Идентификатор рейса
	flight_no as "Номер рейса", --(6) выводим Номер рейса
	actual_departure - scheduled_departure as "Максимальное время задержки вылета" --(7) рассчитываем максимальное время задержки вылета и выводим его
from flights f -- (1) из таблицы рейсов
where actual_departure is not null --(2) где имеется Фактическое время вылета (без него не сможем посчитать задержку)
order by actual_departure - scheduled_departure desc --(3) рассчитываем максимальное время задержки вылета, сортируем по нему обратном порядке (от самого большого к малому)
limit 10; --(4) ставим ограничение на вывод 10 первых строк

-- 4. Были ли брони, по которым не были получены посадочные талоны? 
-- Верный тип JOIN
-- Логика запроса: сопоставить номера бронирований (уникальные знчения) из тиблицы bookings с номерами 
-- посадочных талонов, которые присваиваются после регистрации на рейс.

select
	count(b.book_ref) as "Кол-во броней без полученных посадочных" -- (5) подсчитваем количество уникальных (так как в одной брони может быть несколько билетов) номеров бронирования
from bookings b -- (1) из таблицы бронирования. Так как данная таблица содержит полный перечень номеров бронирования
left join tickets t on t.book_ref = b.book_ref -- (2) присоединяем значения таблицы билеты. Мб использован как join, так и left join. Так как билеты создаются одновременно с бронью
left join boarding_passes bp on bp.ticket_no = t.ticket_no -- (3) присоединяем значения таблицы посадочный талон. Используется только left join, так как талон создается за сутки до полета
where bp.boarding_no is null; -- (4) условие отсутствия хотя бы одного талона у брони

-- 5. Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
--Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого 
--аэропорта на каждый день. Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже 
--вылетело из данного аэропорта на этом или более ранних рейсах в течении дня.
-- - Оконная функция
-- - Подзапросы или/и cte

-- 5.1 Способ через присоединение таблиц ticket_flights и boarding_passes к flights через left join. Таким образом 
--сможем получить объединенные данные из всех таблиц и учесть рейсы, которые отправились в путь без проданных 
--билетов и присвоенных номеров мест. НО обработка данных будет "стоить дороже" с точки зрения вычислительных
--ресурсов.

--explain analyze --64372.17
select
	bought_p.flight_id as "Идентификатор рейса",
	bought_p.aircraft_code,
	total_p.total_places,
	bought_p.bought_places,
	total_p.total_places - bought_p.bought_places as "количество свободных мест",
	(total_p.total_places - bought_p.bought_places)*100/total_p.total_places as "% отн к кол-ву мест в самолете",
	bought_p.departure_airport,
	bought_p.actual_departure,
	sum(bought_p.bought_places) over(partition by bought_p.departure_airport, bought_p.actual_departure::date order by bought_p.departure_airport, bought_p.actual_departure) as "кол-во вывезенных пассажиров"
from 
	(select --find amount of bought places for each flight
		f.flight_id,
		f.flight_no,
		f.aircraft_code,
		f.departure_airport,
		f.actual_departure,
		count(bp.seat_no) as bought_places
	from flights f 
	left join ticket_flights tf on tf.flight_id = f.flight_id 
	left join boarding_passes bp on bp.flight_id = tf.flight_id and bp.ticket_no = tf.ticket_no
	where f.actual_departure is not null
	group by f.flight_id
	) bought_p
left join 
	(select -- find amount of places for each aircraft
		s.aircraft_code,
		count(s.seat_no) as total_places
	from seats s  
	group by s.aircraft_code
	) total_p on total_p.aircraft_code = bought_p.aircraft_code;

-- 5.2 Способ через присоединение таблицы boarding_passes к flights через join. Таким образом не учитываем 
--рейсы у которых нет билетов или которым не присвоены места. Теряем информацию о рейсах, которые отправились 
--в полет без проданных билетов.
--Обработка данных будет "стоить дешевле" приблизительно в 4 раза с точки зрения вычислительных ресурсов.

--explain analyze --15808.57
select
	bought_p.flight_id as "Идентификатор рейса",
	bought_p.aircraft_code,
	total_p.total_places,
	bought_p.bought_places,
	total_p.total_places - bought_p.bought_places as "количество свободных мест",
	(total_p.total_places - bought_p.bought_places)*100/total_p.total_places as "% отн к кол-ву мест в самолете",
	bought_p.departure_airport,
	bought_p.actual_departure,
	sum(bought_p.bought_places) over(partition by bought_p.departure_airport, bought_p.actual_departure::date order by bought_p.departure_airport, bought_p.actual_departure) as "кол-во вывезенных пассажиров"
from 
	(select --find amount of bought places for each flight
		f.flight_id,
		f.flight_no,
		f.aircraft_code,
		f.departure_airport,
		f.actual_departure,
		count(bp.seat_no) as bought_places
	from flights f 
	join boarding_passes bp on bp.flight_id = f.flight_id
	where f.actual_departure is not null
	group by f.flight_id
	) bought_p
left join 
	(select -- find amount of places for each aircraft
		s.aircraft_code,
		count(s.seat_no) as total_places
	from seats s  
	group by s.aircraft_code
	) total_p on total_p.aircraft_code = bought_p.aircraft_code;

--6. Найдите процентное соотношение перелетов по типам самолетов от общего количества.
-- Подзапрос или окно
-- Оператор ROUND
select
	a.aircraft_code as "Код самолета", -- (4) выводим код самолетов
	a.model as "Модель самолета",
	count(flight_id) as "Кол-во перелетов по типам самолетов", -- (5) рассчитываем кол-во перелетов для каждого типа самолетов
	round( -- (6.1) оборачиваем рассчет в в функцию округления
	count(flight_id)*100/( -- (6.2) рассчитываем кол-во перелетов для каждого типа самолетов
		select 
			count(flight_id) -- (6.5) получаем общее количество перелетов для всех типов самолетов
		from flights f  -- (6.3)  из таблицы полетов 
		)::numeric, 2) -- (6.6) занчению выражения присваеваем тип вещественного числа. округляем до второго знака после запятой
		as "% к общему числу перелетов"
from aircrafts a  -- (1) из таблицы полетов
join flights f on f.aircraft_code = a.aircraft_code
group by a.aircraft_code ; -- (3) группируем данные по типу самолетов, чтобы рассчитать кол-во перелетов для каждого типа через аггрегирующую функцию

--7. Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?
-- CTE
explain analyze
	with cte_mm as (
		with cte_min as (
			select -- (1) Поиск минимальных стоимостей билетов бизнес класса по всем рейсам
				flight_id as flight_id_bus, 
				fare_conditions as business,
				min(amount) as value_bus
			from ticket_flights tf
			where fare_conditions = 'Business'
			group by flight_id, fare_conditions)
		select 
			*
		from cte_min
		join (
			select -- (2) Поиск максимальных стоимостей билетов эконом класса по всем рейсам
				flight_id as flight_id_eco,
				fare_conditions as econom,
				max(amount) as value_eco
			from ticket_flights tf
			where fare_conditions = 'Economy'
			group by flight_id, fare_conditions) cte_max on cte_max.flight_id_eco = cte_min.flight_id_bus
			)
select
	flight_id_eco,
	a.city,
	value_bus,
	value_eco
from cte_mm
join flights f on f.flight_id = cte_mm.flight_id_eco
join airports a on a.airport_code = f.arrival_airport 
where value_eco > value_bus;

--8. Между какими городами нет прямых рейсов?
-- Декартово произведение в предложении FROM
-- Самостоятельно созданные представления (если облачное подключение, то без представления)
-- Оператор EXCEPT
--8.1 Оптимальный вариант
--explain analyze --Execution Time: 30.254 ms
create view far_cities as
select -- декартово произведение навзаний городов - создание всевозможных комбинации
	a.city as city_1,
	a2.city as city_2
from airports a, airports a2 
where a.city > a2.city --фильтруем все пары городов с аналогичным наименованием (мск-мск) и повторяющиеся пары нименований в противоположном порядке
except -- искючаем все пары городов, которые имеют прямые перелеты
select distinct
	a.city as city_dep,
	a2.city as city_arr
from flights f
join airports a on a.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport;

--8.2 
--explain analyze --Execution Time: 33.193 ms
select
	*
from (
	select city 
	from airports a) c
cross join (
	select city 
	from airports a) ct
where c.city > ct.city
except 
select distinct
	a.city as city_dep,
	a2.city as city_arr
from flights f
join airports a on a.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport;

--8.3 Черновой вариант
--explain analyze --Execution Time: 82.657 ms
select
	*
from (
	select city 
	from airports a) c
cross join (
	select city 
	from airports a) ct
where c.city > ct.city
except 
select distinct
	city_dep,
	city_arr
from (
	select
		f.flight_id as flight_id_dep,
		f.departure_airport,
		a.city as city_dep
	from flights f 
	join airports a on a.airport_code = f.departure_airport
	) dep
join (
	select
		f.flight_id as flight_id_arr,
		f.arrival_airport,
		a.city as city_arr
	from flights f 
	join airports a on a.airport_code = f.arrival_airport
) arr on dep.flight_id_dep = arr.flight_id_arr
where city_dep > city_arr;
	
--9. Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной 
-- дальностью перелетов  в самолетах, обслуживающих эти рейсы *
-- Оператор RADIANS или использование sind/cosd
-- CASE 

select distinct 
	f.aircraft_code,
	a.airport_name as airport_dep,
	a2.airport_name as airport_arr,
	6371*acos(
	sind(a.latitude)*sind(a2.latitude)+cosd(a.latitude)*cosd(a2.latitude)*cosd(a.longitude-a2.longitude) 
	) as "Расстояние между городами, км",
	a3."range",
	case when a3."range" >
		6371*acos(sind(a.latitude)*sind(a2.latitude)+cosd(a.latitude)*cosd(a2.latitude)*cosd(a.longitude-a2.longitude)) 
		then 'Все в порядке'
		else 'А это уже странно!'
	end as "Сравнение"
from flights f
join airports a on a.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport
join aircrafts a3 on a3.aircraft_code = f.aircraft_code ;

