create database customers_transactions;
use customers_transactions;
SET SQL_SAFE_UPDATES = 0;
update customers set Gender = null where Gender ='';
update customers set Age = null where Age ='';
alter table Customers modify AGE INT NULL;

select * from customers;

create table transactions
(date_new DATE,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2));

SET sql_mode = '';

SHOW VARIABLES LIKE 'secure_file_priv';

LOAD DATA INFILE "D:/Mysql server/Uploads/transactions_final.csv"
INTO TABLE Transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT * FROM Transactions LIMIT 10;

SET sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

