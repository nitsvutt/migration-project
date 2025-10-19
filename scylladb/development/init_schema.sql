CREATE KEYSPACE IF NOT EXISTS sherlock
WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 1
};

USE sherlock;

CREATE TABLE IF NOT EXISTS users (
  user_id UUID,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  registration_date TIMESTAMP,
  PRIMARY KEY (user_id)
);

CREATE TABLE IF NOT EXISTS products (
  product_id UUID,
  name TEXT,
  description TEXT,
  price DECIMAL,
  created_at TIMESTAMP,
  PRIMARY KEY (product_id)
);

CREATE TABLE IF NOT EXISTS orders (
  order_id UUID,
  user_id UUID,
  product_id UUID,
  order_date TIMESTAMP,
  quantity INT,
  PRIMARY KEY (order_id)
);