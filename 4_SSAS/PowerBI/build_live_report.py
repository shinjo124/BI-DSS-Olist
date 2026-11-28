"""Build a thin Power BI project backed by the Olist SSAS cube."""
import argparse
from pathlib import Path

from build_snapshot_report import write, QUESTIONS, field, mint
from build_warehouse_report import BASE, report_page


def col(table, name, caption=None):
    return (table, name, caption or name, False)


def measure(table, name):
    return (table, name, name, True)


def expression(table, name, alias=None, is_measure=False):
    value = field(table, name)['Column']
    if alias:
        value['Expression']['SourceRef'] = {'Source': alias}
    return {'Measure' if is_measure else 'Column': value}


def filter_item(table, name, kind, sources, condition, is_measure=False):
    return {'name': mint(f'{table}/{name}/{kind}'), 'field': expression(table, name, is_measure=is_measure),
            'type': kind, 'howCreated': 'User',
            'filter': {'Version': 2, 'From': sources, 'Where': [{'Condition': condition}]}}


def entity(alias, table):
    return {'Name': alias, 'Entity': table, 'Type': 0}


def allowed(table, name, numbers):
    return filter_item(table, name, 'Categorical', [entity('d', table)], {
        'In': {'Expressions': [expression(table, name, 'd')],
               'Values': [[{'Literal': {'Value': f'{number}L'}}] for number in numbers]}})


def review_threshold():
    return filter_item('Orders', 'Review Count', 'Advanced', [entity('r', 'Orders')], {
        'Comparison': {'ComparisonKind': 2, 'Left': expression('Orders','Review Count','r',True),
                       'Right': {'Literal': {'Value': '100L'}}}}, is_measure=True)


def ranking(table, column, by_table, by_measure, count, bottom=False, minimum_reviews=False):
    group = expression(table, column, 'd')
    query = {'Version': 2, 'From': [entity('d', table), entity('m', by_table)],
             'Select': [{**group, 'Name': 'field'}],
             'OrderBy': [{'Direction': 1 if bottom else 2,
                          'Expression': expression(by_table, by_measure, 'm', True)}], 'Top': count}
    if minimum_reviews:
        review = review_threshold()['filter']
        query['From'] += review['From']
        query['Where'] = review['Where']
    return filter_item(table, column, 'TopN',
                       [{'Name': 'subquery', 'Expression': {'Subquery': {'Query': query}}, 'Type': 2},
                        entity('d', table)],
                       {'In': {'Expressions': [group], 'Table': {'SourceRef': {'Source': 'subquery'}}}})


def live_pages():
    sales = lambda name: measure('Sales', name)
    orders = lambda name: measure('Orders', name)
    payments = lambda name: measure('Payments', name)
    calc = lambda name: measure('Measures', name)
    return [
        ([col('Date','Year'),col('Date','Quarter','Year-quarter code')], [sales('Revenue'),orders('Order Count')],
         ('Year-quarter code','Ascending'), []),
        ([col('Product','Category')], [sales('Revenue'),sales('Quantity')], ('Revenue','Descending'),
         [ranking('Product','Category','Sales','Revenue',10)]),
        ([col('Customer','State')], [sales('Revenue'),orders('Order Count'),calc('Avg Order Value')], ('Revenue','Descending'),
         [ranking('Customer','State','Sales','Revenue',5)]),
        ([col('Payment','Payment','Payment method')], [payments('Payment Amount'),calc('Payment Share')],
         ('Payment Amount','Descending'), []),
        ([col('Date',('Calendar','Month'),'Month')], [sales('Revenue'),calc('MoM Growth')], ('Month','Ascending'),
         [allowed('Date','Year',[2017])]),
        ([col('Product','Category')], [calc('Avg Review'),orders('Review Count'),orders('Order Count')], ('Avg Review','Ascending'),
         [ranking('Product','Category','Measures','Avg Review',10,bottom=True,minimum_reviews=True),review_threshold()]),
        ([col('Customer','State')], [calc('Avg Delivery Days'),calc('Late Rate'),orders('Delivered Count'),
                                    orders('Late Eligible Count')], ('State','Ascending'), []),
        ([col('Seller','Seller','Seller ID'),col('Seller','State')], [sales('Revenue'),orders('Order Count'),calc('Avg Review')],
         ('Revenue','Descending'), [ranking('Seller','Seller','Sales','Revenue',10)]),
        ([col('Date','Year'),col('Customer','Region')], [sales('Revenue'),sales('Freight Value'),calc('Freight Ratio')],
         ('Year','Ascending'), [allowed('Date','Year',[2017,2018]),allowed('Date','Month Number',range(1,9))]),
        ([col('Date','Weekday'),col('Payment','Payment','Payment method')], [payments('Payment Amount')],
         ('Weekday','Ascending'), []),
    ]


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--server', default=r'localhost\SSAS2022')
    cli.add_argument('--catalog', default='OlistBI')
    args = cli.parse_args()
    name = 'Olist Live'
    report, model = Path(f'{name}.Report'), Path(f'{name}.SemanticModel')
    write(Path(f'{name}.pbip'), 'pbip/pbipProperties/1.0.0', version='1.0',
          artifacts=[{'report': {'path': str(report)}}])
    write(report/'definition.pbir', 'item/report/definitionProperties/2.0.0', version='4.0',
          datasetReference={'byPath': {'path': f'../{model}'}})
    write(model/'definition.pbism', 'item/semanticModel/definitionProperties/1.0.0', version='4.2', settings={})
    write(model/'modelReference.json', 'item/semanticModel/modelReference/2.0.0',
          connectionString=f'Data Source={args.server};Initial Catalog={args.catalog};Cube=Olist',
          connectionType='analysisServicesDatabaseLive', isMultiDimentional=True)
    folder = report/'definition'
    write(folder/'version.json', BASE+'versionMetadata/1.0.0',version='2.0.0')
    write(folder/'report.json', BASE+'report/3.0.0',themeCollection={
        'baseTheme': {'name':'CY24SU02','type':'SharedResources',
                      'reportVersionAtImport':{'visual':'2.1.0','page':'2.0.0','report':'3.0.0'}}})
    pages = []
    for n, ((title, _, note), (groups, metrics, sort, filters)) in enumerate(zip(QUESTIONS,live_pages()),1):
        if n == 1:
            note += ' Quarter codes use YYYYQ, for example 20171 for 2017 Q1.'
        if n == 4:
            note = 'Live payment amounts from the Olist SSAS cube.'
        pages.append(report_page(folder,n,f'Q{n:02} {title}',note,groups,metrics,sort,filters))
    write(folder/'pages/pages.json',BASE+'pagesMetadata/1.0.0',pageOrder=pages,activePageName=pages[0])


if __name__ == '__main__':
    main()
