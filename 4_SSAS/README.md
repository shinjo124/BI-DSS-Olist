# Olist cube and analysis deliverables

## Local setup

1. Load the checked dataset with one of the [SSIS packages](../3_SSIS/README.md). The verified full warehouse is `OlistDW_Test`. The four-order warehouse is `OlistDW_Subset_Test`.
2. Use SSAS Multidimensional and Microsoft OLE DB Driver 19 for SQL Server. Give the SSAS processing identity SELECT access to the six dimensions and three facts. See the [local permissions example](SSAS_Project/grant_local_reader.sql).
3. Open [OlistBI.slnx](SSAS_Project/OlistBI.slnx) in Visual Studio with the Analysis Services extension, set the deployment target and data source, and process the cube. Alternatively, run `powershell.exe -NoProfile -File 4_SSAS/SSAS_Project/build_cube.ps1`. The script defaults to `localhost\SSAS2022` and `OlistBI` and accepts server and warehouse parameters. Its `-Replace` switch replaces the named Olist cube, so check the target first.
4. Run `powershell.exe -NoProfile -File 4_SSAS/SSAS_Project/test_cube.ps1` and `powershell.exe -NoProfile -File 4_SSAS/MDX/run_queries.ps1`. Reconcile the CSVs with `.\.venv\Scripts\python -m unittest discover -s 4_SSAS/MDX`. This test uses the local warehouse and full-snapshot SQL references.
5. Open the [Excel workbook](Excel/Olist%20Pivot%20Analyses.xlsx) and refresh its three native PivotTables. Check the cube location under Data > Queries & Connections, or regenerate the workbook with `Excel/build_pivots.ps1` and explicit connection parameters. The [subset workbook](Excel/Olist%20Q4%20Subset.xlsx) points at `OlistBI_Subset`.
6. Open [Olist Warehouse.pbip](PowerBI/Olist%20Warehouse.pbip) in Power BI Desktop. Select **Refresh now** if Desktop requests it, then open **Model view** to see the three fact tables, six dimensions, and 12 relationships. The project embeds selected columns from all warehouse rows, including the keys required for the model. Regenerate it from SQL with `4_SSAS/PowerBI/build_warehouse_report.py`.
7. Open [Olist Live.pbip](PowerBI/Olist%20Live.pbip) for the live cube report. Its default target is `localhost\SSAS2022`, catalog `OlistBI`, cube `Olist`. The published dimensions and measure groups are supplied by SSAS. For a different local or shared instance, regenerate with `4_SSAS/PowerBI/build_live_report.py --server <instance> --catalog <catalog>`.
8. Both projects have ten quiz pages. On Q1, the revenue chart and the quarterly and annual results are together. Detail tables show the rows returned for each quiz.

## Reconciliation evidence

- Full cube grand totals match SQL for orders, revenue, payments and review count. All ten MDX queries and their [saved results](MDX/results/) match independent SQL by row key and measure. All ten warehouse calculations matched when run against the imported Power BI model. Power BI Desktop reported the live SSAS connection as connected and displayed the Q4 payment chart and actual amounts and shares.
- The four-order cube matched overall and group counts, including the category and seller with a missing review. The [subset payment results](MDX/results/subset_Q04.csv) match SQL for each method. The Q4 PivotTables matched method amounts, shares, and totals on both local cubes. Q1 annual orders and Q7 delivery by state matched the full-snapshot PivotTable totals.
- The editable SSAS project built in Visual Studio. The named instance is set in **Project Properties > Deployment > Server** for the Browser. Q4 was built by selecting payment fields in the native designer, and the other nine questions were replayed in its MDX mode. Each Browser result has a screenshot in `SSAS_Project/`. The build emitted dimension and provider recommendations. Local processing succeeded with the specified provider.
- Cross-machine reproduction and instructor Drive access remain open.
