"""Render the checked Olist report source to Word."""
from pathlib import Path
import re

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def main():
    doc = Document()
    doc.core_properties.title = 'Olist Business Intelligence Final Project'
    doc.core_properties.author = 'Lam and Kiet'
    for name in ['Normal', 'Title', 'Heading 1', 'Heading 2', 'Caption']:
        style = doc.styles[name]
        style.font.name = 'Aptos'
        style.font.color.rgb = RGBColor(0, 0, 0)
    doc.styles['Normal'].font.size = Pt(11)
    doc.styles['Normal'].paragraph_format.space_after = Pt(7)
    doc.styles['Title'].font.size = Pt(27)
    for border in doc.styles['Title']._element.xpath('.//w:pBdr'):
        border.getparent().remove(border)
    title_border = OxmlElement('w:pBdr')
    bottom = OxmlElement('w:bottom')
    bottom.set(qn('w:val'), 'nil')
    title_border.append(bottom)
    doc.styles['Title']._element.get_or_add_pPr().append(title_border)
    doc.styles['Heading 1'].font.size = Pt(17)
    section = doc.sections[0]
    section.top_margin = section.bottom_margin = Inches(0.75)
    section.left_margin = section.right_margin = Inches(0.85)
    section.footer.paragraphs[0].add_run('OLIST BUSINESS INTELLIGENCE  •  LAM AND KIET').font.size = Pt(8)
    images = {
        'Customer segmentation using K Means': ('5_DataMining/results/kmeans_selection.png',
                                                'Figure 1. Candidate cluster evaluation on the historical customer snapshot.'),
        'Low review prediction using Random Forest': ('5_DataMining/results/random_forest/evaluation.png',
                                                     'Figure 2. Confusion matrix and precision–recall curve on the held-out period.'),
    }
    source = (HERE / 'DRAFT_LAM_SECTIONS.md').read_text(encoding='utf-8')
    for block in source.strip().split('\n\n'):
        if block.startswith('# '):
            doc.add_paragraph(block[2:], 'Title')
        elif block.startswith('## '):
            name = block[3:]
            if name == 'Customer segmentation using K Means':
                doc.add_page_break()
            doc.add_heading(name, 1)
        elif block.startswith('|'):
            rows = [[cell.strip() for cell in line.strip('|').split('|')]
                    for line in block.splitlines() if not re.match(r'^\|\s*[-:]+\s*\|', line)]
            table = doc.add_table(rows=0, cols=len(rows[0]))
            table.style = 'Light Shading Accent 1'
            for row in rows:
                cells = table.add_row().cells
                for cell, value in zip(cells, row):
                    cell.text = value
                    for paragraph in cell.paragraphs:
                        paragraph.paragraph_format.space_after = Pt(4)
                        for run in paragraph.runs:
                            run.font.size = Pt(10)
            if len(rows[0]) == 2:
                table.autofit = False
                for column, width in zip(table.columns, [2.0, 4.8]):
                    column.width = Inches(width)
                    for cell in column.cells:
                        cell.width = Inches(width)
            table.rows[0]._tr.get_or_add_trPr().append(OxmlElement('w:tblHeader'))
            for row in table.rows:
                row._tr.get_or_add_trPr().append(OxmlElement('w:cantSplit'))
        else:
            doc.add_paragraph(block.replace('`', ''))
            if block.startswith('The first two groups'):
                image, caption = images['Customer segmentation using K Means']
            elif block.startswith('The holdout shows'):
                image, caption = images['Low review prediction using Random Forest']
            else:
                continue
            doc.add_picture(str(ROOT / image), width=Inches(6.4))
            doc.add_paragraph(caption, 'Caption')
    doc.add_heading('Source and validation files', 1)
    doc.add_paragraph('Olist, Brazilian E-Commerce Public Dataset, Kaggle. https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce')
    doc.add_paragraph('Dataset profile and SHA-256: 2_Dataset/DATASET_PROFILE.md. '
                      'SQL and ETL evidence: 3_SSIS/README.md. '
                      'Cube build, MDX exports, and validation: 4_SSAS/. '
                      'Mining code, evaluation, and figures: 5_DataMining/.')
    doc.save(HERE / 'Olist Business Intelligence Report.docx')


if __name__ == '__main__':
    main()
