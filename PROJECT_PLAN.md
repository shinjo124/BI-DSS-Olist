# Olist BI Project Flow and Assignments

## Delivery status as of 28 November 2026

- [x] Built the editable SSAS project and processed the full and four-order cubes locally. The subset checks cover overlapping categories and sellers and missing reviews.
- [x] Executed and reconciled all ten MDX analyses against independent SQL. The local full and subset Q4 totals were BRL 15,738,221.95 and BRL 400.00, respectively.
- [x] Executed all ten questions in Visual Studio's native SSAS Browser and captured the results. Q4 used the visual designer and the other nine used the MDX editor.
- [x] Verified three live full-snapshot Excel PivotTables and one live subset Q4 PivotTable. Both Q4 workbooks matched SQL for every amount and share.
- [x] Built Power BI projects for the editable nine-table warehouse model and the live SSAS connection. The ten questions each have a chart and detail table. The warehouse calculations match SSAS and the live payment page was checked in Desktop.
- [x] Completed both mining experiments and measured Random Forest on a later holdout. Exported the combined Word and PDF report.
- [ ] Reproduce the workflow and verify live Power BI connectivity on the second machine.
- [ ] Verify the instructor's Drive access and publish the reviewed submission. The existing native SSIS package requires machine-specific connections and has no separate rejected-row export.

Use the [BI guide](4_SSAS/README.md) for setups and evidence. The assignments and first integration checklist below retain the division of work and cross-machine acceptance criteria.

The team has two members: **A is Lam; B is Kiet.** This is the agreed starting split, based on the verified SQL/SSIS setup on Lam's machine. Rebalance if the actual workload or availability requires it. No deadline has been set, so stages show dependencies rather than dates. Each person prepares evidence and report content for their work; both cross-review.

## Project flow

```mermaid
flowchart TD
    D["A: obtain and profile Olist snapshot"] --> S["A + B: agree on 10 questions, grain, schema, and measures"]
    S --> T["A + B: reproduce one analysis end to end on both machines"]
    T --> E["A: full warehouse load and reload validation"]
    S --> P["B: cube and report design"]
    E --> C["B: build and process SSAS cube"]
    P --> C
    C --> V["A + B: 10 manual SSAS analyses and Power BI report"]
    C --> X["A: at least 3 Excel Pivot analyses"]
    C --> M["A + B: all 10 MDX queries"]
    D --> K["A: K-Means"]
    D --> R["B: Random Forest"]
    S -. "shared data rules" .-> K
    S -. "shared data rules" .-> R
    V --> Q["A + B: reconcile results and cross-review"]
    X --> Q
    M --> Q
    K --> Q
    R --> Q
    Q --> N["A: assemble report; B: review and prepare submission"]
    N --> Z["B: verify Drive and permissions; optional video"]
```

Mining can run in parallel once the CSV and data rules are available. The team targets all 10 MDX queries and at least three Pivot analyses. These are team decisions, not explicit assignment counts for those sections.

## Current priorities — agreed 27 November 2026

The data foundation has passed local checks: the warehouse and both alternative SSIS packages have full-snapshot validation, SQL references exist for all 10 questions, and K-Means has saved results and local reproduction evidence. The next priority is a processed SSAS cube and one verified analysis across the tools. Second-machine reproduction, final mining interpretation, and submission checks remain open.

1. **Lam hands the warehouse to Kiet:** provide [schema and measure definitions](WAREHOUSE_DESIGN.md), [SSIS setup and validation evidence](3_SSIS/README.md), the checked dataset, and the SQL references below. Confirm the target database and portable connection settings together. Address failures found during integration before extending ETL functionality.
2. **Kiet builds and processes the base cube; both complete Q4 end to end:** use the acceptance checklist below before expanding the reports to all 10 questions.
3. **Both validate Q6 and Q8 next:** check category/seller membership, reviewed-order denominators, and grand totals against SQL. Then complete the remaining seven questions and at least three Pivot analyses.
4. **Mining proceeds alongside cube work:** Lam finalizes the existing K-Means interpretation and limitations. Kiet implements Random Forest at delivery time with a temporal split, training-cutoff label availability, a baseline under the same split, and precision, recall, F1, ROC-AUC, and a confusion matrix. Finish evaluation before adding model complexity.
5. **Build the report as evidence becomes available:** for every question, save the query, filters, actual output, screenshot, business meaning, and limitation together. Compare equivalent months for incomplete 2018 data; explain that reviews belong to orders and are not direct ratings of each seller. Finalize DOCX/PDF and verify submission access after reconciliation.

## First integration milestone — Q4 payment amount and share

