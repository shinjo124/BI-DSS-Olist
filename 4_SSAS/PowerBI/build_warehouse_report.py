"""Build an editable Power BI model from the checked SQL warehouse tables."""
import argparse
import base64
from datetime import date, datetime
from decimal import Decimal
import json
from pathlib import Path
from uuid import uuid5, NAMESPACE_URL
import zlib

import pyodbc

from build_snapshot_report import HERE, QUESTIONS, field, literal, mint, write

NAME = 'Olist Warehouse'
BASE = 'item/report/definition/'
FACTS = {
    'FactSales': ['Date', 'Customer', 'Order', 'Product', 'Seller'],
    'FactOrder': ['Date', 'Customer', 'Order'],
    'FactPayment': ['Date', 'Customer', 'Order', 'Payment'],
}
DIMS = ['Dim' + name for name in ('Date', 'Customer', 'Order', 'Product', 'Seller', 'Payment')]
PROJECTIONS = {
    'DimCustomer': 'CustomerKey, City, State, Region',
    'DimProduct': 'ProductKey, CategoryOriginal, CategoryEnglish, TranslationMissing, WeightG',
    'FactOrder': ('OrderKey, DateKey, CustomerKey, ReviewScore, ReviewPresent, DeliveryDays, '
                  'DeliveredFlag, LateFlag, LateEligibleFlag'),
}

BASE_MEASURES = {
    'FactSales': {
        'Revenue': 'SUM(FactSales[Price])',
        'Item Quantity': 'SUM(FactSales[Quantity])',
        'Sales Orders': 'DISTINCTCOUNT(FactSales[OrderKey])',
        'Avg Order Value': 'DIVIDE(CONVERT([Revenue], DOUBLE), [Sales Orders])',
        'Freight Value': 'SUM(FactSales[FreightValue])',
    },
    'FactOrder': {
        'Order Count': 'COUNTROWS(FactOrder)',
        'Order Review Count': 'COUNT(FactOrder[ReviewScore])',
        'Order Avg Review': 'AVERAGE(FactOrder[ReviewScore])',
        'Matching Orders': 'CALCULATE([Order Count], TREATAS(VALUES(FactSales[OrderKey]), FactOrder[OrderKey]))',
        'Matching Reviews': 'CALCULATE([Order Review Count], TREATAS(VALUES(FactSales[OrderKey]), FactOrder[OrderKey]))',
        'Matching Avg Review': 'CALCULATE([Order Avg Review], TREATAS(VALUES(FactSales[OrderKey]), FactOrder[OrderKey]))',
        'Delivered Count': 'SUM(FactOrder[DeliveredFlag])',
        'Late Eligible Count': 'SUM(FactOrder[LateEligibleFlag])',
        'Avg Delivery Days': 'DIVIDE(SUM(FactOrder[DeliveryDays]), [Delivered Count])',
        'Late Rate': 'DIVIDE(SUM(FactOrder[LateFlag]), [Late Eligible Count])',
    },
    'FactPayment': {
        'Payment Amount': 'SUM(FactPayment[PaymentValue])',
        'Payment Share': 'DIVIDE(CONVERT([Payment Amount], DOUBLE), CALCULATE([Payment Amount], REMOVEFILTERS(DimPayment)))',
    },
}

PAGES = [
    ([('DimDate','Year'), ('DimDate','Quarter')], 'FactSales', ['Revenue', 'Sales Orders'], None),
    ([('DimProduct','CategoryEnglish')], 'FactSales', ['Revenue', 'Item Quantity'], 'Revenue'),
    ([('DimCustomer','State')], 'FactSales', ['Revenue', 'Sales Orders', 'Avg Order Value'], 'Revenue'),
    ([('DimPayment','PaymentType')], 'FactPayment', ['Payment Amount', 'Payment Share'], 'Payment Amount'),
    ([('DimDate','MonthLabel')], 'FactSales', ['Revenue', 'MoM Growth'], None),
    ([('DimProduct','CategoryEnglish')], 'FactOrder', ['Matching Avg Review', 'Matching Reviews', 'Matching Orders'], 'Matching Avg Review'),
    ([('DimCustomer','State')], 'FactOrder', ['Avg Delivery Days', 'Late Rate', 'Delivered Count', 'Late Eligible Count'], None),
    ([('DimSeller','SellerID'), ('DimSeller','State')], 'FactSales', ['Revenue', 'Matching Orders', 'Matching Avg Review'], 'Revenue'),
    ([('DimDate','Year'), ('DimCustomer','Region')], 'FactSales', ['Revenue', 'Freight Value', 'Freight Ratio'], None),
    ([('DimDate','ISOWeekdayName'), ('DimPayment','PaymentType')], 'FactPayment', ['Payment Amount'], None),
]
LABELS = {'MonthLabel': 'Month', 'CategoryEnglish': 'Category', 'PaymentType': 'Payment method',
          'ISOWeekdayName': 'Weekday', 'Sales Orders': 'Order Count', 'Matching Orders': 'Order Count',
          'Matching Reviews': 'Review Count', 'Matching Avg Review': 'Avg Review', 'Item Quantity': 'Quantity'}
