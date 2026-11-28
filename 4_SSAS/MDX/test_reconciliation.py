"""Compare actual MDX CSV exports with fresh independent SQL references."""
import csv
from pathlib import Path
import unittest

import pyodbc

ROOT = Path(__file__).resolve().parents[2]


def sql_results(connection, filename):
    cursor = connection.cursor()
    cursor.execute((ROOT / '3_SSIS/sql' / filename).read_text(encoding='utf-8'))
    results = []
    while True:
        if cursor.description:
            columns = [col[0] for col in cursor.description]
            results.append([dict(zip(columns, row)) for row in cursor.fetchall()])
        if not cursor.nextset():
            break
    return results


class CubeReconciliation(unittest.TestCase):
    def test_all_ten_questions_match_independent_sql(self):
        with pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;'
                            'DATABASE=OlistDW_Test;Trusted_Connection=yes;') as connection:
            first = sql_results(connection, 'reference_questions_01_05.sql')
            middle = sql_results(connection, 'reference_questions_06_08.sql')
            last = sql_results(connection, 'reference_questions_07_09_10.sql')
        specs = [
            (1, first[0], lambda r: (str(r['Year']) + (str(r['Quarter']) if r['Quarter'] else ''),),
             ['Member0'], {'Revenue': 'Revenue', 'Order Count': 'OrderCount'}),
            (2, first[1], lambda r: (r['CategoryEnglish'],), ['Member0'],
             {'Revenue': 'Revenue', 'Quantity': 'Quantity'}),
            (3, first[2], lambda r: (r['State'],), ['Member0'],
             {'Revenue': 'Revenue', 'Order Count': 'OrderCount', 'Avg Order Value': 'AvgOrderValue'}),
            (4, first[3], lambda r: (r['PaymentType'],), ['Member0'],
             {'Payment Amount': 'PaymentAmount', 'Payment Share': 'PaymentShare'}),
            (5, first[4], lambda r: (str(r['MonthStart'])[:7],), ['Member0'],
             {'Revenue': 'Revenue', 'MoM Growth': 'MoMGrowth'}),
            (6, middle[0], lambda r: (r['CategoryEnglish'],), ['Member0'],
             {'Avg Review': 'AvgReview', 'Review Count': 'ReviewCount', 'Order Count': 'OrderCount'}),
            (7, last[0], lambda r: (r['State'],), ['Member0'],
             {'Avg Delivery Days': 'AvgDeliveryDays', 'Late Rate': 'LateRate',
              'Delivered Count': 'DeliveredCount', 'Late Eligible Count': 'LateEligibleCount'}),
            (8, middle[1], lambda r: (r['SellerID'], r['State']), ['Member0', 'Member1'],
             {'Revenue': 'Revenue', 'Order Count': 'OrderCount', 'Avg Review': 'AvgReview'}),
            (9, last[1], lambda r: (str(r['Year']), r['Region']), ['Member0', 'Member1'],
             {'Revenue': 'Revenue', 'Freight Value': 'Freight', 'Freight Ratio': 'FreightRatio'}),
            (10, last[2], lambda r: (r['ISOWeekdayName'], r['PaymentType']), ['Member0', 'Member1'],
             {'Payment Amount': 'PaymentAmount'}),
        ]
        for number, expected, key, members, measures in specs:
            with self.subTest(question=number):
                with (Path(__file__).parent / 'results' / f'Q{number:02}.csv').open(encoding='utf-8-sig') as file:
                    actual = list(csv.DictReader(file))
                indexed = {tuple(row[col] for col in members): row for row in actual}
                self.assertEqual(len(actual), len(indexed), 'Duplicate MDX groups')
                self.assertEqual(set(indexed), {key(row) for row in expected})
                for row in expected:
                    for mdx_name, sql_name in measures.items():
                        value = indexed[key(row)][mdx_name]
                        if row[sql_name] is None:
                            self.assertEqual(value, '')
                        else:
                            self.assertAlmostEqual(float(value), float(row[sql_name]), delta=0.000001,
                                                   msg=f'Q{number} {key(row)} {mdx_name}')


if __name__ == '__main__':
    unittest.main()
