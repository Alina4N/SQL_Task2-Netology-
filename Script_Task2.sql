--1. Выведите название самолетов, которые имеют менее 50 посадочных мест

select 
	a.model 
from aircrafts a 
join seats s on a.aircraft_code = s.aircraft_code 
group by a.aircraft_code 
having count(*) < 50

--2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

select 
	date_trunc('month', book_date)::date booking_month,
	sum(total_amount) sum_amount_per_month,
	round((sum(total_amount) - lag(sum(total_amount)) over()) / lag(sum(total_amount)) over() * 100, 2) percentage_change_amount
from bookings b 
group by booking_month
order by booking_month

--3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.

select 
	a.model
from seats s 
join aircrafts a on s.aircraft_code  = a.aircraft_code 
group by a.model
having not 'Business' = any(array_agg(fare_conditions))

--4. Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
--Выведите в результат названия аэропортов и процентное отношение.
--Решение должно быть через оконную функцию.

select 
	a.airport_name airport_departure_name,
	a2.airport_name airport_arrival_name,
	round(count(*) / sum(count(*)) over () * 100,2 ) percentage_ratio
from flights f
join airports a on f.departure_airport = a.airport_code 
join airports a2 on f.arrival_airport = a2.airport_code 
group by a.airport_name, a2.airport_name 
order by a.airport_name, a2.airport_name

--5. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7

select 
	substring(contact_data ->>'phone' from 3 for 3) operator_code,
	count(*)
from tickets t 
group by operator_code
order by operator_code

--6. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
-- До 50 млн - low
-- От 50 млн включительно до 150 млн - middle
-- От 150 млн включительно - high
-- Выведите в результат количество маршрутов в каждом полученном классе

select t.financial_class, count(t.*)
from (select 
	      case 
		      when sum(amount) < 50000000 then 'low'
		      when sum(amount) < 150000000 then 'middle'
		      else 'high'
	      end financial_class
	    from ticket_flights tf 
	    join flights f on tf.flight_id = f.flight_id
	    group by f.departure_airport, f.arrival_airport) t
group by t.financial_class

--7. Вычислите медиану стоимости перелетов, медиану размера бронирования и отношение медианы бронирования к медиане стоимости перелетов, округленной до сотых

select 
	mf.mediana_flights,
	mb.mediana_bookings,
	round((mb.mediana_bookings / mf.mediana_flights)::numeric, 2)
from (
	select 
		percentile_disc(0.5) within group (order by amount) mediana_flights
	from ticket_flights tf 
	) mf
cross join (
	select
		percentile_disc(0.5) within group (order by total_amount) mediana_bookings
	from bookings b 
	) mb
	
--8. Найдите значение минимальной стоимости полета 1 км для пассажиров. 
-- То есть нужно найти расстояние между аэропортами и с учетом стоимости перелетов получить искомый результат
--  Для поиска расстояния между двумя точками на поверхности Земли используется модуль earthdistance.
--  Для работы модуля earthdistance необходимо предварительно установить модуль cube.
--  Установка модулей происходит через команду: create extension название_модуля.

create extension cube
create extension earthdistance

with t1 as (
	select 
		f.departure_airport,
		f.arrival_airport,
		min(tf.amount) min_amount
	from flights f 
	join ticket_flights tf on f.flight_id = tf.flight_id 
	group by f.departure_airport, f.arrival_airport
	),
t2 as (
	select 
		f.departure_airport, 
		f.arrival_airport,
		earth_distance(ll_to_earth(a.latitude, a.longitude), ll_to_earth(a2.latitude, a2.longitude)) / 1000 distance
	from flights f 
	join airports a on f.departure_airport = a.airport_code
	join airports a2 on f.arrival_airport = a2.airport_code 
	)
select 
	round(min(t1.min_amount/ t2.distance)::numeric, 2) min_cost
from t1
join t2 on t1.departure_airport = t2.departure_airport and t1.arrival_airport = t2.arrival_airport