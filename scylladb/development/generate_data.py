import os
import csv
import uuid
from faker import Faker

COMMON_PATH = os.getenv('COMMON_PATH')

def generate_csv(filename, num_rows, headers, data_func):
    """
    Generates a CSV file with mock data.
    """
    with open(filename, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        for _ in range(num_rows):
            writer.writerow(data_func())

def main():
    fake = Faker()
    num_rows = 100000
    
    user_headers = ['user_id', 'first_name', 'last_name', 'email', 'registration_date']
    user_data_func = lambda: [str(uuid.uuid4()), fake.first_name(), fake.last_name(), fake.email(), fake.date_time_this_decade()]
    generate_csv(f'{COMMON_PATH}/k8s/scylladb/data1/users.csv', num_rows, user_headers, user_data_func)
    print(f"Generated {num_rows} rows in users.csv")

    product_headers = ['product_id', 'name', 'description', 'price', 'created_at']
    product_data_func = lambda: [str(uuid.uuid4()), fake.word().capitalize(), fake.text(max_nb_chars=50), fake.pydecimal(left_digits=3, right_digits=2, positive=True), fake.date_time_this_decade()]
    generate_csv(f'{COMMON_PATH}/k8s/scylladb/data1/products.csv', num_rows, product_headers, product_data_func)
    print(f"Generated {num_rows} rows in products.csv")

    order_headers = ['order_id', 'user_id', 'product_id', 'order_date', 'quantity']
    order_data_func = lambda: [str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4()), fake.date_time_this_year(), fake.random_int(min=1, max=10)]
    generate_csv(f'{COMMON_PATH}/k8s/scylladb/data1/orders.csv', num_rows, order_headers, order_data_func)
    print(f"Generated {num_rows} rows in orders.csv")

if __name__ == "__main__":
    main()