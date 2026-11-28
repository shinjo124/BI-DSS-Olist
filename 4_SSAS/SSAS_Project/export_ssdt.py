"""Split the deployed XMLA definition into an editable SSDT project."""
from pathlib import Path
from xml.dom import minidom
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent


def children(node, name):
    return [n for n in node.childNodes if n.nodeType == n.ELEMENT_NODE and n.localName == name]


def add(doc, parent, name, text=None):
    node = doc.createElement(name)
    if text is not None:
        node.appendChild(doc.createTextNode(text))
    parent.appendChild(node)
    return node


def identifier(node):
    return children(node, 'ID')[0].firstChild.data


def main():
    doc = minidom.parse(str(HERE / 'OlistBI.xmla'))
    db = children(children(doc.documentElement, 'ObjectDefinition')[0], 'Database')[0]
    namespaces = {k: v for k, v in db.attributes.items() if k.startswith('xmlns:')}
    namespaces['xmlns'] = doc.documentElement.namespaceURI
    project = ET.Element('Project')
    ET.SubElement(project, 'ProductVersion').text = '16.0.21152.0'
    ET.SubElement(project, 'SchemaVersion').text = '9.0.2.10'

    def save(node, filename):
        for name, value in namespaces.items():
            node.setAttribute(name, value)
        (HERE / filename).write_text(node.toxml() + '\n', encoding='utf-8')

    def item(group, filename, tag='ProjectItem'):
        row = ET.SubElement(group, tag)
        ET.SubElement(row, 'Name').text = filename
        ET.SubElement(row, 'FullPath').text = filename
        return row

    item(project, 'OlistBI.database', 'Database')
    for folder, kind, suffix in [('Cubes', 'Cube', 'cube'), ('Dimensions', 'Dimension', 'dim'),
                                 ('DataSources', 'DataSource', 'ds'), ('DataSourceViews', 'DataSourceView', 'dsv')]:
        section = ET.SubElement(project, folder)
        parent = children(db, folder)[0]
        for node in children(parent, kind):
            node_id = identifier(node)
            entry = item(section, f'{node_id}.{suffix}')
            if kind == 'Cube':
                partition_file = f'{node_id}.partitions'
                item(ET.SubElement(entry, 'Dependencies'), partition_file)
                partition_cube = doc.createElement('Cube')
                add(doc, partition_cube, 'ID', node_id)
                groups = add(doc, partition_cube, 'MeasureGroups')
                for group in children(children(node, 'MeasureGroups')[0], 'MeasureGroup'):
                    target = add(doc, groups, 'MeasureGroup')
                    add(doc, target, 'ID', identifier(group))
                    target.appendChild(children(group, 'Partitions')[0])
                save(partition_cube, partition_file)
            save(node, f'{node_id}.{suffix}')
        db.removeChild(parent)
    save(db, 'OlistBI.database')
    config = ET.SubElement(ET.SubElement(project, 'Configurations'), 'Configuration')
    ET.SubElement(config, 'Name').text = 'Development'
    ET.SubElement(config, 'Options')
    ET.indent(project)
    ET.ElementTree(project).write(HERE / 'OlistBI.dwproj', encoding='utf-8')
    (HERE / 'OlistBI.slnx').write_text(
        '<Solution>\n  <Configurations><BuildType Name="Development" /><Platform Name="Default" /></Configurations>\n'
        '  <Project Path="OlistBI.dwproj" Type="d2abab84-bf74-430a-b69e-9dc6d40dda17">\n'
        '    <Platform Project="?" /><Deploy />\n  </Project>\n</Solution>\n', encoding='utf-8')


if __name__ == '__main__':
    main()
