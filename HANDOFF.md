# Project Handoff — 17 November 2026

## Goal and submission requirements

The two-person team must submit a report of no more than 100 pages covering the SSIS data selection and loading process, schema and cube construction, analysis and reports for 10 questions using SSAS and Power BI, MDX analysis, Excel PivotTable analysis, and two data-mining algorithms. The Google Drive submission must contain DOCX and PDF reports, the dataset, SSIS project, SSAS project with Power BI and Excel files, and mining code. Videos are optional. Share the submission with `phungntk@uit.edu.vn`.

The team Drive folder is [BI-DSS Olist](https://drive.google.com/drive/folders/1hKuZP3kOY0uqP6j4WBQASlRBnHyWJew3?usp=sharing). Its six submission folders and `olist-download.zip` in `2_Dataset/` were verified. Access for each teammate and the instructor has not been verified.

The Olist outline is a working proposal, not evidence of implementation or additional instructor requirements. The provided assignment requirements are the source of truth. See the [English working version](references/OLIST_OUTLINE_EN.md); the original source is preserved in `references/Original-Olist-Outline.docx`.

The source repository is [shinjo124/BI-DSS-Olist](https://github.com/shinjo124/BI-DSS-Olist). Its About description and homepage link to the Drive have been set. The initial source and documentation commit is on `main`.

## Decisions

- The team has two members and no fixed deadline. **A is Lam; B is Kiet.** This mapping follows the agreed work split and the SQL/SSIS environment verified on Lam's machine.
- Keep Olist and the 10 questions as the project direction. The team may revise schema, measures, or MDX when the outline has a defect, and should record the reason.
- Implement all 10 questions with manual SSAS analysis and Power BI. The team target is also all 10 MDX queries and at least three Excel Pivot analyses; these counts are team decisions, not explicit assignment requirements for MDX or Excel.
- For questions 4 and 10, keep each `payment_type` separate and sum actual `payment_value` rows. An order paid through multiple methods contributes to each method according to its payment rows. Do not select a primary method or collapse methods into an “All” bucket.
- Use K-Means for customer segmentation and Random Forest to predict low review scores at delivery time. For the Random Forest cohort, retain orders whose selected review has `review_answer_timestamp >= delivered_customer_date` as a proxy that the label was not yet observed. The timestamp is imperfect evidence of when the score became available.
- Finish required deliverables before deciding whether to make the optional video.
- Keep SSAS many-to-many for Product/Seller filters on order-level measures. Kiet's one working day for initial implementation and validation starts when the base cube processes and independent SQL reference results are ready. At the checkpoint, assess the grouped-fact fallback if checks still fail. The project submission deadline is tracked separately. [Warehouse design](WAREHOUSE_DESIGN.md)

## Dataset and evidence

The Olist archive was downloaded from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), profiled, and identified by SHA-256 in [2_Dataset/DATASET_PROFILE.md](2_Dataset/DATASET_PROFILE.md). The snapshot contains nine CSV files. The archive and extracted CSVs are excluded from Git; teammates should use the Drive copy and verify its hash.

The profile found 112,650 order-item rows, including 9,803 multi-item orders; 547 orders have multiple review rows; and 2,961 orders have multiple payment rows. Directly joining these tables can multiply measures, which is why the design separates grains. Only 2,887 of 94,983 customers in scope made repeat purchases (3.04%). The proposed Random Forest cohort contains 91,170 delivered orders with a selected review after the delivery timestamp proxy; 8,629 (9.46%) have a score of 1 or 2.

The snapshot figures are input-validation targets, not warehouse or cube results. No SSIS, SSAS, Power BI, Excel Pivot, or mining implementation has been verified yet.

## Environment and access

Each teammate must check their own SQL Server, SSIS, SSAS Multidimensional, Power BI Desktop, Excel, and Python environment. Versions, instances, permissions, and paths can differ. There is no verified common setup guide yet; document portable connection settings and run instructions with each deliverable.

## Remaining work

1. Have Kiet download the Drive archive and verify its hash.
2. Reproduce one analysis on both machines from the same representative CSV subset through SSIS, the warehouse, and SSAS. Run the MDX query and check Power BI and Excel connectivity before scaling to the full dataset.
3. Validate the full load and reload against the dataset profile. Test many-to-many at group and grand-total levels. Start the shared reconciliation checklist with Q4, Q6, and Q8, then reconcile all 10 SSAS, Power BI, and MDX results and the selected Pivot analyses. Save queries, filters, and results as work progresses. [Project plan](PROJECT_PLAN.md)
4. Start mining in parallel once the CSV and data rules are ready. Inspect RFM distributions and cluster meaning. For Random Forest, split by delivery time, restrict training to reviews available by the cutoff, and report exclusions, baseline, metrics, and limitations.
5. Cross-check results, collect real evidence, produce the DOCX/PDF report within the page limit, and verify Drive access for the instructor. Make the optional video only after required work is complete.

Do not invent output figures or screenshots. Before ETL reload, deployment, or processing, verify the target and avoid overwriting class exercises. Update this handoff with relative paths and reproducible validation evidence as work is completed.
