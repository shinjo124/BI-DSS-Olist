# Olist BI Project

This repository contains the project handoff, dataset profile, warehouse and measure specification, and team plan for a two-person BI final project. The Olist data has been profiled, but the warehouse, SSIS package, SSAS cube, reports, and mining models have not yet been built. No deadline has been set.

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

There is no shared build or test command yet. Each implementation should document its setup, run instructions, and validation evidence. Do not treat the previously inspected class exercises as Olist project deliverables.
