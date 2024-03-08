
CREATE USER IF NOT EXISTS 'niojet_user'@'localhost' IDENTIFIED WITH mysql_native_password BY 'niojet_pw';

CREATE DATABASE IF NOT EXISTS niojet_demo CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, DROP, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES ON niojet_demo.* TO 'niojet_user'@'localhost';

USE niojet_demo;

CREATE TABLE IF NOT EXISTS quotes (
  id INT AUTO_INCREMENT,
  text TEXT NOT NULL,
  author VARCHAR(255),
  displayOptions JSON DEFAULT NULL,
  price DECIMAL(20,2) DEFAULT NULL,
  createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

INSERT IGNORE INTO quotes (id, text, author, display_options, price)
VALUES
	(1, 'Experience is the name everyone gives to their mistakes.', 'Oscar Wilde', '{\"centered\": true}', NULL),
	(2, 'Sometimes it pays to stay in bed on Monday, rather than spending the rest of the week debugging Monday’s code.', 'Dan Salomon', NULL, 14.99),
	(3, 'Run, rabbit, run\nDig that hole, forget the sun\nWhen, at last, the work is done\nDon\'t sit down, it\'s time to dig another one', 'Pink Floyd', NULL, 59.99);