RANK_FILTERS = {
    3: 'RANKX(ALLSELECTED(DimCustomer[State]), [Revenue], , DESC) <= 5',
    6: '[Matching Reviews] >= 100 && RANKX(FILTER(ALLSELECTED(DimProduct[CategoryEnglish]), [Matching Reviews] >= 100), [Matching Avg Review], , ASC) <= 10',
    8: 'RANKX(ALLSELECTED(DimSeller), [Revenue], [Revenue], DESC) <= 10',
}
CHARTS = {
    1: ('clusteredColumnChart', 0, 0, None, 'Revenue by year'),
    2: ('clusteredBarChart', 0, 0, None, 'Revenue by product category'),
    3: ('clusteredBarChart', 0, 0, None, 'Revenue by customer state'),
    4: ('donutChart', 0, 0, None, 'Payment amount by method'),
    5: ('lineChart', 0, 0, None, 'Monthly revenue in 2017'),
    6: ('clusteredBarChart', 0, 0, None, 'Average review by category'),
    7: ('clusteredBarChart', 0, 1, None, 'Late delivery rate by state'),
    8: ('clusteredBarChart', 0, 0, None, 'Revenue by seller'),
    9: ('clusteredColumnChart', 1, 2, 0, 'Freight ratio by region and year'),
    10: ('columnChart', 0, 0, 1, 'Payment amount by weekday and method'),
}


def question_measure(number, metric):
    if number == 2:
        return ('VAR TopCategories = TOPN(10, ALLSELECTED(DimProduct[CategoryEnglish]), '
                '[Revenue], DESC, DimProduct[CategoryEnglish], ASC) '
                f'RETURN CALCULATE([{metric}], KEEPFILTERS(TopCategories))')
    if number in RANK_FILTERS:
        return f'IF({RANK_FILTERS[number]}, [{metric}])'
    if number == 5:
        if metric == 'Revenue':
            return 'IF(SELECTEDVALUE(DimDate[Year]) = 2017, [Revenue])'
        return ('VAR Period = SELECTEDVALUE(DimDate[YearMonth]) '
                'VAR Prior = IF(MOD(Period,100)=1, Period-89, Period-1) '
                'VAR PreviousRevenue = CALCULATE([Revenue], REMOVEFILTERS(DimDate), DimDate[YearMonth]=Prior) '
                'RETURN IF(SELECTEDVALUE(DimDate[Year])=2017, DIVIDE(CONVERT([Revenue]-PreviousRevenue, DOUBLE), PreviousRevenue))')
    if number == 9:
        if metric == 'Freight Ratio':
            return 'DIVIDE(CONVERT([Q09 Freight Value], DOUBLE), [Q09 Revenue])'
        return f'CALCULATE([{metric}], KEEPFILTERS(DimDate[Year] IN {{2017,2018}}), KEEPFILTERS(DimDate[Month]<=8))'
    return f'[{metric}]'


def number_format(name):
    if name.endswith('Payment Share'):
        return '0.000%'
    if name.endswith('Avg Review'):
        return '0.0000'
    if name.endswith(('Share', 'Rate', 'Ratio', 'Growth')):
        return '0.00%'
    if name.endswith(('Revenue', 'Value', 'Amount', 'Days', 'Review')):
        return '#,##0.00'
    return '#,##0'


def json_value(value):
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    return value


