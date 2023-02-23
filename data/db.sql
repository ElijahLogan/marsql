--
-- ** setting up example tables and data **
-- 
-- 

CREATE TABLE task (
  id BIGSERIAL ,
  name TEXT,
  parent_id BIGINT REFERENCES task(id),
  PRIMARY KEY (id)
);


SELECT pg_catalog.setval('task_id_seq', 1, false);

INSERT INTO task VALUES (1, 'task1', NULL);
INSERT INTO task VALUES (2, 'task2', NULL);
INSERT INTO task VALUES (3, 'task3', NULL);
INSERT INTO task VALUES (4, 'task1-1', 1);
INSERT INTO task VALUES (5, 'task1-2', 1);
INSERT INTO task VALUES (6, 'task1-3', 1);
INSERT INTO task VALUES (7, 'task2-1', 2);
INSERT INTO task VALUES (8, 'task2-2', 2);
INSERT INTO task VALUES (9, 'task2-3', 2);
INSERT INTO task VALUES (10, 'task3-1', 3);
INSERT INTO task VALUES (11, 'task3-2', 3);
INSERT INTO task VALUES (12, 'task3-3', 3);
INSERT INTO task VALUES (13, 'task1-3-1', 6);
INSERT INTO task VALUES (14, 'task1-3-1-1', 13);


CREATE TABLE employees (
  employee_id BIGSERIAL,
  last_name TEXT,
  manager_id BIGINT REFERENCES employees(employee_id),
  PRIMARY KEY (employee_id)  
);

SELECT pg_catalog.setval('employees_employee_id_seq', 1, false);

INSERT INTO employees VALUES (100, 'King', NULL);
INSERT INTO employees VALUES (101, 'Kochhar', 100);

INSERT INTO employees VALUES (108, 'Greenberg', 101);
INSERT INTO employees VALUES (200, 'Whalen', 101);
INSERT INTO employees VALUES (203, 'Mavris', 101);
INSERT INTO employees VALUES (204, 'Baer', 101);
INSERT INTO employees VALUES (205, 'Higgins', 101);

INSERT INTO employees VALUES (109, 'Faviet', 108);
INSERT INTO employees VALUES (110, 'Chen', 108);
INSERT INTO employees VALUES (111, 'Sciarra', 108);
INSERT INTO employees VALUES (112, 'Urman', 108);
INSERT INTO employees VALUES (113, 'Popp', 108);
INSERT INTO employees VALUES (206, 'Gietz', 205);


CREATE TABLE empsalary (
  empno BIGSERIAL PRIMARY KEY,
  depname TEXT,
  location TEXT,
  salary DECIMAL
);

INSERT INTO empsalary VALUES (11, 'develop', 'fi', 5200);
INSERT INTO empsalary VALUES (7, 'develop', 'fi', 4200);
INSERT INTO empsalary VALUES (9, 'develop', 'fi', 4500);
INSERT INTO empsalary VALUES (8, 'develop', 'fi', 6000);
INSERT INTO empsalary VALUES (10, 'develop', 'se', 5200);
INSERT INTO empsalary VALUES (5, 'personnel', 'fi', 3500);
INSERT INTO empsalary VALUES (2, 'personnel', 'fi', 3900);
INSERT INTO empsalary VALUES (3, 'sales', 'se', 4800);
INSERT INTO empsalary VALUES (1, 'sales', 'se', 5000);
INSERT INTO empsalary VALUES (4, 'sales', 'se', 4800);
 

CREATE TABLE emp_phone (
  emp_id BIGINT REFERENCES employees(employee_id),
  emp_phone_num VARCHAR(20),
  UNIQUE(emp_id, emp_phone_num)  
);

INSERT INTO emp_phone VALUES (101, '555-123');
INSERT INTO emp_phone VALUES (101, '555-234');
INSERT INTO emp_phone VALUES (101, '555-345');
INSERT INTO emp_phone VALUES (108, '555-111');
INSERT INTO emp_phone VALUES (205, '555-914');
INSERT INTO emp_phone VALUES (205, '555-222');
INSERT INTO emp_phone VALUES (109, '555-987');

