"""Import the Olist CSV snapshot into SQL Server staging in one transaction."""

import argparse
import csv
from pathlib import Path

import pyodbc


TABLES = [
    ('Orders', 'olist_orders_dataset.csv', 'order_id customer_id order_status order_purchase_timestamp order_approved_at order_delivered_carrier_date order_delivered_customer_date order_estimated_delivery_date'),
    ('Customers', 'olist_customers_dataset.csv', 'customer_id customer_unique_id customer_zip_code_prefix customer_city customer_state'),
    ('Products', 'olist_products_dataset.csv', 'product_id product_category_name product_weight_g'),
    ('CategoryTranslation', 'product_category_name_translation.csv', 'product_category_name product_category_name_english'),
    ('Sellers', 'olist_sellers_dataset.csv', 'seller_id seller_zip_code_prefix seller_city seller_state'),
    ('OrderItems', 'olist_order_items_dataset.csv', 'order_id order_item_id product_id seller_id shipping_limit_date price freight_value'),
    ('Payments', 'olist_order_payments_dataset.csv', 'order_id payment_sequential payment_type payment_installments payment_value'),
    ('Reviews', 'olist_order_reviews_dataset.csv', 'review_id order_id review_score review_creation_date review_answer_timestamp'),
]


def read_rows(path, columns):
    with path.open(encoding='utf-8-sig', newline='') as source:
        reader = csv.DictReader(source, strict=True)
        try:
            if not reader.fieldnames or not set(columns).issubset(reader.fieldnames):
                raise ValueError(f'{path}: required CSV columns are missing')
            for row in reader:
                if None in row or any(value is None for value in row.values()):
                    raise ValueError(f'{path}: incorrect CSV field count near line {reader.line_num}')
                yield tuple(row[column] if row[column] != '' else None for column in columns)
        except csv.Error as exc:
            raise ValueError(f'{path}: invalid CSV near line {reader.reader.line_num}: {exc}') from exc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, required=True)
    parser.add_argument('--server', required=True)
    parser.add_argument('--database', required=True)
    parser.add_argument('--driver', default='ODBC Driver 17 for SQL Server')
    args = parser.parse_args()
    for _, filename, columns in TABLES:
        with (args.data / filename).open(encoding='utf-8-sig', newline='') as source:
            header = next(csv.reader(source), [])
        if not set(columns.split()).issubset(header):
            raise ValueError(f'{filename}: required CSV columns are missing')
    connection = pyodbc.connect(f'DRIVER={{{args.driver}}};SERVER={{{args.server}}};DATABASE={{{args.database}}};Trusted_Connection=yes;TrustServerCertificate=yes', autocommit=False)
    try:
        cursor = connection.cursor()
        cursor.fast_executemany = True
        for table, filename, column_string in TABLES:
            columns = column_string.split()
            cursor.execute(f'DELETE FROM stg.[{table}]')
            sql = f"INSERT INTO stg.[{table}] ({','.join('[' + c + ']' for c in columns)}) VALUES ({','.join('?' for _ in columns)})"
            batch = []
            count = 0
            for row in read_rows(args.data / filename, columns):
                batch.append(row)
                if len(batch) == 1000:
                    cursor.executemany(sql, batch)
                    count += len(batch)
                    batch.clear()
            if batch:
                cursor.executemany(sql, batch)
                count += len(batch)
            print(f'{table}: {count} rows', flush=True)
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


if __name__ == '__main__':
    main()