def load_tables(connection):
    types = {int: ('int64','Int64.Type'), str: ('string','type text'), bool: ('int64','Int64.Type'),
             datetime: ('dateTime','type datetime'), date: ('dateTime','type datetime'),
             Decimal: ('decimal','Currency.Type'), float: ('double','type number')}
    tables = {}
    for name in DIMS + list(FACTS):
        cursor = connection.cursor()
        columns_sql = PROJECTIONS.get(name, '*')
        if name == 'DimDate':
            columns_sql += ', [Year]*100+[Month] AS YearMonth, CONVERT(varchar(7),FullDate,120) AS MonthLabel'
        cursor.execute(f'SELECT {columns_sql} FROM dbo.[{name}]')
        types_by_column = [(col[0], *types[col[1]]) for col in cursor.description]
        payload = json.dumps([[json_value(v) for v in row] for row in cursor], ensure_ascii=False,
                             separators=(',', ':')).encode()
        compressor = zlib.compressobj(level=9, wbits=-15)
        encoded = base64.b64encode(compressor.compress(payload)+compressor.flush()).decode()
        chunks = ',\n'.join(json.dumps(encoded[i:i+60000]) for i in range(0,len(encoded),60000))
        names = ', '.join(json.dumps(c[0]) for c in types_by_column)
        m_types = ', '.join('{"'+col+'", '+m+'}' for col, _, m in types_by_column)
        expression = ['let', '    Rows = Json.Document(Binary.Decompress(Binary.FromText(Text.Combine({',
                      chunks, '    }), BinaryEncoding.Base64), Compression.Deflate)),',
                      '    Raw = Table.FromRows(Rows, {'+names+'}),',
                      '    Typed = Table.TransformColumnTypes(Raw, {'+m_types+'}, "en-US")', 'in Typed']
        columns = [{'name': col,'sourceColumn': col,'dataType': kind,'summarizeBy': 'none'}
                   for col,kind,_ in types_by_column]
        if name == 'DimDate':
            next(c for c in columns if c['name']=='ISOWeekdayName')['sortByColumn']='ISOWeekdayNo'
        tables[name] = {'name': name, 'columns': columns, 'measures': [],
                        'partitions':[{'name':name,'mode':'import','source':{'type':'m','expression':expression}}]}
    query_bytes = sum(len(line.encode()) for t in tables.values()
                      for line in t['partitions'][0]['source']['expression'])
    if query_bytes >= 9_750_000:
        raise ValueError(f'Snapshot query payload is {query_bytes:,} bytes, near the Desktop 10 MB limit')
    return tables


def add_measure(table, metric, expression, hidden=False):
    table['measures'].append({'name':metric, 'expression':expression, 'formatString':number_format(metric),
                              'isHidden':hidden})


def project_fields(fields):
    projections = []
    for table, name, caption, is_measure in fields:
        if isinstance(name, tuple):
            hierarchy, level = name
            expr = {'HierarchyLevel': {'Expression': {'Hierarchy': {
                'Expression': {'SourceRef': {'Entity': table}}, 'Hierarchy': hierarchy}}, 'Level': level}}
            name = hierarchy + '.' + level
        else:
            expr = field(table,name)
        if is_measure:
            expr = {'Measure':expr['Column']}
        projections.append({'field':expr,'queryRef':f'{table}.{name}','nativeQueryRef':caption,'displayName':caption})
    return projections


def write_table(folder, visual_id, projections, sort, position, title, scoped):
    query = {'queryState': {'Values': {'projections': projections}}}
    if sort:
        keys, direction = sort
        keys = (keys,) if isinstance(keys, str) else keys
        query['sortDefinition']={'sort':[{'field':p['field'],'direction':direction}
                                         for key in keys for p in projections if p['nativeQueryRef']==key]}
    write(folder/'visuals'/visual_id/'visual.json', BASE+'visualContainer/2.1.0', name=visual_id,
          position=position, **scoped, visual={
              'visualType':'tableEx','query':query,
              'objects':{'total':[{'properties':{'totals':literal('false')}}]},
              'visualContainerObjects':{
                  'title':[{'properties':{'show':literal('true'),'text':literal(f"'{title}'")}}]}})


def report_page(folder, number, label, note, groups, metrics, sort, filters=()):
    page = mint('warehouse-page-'+str(number))
    folder = folder / 'pages' / page
    write(folder/'page.json', BASE+'page/2.0.0', name=page, displayName=label, displayOption='FitToPage',
          width=1120,height=700)
    projections = project_fields(groups + metrics)
    scoped = {'filterConfig': {'filters': list(filters)}} if filters else {}
    table_position = {'x':34,'y':335,'z':0,'width':1052,'height':338,'tabOrder':1}
    if number == 1:
        table_position['width'] = 525
        write_table(folder, mint('warehouse-annual-totals'), projections[:1] + projections[len(groups):],
                    ('Year','Ascending'),
                    {**table_position,'x':579,'z':2,'width':507,'tabOrder':2}, 'Annual totals', scoped)
    write_table(folder, mint('warehouse-visual-'+str(number)), projections, sort, table_position,
                'Quarterly results' if number == 1 else 'Detailed results', scoped)
    kind, category_no, metric_no, series_no, title = CHARTS[number]
    category, metric = projections[category_no], projections[len(groups)+metric_no]
    roles = {'Category': {'projections': [category]}, 'Y': {'projections': [metric]}}
    if series_no is not None:
        roles['Series'] = {'projections': [projections[series_no]]}
    sort_field = category if number in (1,5,10) else metric
    direction = 'Ascending' if number in (1,5,6,10) else 'Descending'
    chart_query = {'queryState': roles, 'sortDefinition': {
        'sort': [{'field': sort_field['field'], 'direction': direction}]}}
    chart_id = mint('warehouse-chart-'+str(number))
    write(folder/'visuals'/chart_id/'visual.json',BASE+'visualContainer/2.1.0',name=chart_id,
          position={'x':34,'y':20,'z':1,'width':1052,'height':295,'tabOrder':0},
          **scoped,
          visual={'visualType':kind,'query':chart_query,'visualContainerObjects':{
              'title':[{'properties':{'show':literal('true'),'text':literal(f"'{title}'"),'fontSize':literal('19D')}}],
              'subTitle':[{'properties':{'show':literal('true'),'text':literal(f"'{note}'")}}]}})
    return page


