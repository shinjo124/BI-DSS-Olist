# Olist BI Project

This repository contains the project handoff, dataset profile, warehouse and measure specification, and team plan for a two-person BI final project. The Olist dataset has been profiled. Two alternative SSIS packages load the same warehouse: one uses native SSIS Data Flows and the other uses Python plus sqlcmd. The native SSIS package, SQL warehouse load, and exploratory K-Means run have been tested locally; the SSAS cube, reports, and cross-machine integration remain open. No deadline has been set.

## Start here

1. [Project handoff](HANDOFF.md) — requirements, decisions, current state, and next steps.
2. [Warehouse design](WAREHOUSE_DESIGN.md) — proposed fact grains, dimensions, measures, question mapping, and validation cases.
3. [Project flow and assignments](PROJECT_PLAN.md) — overall dependency flow, individual A/B checklists, and handoff points.
4. [Dataset profile](2_Dataset/DATASET_PROFILE.md) — source, snapshot hash, data quality checks, and mining cohort sizes.
5. [Olist outline in English](references/OLIST_OUTLINE_EN.md) — English working version of the original proposal.
6. [Original outline](references/Original-Olist-Outline.docx) — preserved source document.

## Dataset

The checked `olist-download.zip` snapshot is in the [team Drive](https://drive.google.com/drive/folders/1hKuZP3kOY0uqP6j4WBQASlRBnHyWJew3?usp=sharing), under `2_Dataset/`. The local archive and extracted CSVs are excluded from Git. Download the Drive copy and verify its SHA-256 against the dataset profile before use.

## Working layout

The Drive has the submission folders `1_Report/`, `2_Dataset/`, `3_SSIS/`, `4_SSAS/`, `5_DataMining/`, and `6_Videos/`. GitHub stores source and project documentation; Drive stores the dataset, videos, and submission files. Drive access for every team member and the instructor still needs verification.

Setup and test instructions for both alternative SSIS packages are in [3_SSIS/README.md](3_SSIS/README.md). Use one package per warehouse refresh; they are not sequential stages. The [K-Means README](5_DataMining/README.md) documents its environment, run commands, and findings. The saved native package loaded the full snapshot successfully in the local Visual Studio debugger; second-machine verification remains open.

The [integration subset](2_Dataset/INTEGRATION_SUBSET.md) contains the first cube-check references. [Lam's report draft](1_Report/DRAFT_LAM_SECTIONS.md) is working material and still needs the remaining team results and final review.
