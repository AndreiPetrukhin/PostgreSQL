--Необходимо нормализовать исходную таблицу.
--Получившиеся отношения должны быть не ниже 3 Нормальной Формы.
--В результате должна быть диаграмма из не менее чем 5 нормализованных отношений и 1 таблицы с историчностью, 
--соответствующей требованиям SCD4.
--Контролировать целостность данных в таблице с историчными данными необходимо с помощью триггерной функции.
--Результат работы должен быть в виде одного скриншота ER-диаграммы и sql запроса с триггером и функцией.

--drop table employee_salary_history;
create table employee_salary_history (
	emp_id int4 NOT null,
	salary_old numeric(12, 2) default 0, -- последнее значение salary (если не найдено, то 0)
	salary_new numeric(12, 2), -- новое значение salary
	difference numeric(12, 2), -- разница между новым и старым значением salary
	last_update timestamp default now() --last_update - текущая дата и время
	);

-- company.employee_salary_history foreign keys
ALTER TABLE company.employee_salary_history ADD CONSTRAINT employee_salary_history_emp_id_fkey FOREIGN KEY (emp_id) REFERENCES employee(emp_id);

create or replace function salary_insert() returns trigger as $$
declare empid int4 = new.emp_id;
	salarynew numeric(12, 2) = new.salary; -- новое значение salary
	salaryold numeric(12, 2) = (select salary from employee_salary es 
								where es.emp_id = new.emp_id and es.order_id <> new.order_id
								order by es.emp_id, es.effective_date desc
								limit 1);
begin
	IF TG_OP = 'INSERT' and salaryold is not null and new.emp_id in (select emp_id from employee)
		THEN insert into employee_salary_history(emp_id, salary_old, salary_new, difference)
		values (empid, salaryold, salarynew, salarynew - salaryold);
		delete from employee_salary where emp_id = new.emp_id;
	elseif TG_OP = 'INSERT' and salaryold is null and new.emp_id in (select emp_id from employee)
		THEN insert into employee_salary_history(emp_id, salary_old, salary_new, difference)
		values (empid, 0, salarynew, salarynew);
	elseif TG_OP = 'UPDATE' and new.emp_id in (select emp_id from employee)
		THEN insert into employee_salary_history(emp_id, salary_old, salary_new, difference)
		values (empid, old.salary, salarynew, salarynew - old.salary);
		delete from employee_salary where emp_id = new.emp_id;
	elseif new.emp_id not in (select emp_id from employee)
		THEN RAISE EXCEPTION 'Сначала добавьте сотрудника в таблицу employee';
	end if;
return new;
end;
$$ language plpgsql;

--drop trigger salary_insert on "employee_salary";
create trigger salary_insert
after insert or update of salary on employee_salary --вставка в таблицу и oбновление колонки (можно указать несколько колонок)
for each row execute function salary_insert();


-- DB creation script
-- company.address_home definition
-- DROP TABLE address_home;
CREATE TABLE address_home (
	address_id int4 NOT NULL,
	city varchar(50) NOT NULL,
	street varchar(100) NOT NULL,
	building_No varchar(10) NOT null,
	CONSTRAINT address_pkey PRIMARY KEY (address_id)
);

-- company.person definition
-- DROP TABLE person;
CREATE TABLE person (
	person_id int4 NOT NULL,
	first_name varchar(250) NOT NULL,
	last_name varchar(250) NOT NULL,
	dob date NULL,
	address_id int4 null,
	CONSTRAINT person_pkey PRIMARY KEY (person_id)
);

-- company.person foreign keys
ALTER TABLE company.person ADD CONSTRAINT person_address_id_fkey FOREIGN KEY (address_id) REFERENCES address_home(address_id);


-- company.address_dep definition
DROP TABLE address_dep;
CREATE TABLE address_dep (
	address_id int4 NOT NULL,
	city varchar(50) NOT NULL,
	street varchar(100) NOT NULL,
	building_No varchar(10) NOT null,
	CONSTRAINT address_dep_pkey PRIMARY KEY (address_id)
);

-- company.department definition
--DROP TABLE department;
CREATE TABLE department (
	dep_id int4 NOT NULL,
	title varchar(100) NOT NULL,
	CONSTRAINT department_pkey PRIMARY KEY (dep_id)
);

-- company.department foreign keys
ALTER TABLE company.department ADD CONSTRAINT department_address_id_fkey FOREIGN KEY (address_id) REFERENCES address_dep(address_id);
--ALTER TABLE company.department drop CONSTRAINT if exists department_address_id_fkey;

-- company.position definition
-- DROP TABLE position;
CREATE TABLE position (
	position_id int4 NOT NULL,
	title varchar(100) NULL,
	dep_id int4 NULL,
	address_id int4 null,
	CONSTRAINT position_pkey PRIMARY KEY (position_id)
);

-- company.position foreign keys
ALTER TABLE company.position ADD CONSTRAINT position_dep_id_fkey FOREIGN KEY (dep_id) REFERENCES department(dep_id);
ALTER TABLE company.position ADD CONSTRAINT position_address_id_fkey FOREIGN KEY (address_id) REFERENCES address_dep(address_id);
--ALTER TABLE company.position drop CONSTRAINT if exists position_dep_id_fkey;

