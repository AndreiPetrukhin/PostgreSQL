--Задание 1. Работа с командной строкой
--Пункты 1.1 и 1.2 выполняются в командной строке, пункты 1.3 и 1.4 выполняются в интерактивном режиме.
--1.1. Создайте новую базу данных с любым названием
export PATH=/Library/PostgreSQL/12/bin:$PATH
psql -h localhost -p 5432 -U postgres -c "create database apetrukh"

--1.2. Восстановите бэкап учебной базы данных в новую базу данных с помощью psql
psql -h localhost -p 5432 -U postgres -d apetrukh < "/Users/apetrukh/SQL study/hr.sql"

--1.3. Выведите список всех таблиц восстановленной базы данных
apetrukh=# \dt hr.

--1.4. Выполните SQL-запрос на выборку всех полей из любой таблицы восстановленной базы данных
apetrukh=# set search_path to hr;
apetrukh=# select * from address;

--Задание 2. Работа с пользователями. Задание выполняется в DBeaver
--2.1. Создайте нового пользователя MyUser, которому разрешен вход, но не задан пароль и права доступа.
create role MyUser with login;

--2.2. Задайте пользователю MyUser любой пароль сроком действия до последнего дня текущего месяца.
alter role MyUser with login password '1111' valid until '2022-08-01';

--2.3. Дайте пользователю MyUser права на чтение данных из двух любых таблиц восстановленной базы данных.
grant select on "city", "address" to MyUser;

--2.4. Заберите право на чтение данных ранее выданных таблиц
revoke select on "city", "address" from MyUser;

--2.5. Удалите пользователя MyUser.
drop role if exists MyUser;

--Задание 3. Работа с транзакциями. Задание выполняется в DBeaver
--3.1. Начните транзакцию
begin;

--3.2. Добавьте в таблицу projects новую запись
insert into projects (project_id, name, employees_id, amount, assigned_id, created_at) 
values (129, 'Нетология', '{1,2,3}', 30000, 1, '2022-07-03');

--3.3. Создайте точку сохранения
SAVEPOINT my_savepoint;

--3.4. Удалите строку, добавленную в п.3.2
delete from projects where project_id = 129;

--3.5. Откатитесь к точке сохранения
ROLLBACK TO my_savepoint;

--3.6. Завершите транзакцию.
COMMIT;

--Проверка Задания 3
select * from projects p 
where project_id = 129;
