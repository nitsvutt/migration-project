USE sherlock;

COPY users (user_id, first_name, last_name, email, registration_date)
FROM '/var/lib/scylla/users.csv' WITH HEADER = TRUE;

COPY products (product_id, name, description, price, created_at)
FROM '/var/lib/scylla/products.csv' WITH HEADER = TRUE;

COPY orders (order_id, user_id, product_id, order_date, quantity)
FROM '/var/lib/scylla/orders.csv' WITH HEADER = TRUE;