- [ ] Lam loads a representative subset of the shared snapshot through SSIS into the warehouse while Kiet builds the first cube measures. Include a multi-method payment, repeated items within a category or seller, an order spanning groups, and an order without a review.
- [ ] Kiet processes the base cube and implements Q4 using actual payment rows by method. Keep each method separate for orders with multiple payment types. Payment share divides each method's amount by the total across methods under the same non-method filters.
- [ ] Both reproduce Q4 on the same four-order subset in SQL, SSAS Browser, Power BI, MDX, and an Excel PivotTable. Expected total: **BRL 400.00**; credit_card **BRL 255.54 (63.885%)**, boleto **BRL 126.54 (31.635%)**, voucher **BRL 17.92 (4.480%)**. Check unrounded values before display rounding and confirm shares total 100%. See [subset references](2_Dataset/INTEGRATION_SUBSET.md).
- [ ] Open and refresh the Q4 report and PivotTable and run its MDX query from the other machine. Record the snapshot, database/cube, connection settings without secrets, filters, actual results, and setup issues. Save the SSAS project, PBIX, MDX, workbook, and screenshots in the matching `4_SSAS/` folders and link the evidence here.
- [ ] After the subset agrees across tools and machines, repeat Q4 on the full snapshot and reconcile it with the [full SQL reference](3_SSIS/sql/reference_questions_01_05_results.txt). Keep subset evidence separate. This milestone is complete only when both checks have actual results and evidence; local ETL success alone does not complete it.
- [ ] Maintain one shared checklist for all 10 questions with the measure, filters, sort order, expected SQL result, and evidence links for SSAS, Power BI, and MDX. Keep the subset and full-snapshot results distinct. Start with Q4 (payment share), Q6 (category reviews), and Q8 (seller order counts and reviews), then complete and reconcile the other seven. Save each query, its filter settings, and its actual result as work is completed.

## A — Lam

