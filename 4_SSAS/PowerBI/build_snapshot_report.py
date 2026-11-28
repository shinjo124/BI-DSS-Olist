"""Build a portable Power BI project from the reconciled SSAS exports."""
import csv
import json
from pathlib import Path
from uuid import uuid5, NAMESPACE_URL

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'MDX' / 'results'
PREFIX = 'https://developer.microsoft.com/json-schemas/fabric/'
NAME = 'Olist Analysis'
REPORT = f'{NAME}.Report'
MODEL = f'{NAME}.SemanticModel'
QUESTIONS = [
    ('Revenue and orders by quarter', ['Period'], 'Item prices in BRL. The 2018 snapshot covers part of the year.'),
    ('Top categories by revenue', ['Category'], 'Top 10 categories by item revenue.'),
    ('Top customer states', ['State'], 'Top 5 customer states by revenue. Average order value excludes freight.'),
    ('Payment method share', ['Payment method'], 'Share of BRL 15,738,221.95 paid across all methods in the full snapshot.'),
    ('Monthly revenue growth in 2017', ['Month'], 'January compares with the BRL 10.90 December 2016 baseline.'),
    ('Lowest category reviews', ['Category'], 'At least 100 reviewed orders per category. Reviews are at order level.'),
    ('Delivery by customer state', ['State'], 'Delivery and late rate use their respective eligibility counts.'),
    ('Top sellers by revenue', ['Seller ID', 'State'], 'Top 10 sellers. Review averages describe orders containing each seller.'),
    ('Freight ratio by region', ['Year', 'Region'], 'January through August in both years. Freight divided by item revenue.'),
    ('Payment amount by weekday', ['Weekday', 'Payment method'], 'Weekdays follow purchase date. Payment amounts use actual payment rows.'),
]
PERCENT = {'Payment Share', 'Late Rate', 'Freight Ratio', 'MoM Growth'}
MONEY = {'Revenue', 'Freight Value', 'Payment Amount', 'Avg Order Value'}


def write(path, schema, **value):
    path = HERE / path
    path.parent.mkdir(parents=True, exist_ok=True)
    if schema:
        value = {'$schema': PREFIX + schema + '/schema.json', **value}
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def field(table, column):
    return {'Column': {'Expression': {'SourceRef': {'Entity': table}}, 'Property': column}}


def literal(value):
    return {'expr': {'Literal': {'Value': value}}}


def mint(key):
    return uuid5(NAMESPACE_URL, 'olist-dss-bi/' + key).hex[:20]


def read_question(number, captions):
    with (SOURCE / f'Q{number:02}.csv').open(encoding='utf-8-sig', newline='') as stream:
        reader = csv.DictReader(stream)
        metrics = [col for col in reader.fieldnames if not col.startswith(('Member', 'Key'))]
        rows = []
        for idx, raw in enumerate(reader, 1):
            members = [raw[f'Member{i}'] for i in range(len(captions))]
            if number == 1 and len(members[0]) == 5:
                members[0] = f'{members[0][:4]} Q{members[0][-1]}'
            rows.append([idx, *members, *(float(raw[col]) if raw[col] else None for col in metrics)])
    return ['Row', *captions, *metrics], rows


def main():
    write(Path(f'{NAME}.pbip'), 'pbip/pbipProperties/1.0.0', version='1.0',
          artifacts=[{'report': {'path': REPORT}}], settings={'enableAutoRecovery': False})
    write(Path(REPORT) / 'definition.pbir', 'item/report/definitionProperties/2.0.0', version='4.0',
          datasetReference={'byPath': {'path': f'../{MODEL}'}})
    write(Path(MODEL) / 'definition.pbism', 'item/semanticModel/definitionProperties/1.0.0',
          version='4.0', settings={})
    definition = Path(REPORT) / 'definition'
    base = 'item/report/definition/'
    write(definition / 'version.json', base + 'versionMetadata/1.0.0', version='2.0.0')
    write(definition / 'report.json', base + 'report/3.0.0', themeCollection={
        'baseTheme': {'name': 'CY24SU02', 'type': 'SharedResources',
                      'reportVersionAtImport': {'visual': '2.1.0', 'page': '2.0.0', 'report': '3.0.0'}}
    })
    tables, pages = [], []
    for number, (title, captions, note) in enumerate(QUESTIONS, 1):
        table = f'Q{number:02}'
        names, rows = read_question(number, captions)
        columns = []
        for name in names:
            data_type = 'string' if name in captions else ('int64' if name == 'Row' or name == 'Quantity'
                                                             or name.endswith('Count') else 'double')
            col = {'name': name, 'sourceColumn': name, 'dataType': data_type, 'summarizeBy': 'none'}
            if name in PERCENT:
                col['formatString'] = '0.00%'
            elif name in MONEY:
                col['formatString'] = '#,##0.00'
            elif data_type != 'string':
                col['formatString'] = '#,##0' if data_type == 'int64' else '0.00'
            columns.append(col)
        m_types = {'int64': 'Int64.Type', 'string': 'type text', 'double': 'type number'}
        m_columns = ', '.join('{"' + col['name'] + '", ' + m_types[col['dataType']] + '}' for col in columns)
        q = lambda x: json.dumps(x, ensure_ascii=False)
        m_rows = ',\n'.join('{' + ', '.join(q(value) for value in row) + '}' for row in rows)
        expression = ['let', '    Data = #table({' + ', '.join(map(q, names)) + '}, {',
                      m_rows, '    }),', '    Typed = Table.TransformColumnTypes(Data, {' + m_columns + '})',
                      'in Typed']
        tables.append({'name': table, 'description': note, 'columns': columns,
                       'partitions': [{'name': table, 'mode': 'import', 'source': {'type': 'm', 'expression': expression}}]})
        page = mint(table)
        pages.append(page)
        folder = definition / 'pages' / page
        write(folder / 'page.json', base + 'page/2.0.0', name=page, displayName=f'{table} {title}',
              displayOption='FitToPage', width=1120, height=700)
        visual_id = mint(table + '-table')
        write(folder / 'visuals' / visual_id / 'visual.json', base + 'visualContainer/2.1.0',
              name=visual_id, position={'x': 34, 'y': 30, 'z': 0, 'width': 1052, 'height': 630, 'tabOrder': 0},
              visual={
                  'visualType': 'tableEx',
                  'query': {'queryState': {'Values': {'projections': [
                      {'field': field(table, col), 'queryRef': f'{table}.{col}', 'nativeQueryRef': col} for col in names
                  ]}}, 'sortDefinition': {'sort': [{'field': field(table, 'Row'), 'direction': 'Ascending'}]}},
                  'visualContainerObjects': {
                      'title': [{'properties': {'show': literal('true'), 'text': literal(f"'{title}'"),
                                                 'fontSize': literal('20D')}}],
                      'subTitle': [{'properties': {'show': literal('true'), 'text': literal(f"'{note}'")}}],
                  },
              })
    write(definition / 'pages/pages.json', base + 'pagesMetadata/1.0.0',
          pageOrder=pages, activePageName=pages[3])
    write(Path(MODEL) / 'model.bim', None, name=NAME, compatibilityLevel=1601,
          model={'culture': 'en-US', 'defaultPowerBIDataSourceVersion': 'powerBI_V3',
                 'discourageImplicitMeasures': True, 'tables': tables})


if __name__ == '__main__':
    main()
