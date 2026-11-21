"""Extract the four documented integration orders and their related CSV rows."""

import argparse
import csv
from pathlib import Path

ORDER_IDS = {
    '0016dfedd97fc2950e388d2971d718c7', '0008288aa423d2a3f00fcb17cd7d8719',
    '002f98c0f7efd42638ed6100ca699b42', '00143d0f86d6fbd9f9b38ab440ac16f5',
}


def extract(source, output):
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise ValueError(f'Output directory must be empty: {output}')

    def select(filename, predicate):
        with (source / filename).open(encoding='utf-8-sig', newline='') as src:
            reader = csv.DictReader(src, strict=True)
            if not reader.fieldnames:
                raise ValueError(f'Missing header: {filename}')
            rows = [row for row in reader if predicate(row)]
            with (output / filename).open('w', encoding='utf-8', newline='') as dst:
                writer = csv.DictWriter(dst, fieldnames=reader.fieldnames)
                writer.writeheader()
                writer.writerows(rows)
            return rows

    orders = select('olist_orders_dataset.csv', lambda r: r['order_id'] in ORDER_IDS)
    if {r['order_id'] for r in orders} != ORDER_IDS or len(orders) != len(ORDER_IDS):
        raise ValueError('The source does not contain each integration order exactly once')
    items = select('olist_order_items_dataset.csv', lambda r: r['order_id'] in ORDER_IDS)
    for name in ('order_payments', 'order_reviews'):
        select(f'olist_{name}_dataset.csv', lambda r: r['order_id'] in ORDER_IDS)
    customers = {r['customer_id'] for r in orders}
    products = {r['product_id'] for r in items}
    sellers = {r['seller_id'] for r in items}
    select('olist_customers_dataset.csv', lambda r: r['customer_id'] in customers)
    selected_products = select('olist_products_dataset.csv', lambda r: r['product_id'] in products)
    select('olist_sellers_dataset.csv', lambda r: r['seller_id'] in sellers)
    categories = {r['product_category_name'] for r in selected_products}
    select('product_category_name_translation.csv', lambda r: r['product_category_name'] in categories)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    extract(args.source, args.output)