- [x] **Dataset profile:** the snapshot has been checked; results, hashes, and source conditions are in `2_Dataset/DATASET_PROFILE.md`.
- [x] **Share dataset:** `olist-download.zip` is in `2_Dataset/` on the [team Drive](https://drive.google.com/drive/folders/1hKuZP3kOY0uqP6j4WBQASlRBnHyWJew3?usp=sharing). The user confirmed the shared-dataset step complete. Keep raw CSVs out of Git.
- [ ] **Shared design:** agree with B on the 10 question definitions, grain, keys, filters, missing-data rules, and measure calculations before implementing separate components. Record changes from the outline and why.
- [ ] **SQL and SSIS:** maintain the two alternative Olist ETL packages for the same staging and warehouse process; document portable setup and run steps for each. Reconcile rows, keys, revenue, freight, payment totals, and rejected rows against the source; run the load twice and verify identical totals and no duplicates or data loss. Use one package per refresh, not both consecutively. Hand B the schema, validated data, SQL checks, and evidence.
- SQL schema, staging importer and warehouse transformation have passed local full-snapshot totals and row reconciliation. The native SSIS package ran the full snapshot successfully in Visual Studio; the earlier Python/sqlcmd package was tested on the subset and full snapshot. A reproducible two-machine handoff remains open. [SSIS status](3_SSIS/README.md)
- [ ] **K-Means:** build customer-level data, inspect RFM distributions and limited repeat-purchase frequency, compare candidate values of k, evaluate and interpret cluster profiles. Hand off code, environment, run steps, actual results, and limitations. Do not label customers loyal without evidence.
- An exploratory K-Means run and initialization stability check have been completed locally; review the profiles and limitations before using them in the report. [K-Means results](5_DataMining/README.md)
- [ ] **Excel Pivot:** after the cube is ready, create at least three useful analyses; save the workbook and evidence, document the source/connection, and reconcile measures with SQL or the cube.
- [ ] **MDX:** write and run questions 1–5 using actual cube metadata; reconcile each with SQL or SSAS Browser and Power BI under identical filters, and review B's results.
- [ ] **Report:** assemble the DOCX from both members' explanations, figures, run steps, and actual results; export PDF, stay within 100 pages, and send it to B for final review.

## B — Kiet

- [ ] **Analysis specification:** map the 10 outline questions to measures, dimensions, filters, and expected outputs. Agree on schema, grain, and calculations with A; hand the specification to A for warehouse work.
- [ ] **SSAS and Power BI:** design the cube in parallel with ETL. Keep many-to-many and give initial implementation and SQL validation one working day starting when the base cube processes and SQL reference results are ready. Use the group and grand-total checks in [the warehouse design](WAREHOUSE_DESIGN.md). Document failures and assess the fallback at the checkpoint. Complete the 10 manual SSAS analyses and Power BI report and hand A the project, PBIX, connection instructions, results, and evidence.
- [ ] **Random Forest:** split by delivery time and train only on orders whose selected review answer is available by the training cutoff. Record exclusions, fit preprocessing on training data, and compare with a baseline under the same split. Hand A the code, environment, run steps, actual results, and timestamp limitations. Use only features available at delivery.
- [ ] **MDX:** write and run questions 6–10 using actual cube metadata; reconcile each with SQL or SSAS Browser and Power BI under identical filters, and review A's results. Save queries and evidence.
- [ ] **Submission package:** review the report and A's deliverables; prepare the Drive folder structure and verify required files, links, and permission for `phungntk@uit.edu.vn`. Do not assume access has been granted until checked.

## Handoffs and joint checks

The table tracks the **full snapshot**. MDX and the [Power BI reports](4_SSAS/README.md) use the reconciled SQL row values. The Browser screenshots show each analysis running against the cube. Use the separate [subset references](2_Dataset/INTEGRATION_SUBSET.md) for the four-order test.

| Question and comparison | SQL reference | SSAS manual | Power BI | MDX |
| --- | --- | --- | --- | --- |
| Q1 Revenue and orders by year/quarter | [Q1–Q5](3_SSIS/sql/reference_questions_01_05_results.txt) | [Browser](4_SSAS/SSAS_Project/Q01%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q01.csv) |
| Q2 Top 10 categories by revenue | [Q1–Q5](3_SSIS/sql/reference_questions_01_05_results.txt) | [Browser](4_SSAS/SSAS_Project/Q02%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q02.csv) |
| Q3 Top 5 customer states | [Q1–Q5](3_SSIS/sql/reference_questions_01_05_results.txt) | [Browser](4_SSAS/SSAS_Project/Q03%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q03.csv) |
| Q4 Payment amount and share | [Q1–Q5](3_SSIS/sql/reference_questions_01_05_results.txt) | [Browser](4_SSAS/SSAS_Project/Q04%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q04.csv) |
| Q5 Monthly revenue and growth in 2017 | [Q1–Q5](3_SSIS/sql/reference_questions_01_05_results.txt) | [Browser](4_SSAS/SSAS_Project/Q05%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q05.csv) |
| Q6 Category review averages, minimum 100 reviews | [Q6 and Q8](3_SSIS/sql/reference_questions_06_08_results.txt) | [Browser](4_SSAS/SSAS_Project/Q06%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q06.csv) |
| Q7 Delivery and late rates by state | [Q7, Q9, Q10](3_SSIS/sql/reference_questions_07_09_10_results.txt) | [Browser](4_SSAS/SSAS_Project/Q07%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q07.csv) |
| Q8 Top 10 sellers and order reviews | [Q6 and Q8](3_SSIS/sql/reference_questions_06_08_results.txt) | [Browser](4_SSAS/SSAS_Project/Q08%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q08.csv) |
| Q9 Freight ratio by region, January–August | [Q7, Q9, Q10](3_SSIS/sql/reference_questions_07_09_10_results.txt) | [Browser](4_SSAS/SSAS_Project/Q09%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q09.csv) |
| Q10 Payment by weekday and method | [Q7, Q9, Q10](3_SSIS/sql/reference_questions_07_09_10_results.txt) | [Browser](4_SSAS/SSAS_Project/Q10%20Browser%20Evidence.png) | Snapshot verified | [Verified](4_SSAS/MDX/results/Q10.csv) |

For each completed cell, replace `Pending` with an evidence link and record any additional filters, sort order, and discrepancies. The SQL files contain the exact definitions and ordering. Reconcile at least three selected Excel Pivot analyses separately and link the workbook and results here when available.

1. **A → B:** A provides the same CSV snapshot, source, and retrieval instructions; Kiet confirms access.
2. **A + B:** record the 10-question specification, schema, and measure definitions before ETL and cube work split. Resolve order/item counting, reviews and delivery metrics, multi-seller orders, and multiple payment methods.
3. **A → B:** the project owner hands over the validated warehouse, schema, connection steps, and reconciliations to Kiet for cube construction.
4. **B → A:** Kiet hands over the processed cube, metadata, connection steps, and sample results for Pivot and MDX work.
5. **A + B:** reconcile all 10 SSAS, Power BI, and MDX results; explain differences caused by filters, grain, or rounding. Reconcile the selected Pivot analyses too. Collect actual screenshots and results as each part is completed.
6. **A + B:** both provide report content, figures, and actual results. The project owner assembles; Kiet cross-reviews. Check the six submission folders, DOCX/PDF page limit, Drive link, and instructor access. Video is optional after required work.

Git holds source and project documentation; Drive holds the dataset, videos, and submission package. Only one person should edit DOCX, PBIX, or Excel at a time; agree on the current version location. Do not commit passwords or machine-specific connection settings.
