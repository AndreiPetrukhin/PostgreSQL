--Задание 1. Напишите функцию, которая принимает на вход название должности (например, стажер), а также даты 
--периода поиска, и возвращает количество вакансий, опубликованных по этой должности в заданный период.

CREATE OR REPLACE function vac_number -- для корректировки "create or replace function"
(vac_name text, start_date date, end_date date, out vac_namuber integer) as $$
begin
	IF start_date IS NULL OR end_date IS NULL
		THEN RAISE EXCEPTION 'Одна из дат отсутствует';
	elseif start_date > end_date
		THEN RAISE EXCEPTION 'Дата начала больше чем дата окончания';
	else
		select 
			count(v.pos_id) 
		from vacancy v 
		join "position" p on p.pos_id = v.pos_id
		where vac_name like p.pos_title and 
			(v.create_date between start_date and end_date) into vac_namuber;
	end if;
end;
$$ language plpgsql;

select vac_number ('специалист', '2013-06-20', '2016-01-27'); --15

--Задание 2. Напишите триггер, срабатывающий тогда, когда в таблицу position добавляется значение grade, 
--которого нет в таблице-справочнике grade_salary. Триггер должен возвращать предупреждение пользователю о 
--несуществующем значении grade.

create or replace function insertation() returns trigger as $$
begin
	IF new.grade not in (select grade from grade_salary gs)
		THEN RAISE EXCEPTION 'Предупреждение пользователю о несуществующем значении grade';
	else
		return new;
	end if;
end;
$$ language plpgsql;

--drop trigger add_grade_position on "position";

create trigger add_grade_position
before insert or update of grade on "position"
for each row
execute function insertation();

--Check
insert into "position"(pos_id, pos_title, pos_category, unit_id, grade, address_id, manager_pos_id)
values (100000001, 'new.pos_title', 'new.pos_category', 100, 2, 10, 485);

--DELETE FROM "position" WHERE pos_id = 100000001;


--Задание 3. Создайте таблицу employee_salary_history с полями:
--emp_id - id сотрудника
--salary_old - последнее значение salary (если не найдено, то 0)
--salary_new - новое значение salary
--difference - разница между новым и старым значением salary
--last_update - текущая дата и время
--Напишите триггерную функцию, которая срабатывает при добавлении новой записи о сотруднике или при обновлении 
--значения salary в таблице employee_salary, и заполняет таблицу employee_salary_history данными.
create table employee_salary_history (
	emp_id int4 NOT null,
	salary_old numeric(12, 2) default 0, -- последнее значение salary (если не найдено, то 0)
	salary_new numeric(12, 2), -- новое значение salary
	difference numeric(12, 2), -- разница между новым и старым значением salary
	last_update timestamp default now() --last_update - текущая дата и время
	); 

--drop table employee_salary_history;

create or replace function salary_insert() returns trigger as $$
declare empid int4 = new.emp_id;
	salarynew numeric(12, 2) = new.salary; -- новое значение salary
	salaryold numeric(12, 2) = (select salary from (
		select
			*,
			row_number() over(partition by emp_id order by effective_from desc) as numb 
		from employee_salary es ) fin 
		where numb = 2 and emp_id = new.emp_id);
begin
	IF TG_OP = 'INSERT' and salaryold is not null and new.emp_id in (select emp_id from employee)
		THEN insert into employee_salary_history(emp_id, salary_old, salary_new, difference)
		values (empid, salaryold, salarynew, salarynew - salaryold);
	elseif TG_OP = 'INSERT' and salaryold is null and new.emp_id in (select emp_id from employee)
		THEN insert into employee_salary_history(emp_id, salary_old, salary_new, difference)
		values (empid, 0, salarynew, salarynew);
	elseif TG_OP = 'UPDATE' and new.emp_id in (select emp_id from employee)
		THEN insert into employee_salary_history(emp_id, salary_old, salary_new, difference)
		values (empid, old.salary, salarynew, salarynew - old.salary);
	elseif new.emp_id not in (select emp_id from employee)
		THEN RAISE EXCEPTION 'Сначала добавьте сотрудника в таблицу employee';
	end if;
return new;
end;
$$ language plpgsql;

drop trigger salary_insert on "employee_salary";

create trigger salary_insert
after insert or update of salary on employee_salary --вставка в таблицу и oбновление колонки (можно указать несколько колонок)
for each row execute function salary_insert();

--check
insert into employee_salary (order_id, emp_id, salary, effective_from)
values (29998, 1, 22000, now());

--check
update employee_salary set salary = 17000
where order_id = 25001 and emp_id = 1;

DELETE FROM employee_salary WHERE order_id = 25001;
--DELETE FROM employee_salary_history WHERE emp_id = 1;

select * from employee_salary es 
order by emp_id;

select * from employee_salary_history esh ;

select salary from (
		select
			*,
			row_number() over(partition by emp_id order by effective_from desc) as numb 
		from employee_salary es ) fin 
		where numb = 1 and emp_id = 1;

--Задание 4. Напишите процедуру, которая содержит в себе транзакцию на вставку данных в таблицу employee_salary. 
--Входными параметрами являются поля таблицы employee_salary.

CREATE PROCEDURE my_isert(_order_id int4, _emp_id int4, _salary numeric(12, 2), _effective_from date) AS $$
	BEGIN
		INSERT INTO employee_salary(order_id, emp_id, salary, effective_from)
		VALUES (_order_id, _emp_id, _salary, _effective_from);
	END;
$$ LANGUAGE plpgsql;

select * from employee_salary es order by emp_id;

call my_isert(25001, 1, 12200, '2021-01-01');