CREATE TABLE emp_sm_contact (
  emp_id BIGINT,
  contact_type VARCHAR(20),
  contact TEXT,
  UNIQUE (emp_id, contact_type)
);


INSERT INTO emp_sm_contact VALUES (100, 'twitter', 'beking');
INSERT INTO emp_sm_contact VALUES (100, 'linkedIn', 'b.king');
INSERT INTO emp_sm_contact VALUES (100, 'g+', 'bking');
INSERT INTO emp_sm_contact VALUES (101, 'twitter', 'kochhar');
INSERT INTO emp_sm_contact VALUES (101, 'linkedIn', 'kochhar.1');
INSERT INTO emp_sm_contact VALUES (101, 'g+', 'kochhar.2');
INSERT INTO emp_sm_contact VALUES (200, 'twitter', 'whalen');




--
-- ** example 1 **
-- 
-- hierarchic queries using CTE.
-- 

-- generate task tree and paths using standard CTE.
-- path requires using PostgreSQL arrays.
WITH RECURSIVE task_tree (id, name, parent_id, depth, path) AS (
  SELECT id, name, parent_id, 1, ARRAY[t.id]
    FROM task t WHERE t.id = 1
  UNION ALL
  SELECT s.id, s.name, s.parent_id, tt.depth + 1, path || s.id
    FROM task s, task_tree tt WHERE s.parent_id = tt.id
)
SELECT * FROM task_tree
ORDER BY depth ASC;


--
-- ** example 2 **
-- 
-- hierarchic queries using PostgreSQL tablefunc module.
-- 

-- generate task tree and paths using PostgreSQL tablefunc extension module.
SELECT * FROM connectby('task', 'id', 'parent_id', '1', 0, '/')
 AS t(id BIGINT, parent_id BIGINT, level int, branch text);
 

--
-- ** example **
-- 
-- another example of hierarchic queries using CTE but with employee hierarchy.
-- http://docs.oracle.com/cd/E11882_01/server.112/e26088/statements_10002.htm#BABCDJDB
--

WITH RECURSIVE
  reports_to_101 (eid, emp_last, mgr_id, reportLevel, path) AS
  (
     SELECT employee_id, last_name, manager_id, 0 reportLevel, ARRAY[manager_id]
     FROM employees
     WHERE employee_id = 101
   UNION ALL
     SELECT e.employee_id, e.last_name, e.manager_id, reportLevel+1, path || manager_id
     FROM reports_to_101 r, employees e
     WHERE r.eid = e.manager_id
  )
SELECT eid, emp_last, mgr_id, reportLevel, path
FROM reports_to_101
ORDER BY reportLevel, eid;

--
-- ** example 3 **
-- 
-- Calculating aggregates using window functions.
-- 

SELECT depname, location, empno, salary,
AVG(salary) OVER (PARTITION BY depname) avgdept,
SUM(salary) OVER (PARTITION BY depname) sumdept,
AVG(salary) OVER (PARTITION BY location) avgloc,
RANK() OVER (PARTITION BY depname ORDER BY salary DESC, empno) AS pos
FROM empsalary;


--
-- ** example 4 **
-- 
-- Pivot using subquery + arrays.
-- 

SELECT e.*,
(SELECT ARRAY_TO_STRING(ARRAY(SELECT emp_phone_num FROM emp_phone p WHERE e.employee_id = p.emp_id), ',')) AS phones
 FROM employees AS e
;

--
-- ** example 5 **
-- 
-- Pivot using tablefunc.crosstab.
-- 


SELECT *
FROM crosstab(
  'SELECT emp_id, contact_type, contact FROM emp_sm_contact ORDER BY 1',
  'SELECT DISTINCT contact_type FROM emp_sm_contact ORDER BY 1'
)
AS emp_sm_contact(emp_id BIGINT, "g+" TEXT, "linkedIn" TEXT, twitter TEXT)
;