def main():
    cli=argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--server',default='localhost')
    cli.add_argument('--database',default='OlistDW_Test')
    args=cli.parse_args()
    with pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};Trusted_Connection=yes;'
                        f'SERVER={args.server};DATABASE={args.database}') as connection:
        tables=load_tables(connection)
    for fact, measures in BASE_MEASURES.items():
        for name, expression in measures.items():
            add_measure(tables[fact],name,expression)
    links=[]
    for fact,dims in FACTS.items():
        for dim in dims:
            key=dim+'Key'
            links.append({'name':str(uuid5(NAMESPACE_URL,f'{fact}/{dim}')), 'fromTable':fact, 'fromColumn':key,
                          'toTable':'Dim'+dim, 'toColumn':key, 'crossFilteringBehavior':'oneDirection'})
    report,model=Path(f'{NAME}.Report'),Path(f'{NAME}.SemanticModel')
    write(Path(f'{NAME}.pbip'),'pbip/pbipProperties/1.0.0',version='1.0',artifacts=[{'report':{'path':str(report)}}])
    write(report/'definition.pbir','item/report/definitionProperties/2.0.0',version='4.0',
          datasetReference={'byPath':{'path':f'../{model}'}})
    write(model/'definition.pbism','item/semanticModel/definitionProperties/1.0.0',version='4.0',settings={})
    definition=report/'definition'
    write(definition/'version.json',BASE+'versionMetadata/1.0.0',version='2.0.0')
    write(definition/'report.json',BASE+'report/3.0.0',themeCollection={
        'baseTheme':{'name':'CY24SU02','type':'SharedResources',
                     'reportVersionAtImport':{'visual':'2.1.0','page':'2.0.0','report':'3.0.0'}}})
    pages=[]
    for n, ((title, _, note),(groups,fact,metrics,sort)) in enumerate(zip(QUESTIONS,PAGES),1):
        group_fields=[(t,c,LABELS.get(c,c),False) for t,c in groups]
        measure_fields=[]
        for metric in metrics:
            name=f'Q{n:02} {metric}'
            add_measure(tables[fact],name,question_measure(n,metric))
            measure_fields.append((fact,name,LABELS.get(metric,metric),True))
        if n==4:
            note='Payment share uses the total amount across methods under the current filters.'
        order=(LABELS.get(sort,sort),'Ascending' if n==6 else 'Descending') if sort else (
            group_fields[0][2],'Ascending')
        if n == 1:
            order = (('Year','Quarter'),'Ascending')
        pages.append(report_page(definition,n,f'Q{n:02} {title}',note,group_fields,measure_fields,order))
    write(definition/'pages/pages.json',BASE+'pagesMetadata/1.0.0',pageOrder=pages,activePageName=pages[0])
    write(model/'model.bim',None,name=NAME,compatibilityLevel=1601,model={
        'culture':'en-US','defaultPowerBIDataSourceVersion':'powerBI_V3','discourageImplicitMeasures':True,
        'tables':list(tables.values()), 'relationships':links})
    positions={'DimProduct':(30,20),'DimSeller':(30,250),'DimPayment':(30,520),
               'FactSales':(340,20),'FactOrder':(340,300),'FactPayment':(340,600),
               'DimDate':(700,20),'DimCustomer':(700,380),'DimOrder':(700,650)}
    write(model/'diagramLayout.json',None,version='1.1.0',diagrams=[{
        'name':'All tables','ordinal':0,'scrollPosition':{'x':0,'y':0},'zoomValue':70,
        'nodes':[{'nodeIndex':name,'location':{'x':x,'y':y},'size':{'width':234,'height':200},'zIndex':i}
                 for i,(name,(x,y)) in enumerate(positions.items())],
        'isDefault':True}],selectedDiagram='All tables')


if __name__=='__main__':
    main()
