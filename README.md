# Olist BI Project

This two-person BI project analyzes the checked Brazilian Olist e-commerce snapshot. Two alternative SSIS packages load the documented warehouse. The SSAS cube has processed locally, all ten MDX analyses match SQL, and three live Excel PivotTables have been verified. Power BI has an editable warehouse project and a separate live SSAS project. Both mining experiments and the DOCX/PDF report are available. Cross-machine integration and submission access remain open. No deadline has been set.

## Start here

1. [Project handoff](HANDOFF.md) — requirements, decisions, current state, and next steps.
2. [Warehouse design](WAREHOUSE_DESIGN.md) — proposed fact grains, dimensions, measures, question mapping, and validation cases.
3. [Project flow and assignments](PROJECT_PLAN.md) — overall dependency flow, individual A/B checklists, and handoff points.
4. [Dataset profile](2_Dataset/DATASET_PROFILE.md) — source, snapshot hash, data quality checks, and mining cohort sizes.
5. [Olist outline in English](references/OLIST_OUTLINE_EN.md) — English working version of the original proposal.
6. [Original outline](references/Original-Olist-Outline.docx) — preserved source document.
7. [Cube, MDX, Excel and Power BI](4_SSAS/README.md) — setup, deliverables, and local verification.
8. [Report PDF](1_Report/Olist%20Business%20Intelligence%20Report.pdf) and [editable Word report](1_Report/Olist%20Business%20Intelligence%20Report.docx).

## Dataset

The checked `olist-download.zip` snapshot is in the [team Drive](https://drive.google.com/drive/folders/1hKuZP3kOY0uqP6j4WBQASlRBnHyWJew3?usp=sharing), under `2_Dataset/`. The local archive and extracted CSVs are excluded from Git. Download the Drive copy and verify its SHA-256 against the dataset profile before use.

## Working layout

The Drive has the submission folders `1_Report/`, `2_Dataset/`, `3_SSIS/`, `4_SSAS/`, `5_DataMining/`, and `6_Videos/`. GitHub stores source and project documentation; Drive stores the dataset, videos, and submission files. Drive access for every team member and the instructor still needs verification.

Setup and test instructions for both alternative SSIS packages are in [3_SSIS/README.md](3_SSIS/README.md). Use one package per warehouse refresh; they are not sequential stages. The [K-Means README](5_DataMining/README.md) documents its environment, run commands, and findings. The saved native package loaded the full snapshot successfully in the local Visual Studio debugger; second-machine verification remains open.

The [integration subset](2_Dataset/INTEGRATION_SUBSET.md) contains the first cube-check references. The [report source](1_Report/DRAFT_LAM_SECTIONS.md) contains the combined analysis and mining write-up.
