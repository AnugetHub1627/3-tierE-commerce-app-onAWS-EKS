CREATE DATABASE IF NOT EXISTS ecommerce;
USE ecommerce;

CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL
);

INSERT INTO products (name, price, stock) VALUES 
('Wireless Mouse', 29.99, 15),
('Mechanical Keyboard', 89.99, 5),
('Gaming Monitor', 249.99, 2);