-- company.employee definition
--DROP TABLE employee;
CREATE TABLE employee (
	emp_id int4 NOT NULL,
	person_id int4 NOT NULL,
	position_id int4 NOT NULL,
	email varchar(100) NULL,
	manager_person_id int4 null,
	CONSTRAINT employee_pkey PRIMARY KEY (emp_id)
);

-- company.employee foreign keys
ALTER TABLE company.employee ADD CONSTRAINT employee_position_id_fkey FOREIGN KEY (position_id) REFERENCES position(position_id);
ALTER TABLE company.employee ADD CONSTRAINT employee_person_id_fkey FOREIGN KEY (person_id) REFERENCES person(person_id);
ALTER TABLE company.employee ADD CONSTRAINT employee_manager_person_id_fkey FOREIGN KEY (manager_person_id) REFERENCES person(person_id);

-- company.duration definition
--DROP TABLE duration;
CREATE TABLE duration (
	emp_id int4 NOT NULL,
	position_id int4 NOT NULL,
	hire_date date null,
	leave_date date null,
	CONSTRAINT duration_pkey PRIMARY KEY (emp_id, position_id)
);

-- company.duration foreign keys
ALTER TABLE company.duration ADD CONSTRAINT duration_position_id_fkey FOREIGN KEY (position_id) REFERENCES position(position_id);
ALTER TABLE company.duration ADD CONSTRAINT duration_emp_id_fkey FOREIGN KEY (emp_id) REFERENCES employee(emp_id);

-- company.employee_salary definition
-- DROP TABLE employee_salary;
CREATE TABLE employee_salary (
	order_id int4 NOT NULL,
	emp_id int4 NOT NULL,
	salary numeric(12, 2) NOT NULL,
	effective_date date not null,
	CONSTRAINT employee_salary_pkey PRIMARY KEY (order_id)
);

-- company.employee_salary foreign keys
ALTER TABLE company.employee_salary ADD CONSTRAINT employee_salary_emp_id_fkey FOREIGN KEY (emp_id) REFERENCES employee(emp_id);

--Data insertation
--address_home
insert into address_home (address_id, city, street, building_no)
values 
(1, 'Bradford', 'Shaw Land Lake HollyGL1', '72'),
(2, 'Birmingham', 'Row West Tonytown BT60', '8'),
(3, 'Birmingham', 'Davies Points New LU7', '91'),
(4, 'Bradford', 'Wood Isle Port BS4', '40'),
(5, 'Swansea', 'Way Lake M46', 'Studio 12'),
(6, 'Birmingham', 'Knight Corn East HU14', '63');

--address_dep
insert into address_dep (address_id, city, street, building_no)
values 
(1, 'Birmingham', 'Bailey Center RM12', '625'),
(2, 'Bradford', 'Meadow Freyaview W1D', '113'),
(3, 'Swansea', 'Harbours New Sally BR6', '557');

--person
insert into person (person_id, first_name, last_name, dob, address_id)
values 
(1, 'Linda', 'Smith', '1989-07-07', 6),
(2, 'Oscar', 'Fowler', '1988-11-01', 2),
(3, 'Everett', 'Garcia', '1981-05-22', 3), --manager
(4, 'Mary', 'Roberts', '1975-07-15', 1),
(5, 'John', 'Obrien', '1978-03-31', 5),
(6, 'Sharon', 'Hunter', null, null), --manager
(7, 'David', 'Morgan', null, null), --manager
(8, 'William', 'Lewis', null, null), --manager
(9, 'Leon', 'Mitchell', null, null), --manager
(10, 'Charles', 'Johnson', null, null); --manager

--department
insert into department (dep_id, title)
values 
(1, 'Project Office'),
(2, 'Software Development'),
(3, 'IT Help Desk'),
(4, 'Design'),
(5, 'Maintenance and Administration');

 --position
insert into position (position_id, title, dep_id, address_id)
values 
(1, 'Project Manager', 1, 1),
(2, 'Analyst', 2, 1),
(3, 'Computer Programmer', 3, 1),
(4, 'Project Office Team Leader', 5, 2),
(5, 'Graphic Designer', 4, 2),
(6, 'Web Designer', 5, 2),
(7, 'Web Application Developer', 2, 3);

--employees
insert into employee (emp_id, person_id, position_id, email, manager_person_id)
values
(1, 1, 6, 'LindaSmith@default.com', 3),
(2, 3, 4, 'EverettGarcia@default.com', 8),
(3, 5, 7, 'JohnObrien@default.com', 10),
(4, 4, 6, 'MaryRoberts@default.com', 6);

--duration
insert into duration (emp_id, position_id, hire_date, leave_date)
values
(4, 5, '2017-08-20', '2020-12-31'),
(4, 6, '2021-01-01', null);

--employee_salary
insert into employee_salary (order_id, emp_id, salary, effective_date)
values
(4, 2, 20000, '2019-01-13');
--delete from employee_salary_history where emp_id = 3;


update employee_salary
set salary = 18900
where emp_id = 2;

--check salary history
select * from employee_salary_history esh ;

select * from employee_salary es;

select * from duration d ;

