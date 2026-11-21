# Olist warehouse and ETL

The SQL scripts create the warehouse, eight typed staging tables, and a transactional staging-to-warehouse load procedure. `OlistETL.slnx` targets SQL Server 2025 and contains two alternative packages for the same full-data warehouse. Choose one package for a refresh; they are two ways to perform the ETL, not consecutive steps. `OlistNativeETL.dtsx` loads the eight CSVs and then the dimensions and facts with SSIS Data Flows. `OlistETL.dtsx` uses the Python importer for staging and sqlcmd to run the warehouse procedure.

The native package built and ran successfully in the Visual Studio 18.11.2 debugger against the local full-data database, `OlistDW_Test`. The full-snapshot, source-reconciliation, and category/seller checks passed afterward. A temporary runtime copy also loaded an isolated database; all eight staging tables matched the earlier full-data staging tables in both directions and by row count. A second isolated run succeeded; an invalid payment row failed and rolled back, preserving the previous warehouse totals. The temporary verification database has since been removed. Execution on another machine remains unverified. Visual Studio crashed after the successful run when opening the Data Flow selector; the control flow and Orders Data Flow rendered before the crash.

## Native package setup

1. Create an empty target database and run `sql/01_warehouse.sql` and `sql/02_staging.sql` against it. The native package uses the tables from those scripts; it does not call the procedure in `sql/03_load_warehouse.sql`.
2. Open `OlistETL.slnx` with the SSIS extension. In `OlistNativeETL.dtsx`, configure the `Olist Warehouse` OLE DB connection for the target database and the eight named CSV connection managers for the local `2_Dataset/raw` folder. The saved values currently point to this machine and the full-data database `OlistDW_Test`; update them before running elsewhere.
3. Ensure Microsoft Distributed Transaction Coordinator (MSDTC) is running. The package requires a transaction so a failure rolls back staging and warehouse changes. A successful run replaces both staging and warehouse data; use a database intended for this project and retain a backup.
4. Execute the native package and run `sql/test_full_snapshot.sql`, `sql/test_source_reconciliation.sql`, and `sql/test_group_reconciliation.sql` against the target. Reprocess dependent SSAS objects after a successful reload because surrogate keys can change.

The control flow prepares staging, loads Orders, Customers, Products, Category Translation, Sellers, Order Items, Payments, and Reviews, validates the staged relationships, prepares the warehouse, then loads six dimensions and three facts. Each CSV has a Flat File Source, conversion steps, and an OLE DB Destination. Warehouse Data Flows use OLE DB source queries to apply the existing business rules and OLE DB destinations to populate their tables. Errors stop the run; a separate rejected-row file is not produced.

## Python and sqlcmd alternative package

A temporary configured copy of `OlistETL.dtsx` completed the four-order subset and two consecutive full-snapshot runs in Visual Studio. Both tasks reported success in each full run; full-snapshot totals, staging reconciliation, and category/seller checks passed in an isolated database. Execution on another machine remains unverified. Standalone SSIS 13 DTExec reported that Standard Edition or higher is required outside SQL Server Data Tools; SSIS 17 DTExec could not load the Execute Process Task.

Before running the package, configure the `User::PythonExecutable`, `User::ImportArguments`, `User::SqlcmdExecutable`, and `User::SqlcmdArguments` variables in the SSIS designer. Use an absolute Python executable path and an import argument string containing the absolute `import_staging.py` and data-directory paths plus explicit `--server` and `--database` values. Set `SqlcmdExecutable` to the installed sqlcmd path and use sqlcmd arguments with `-b` and `-Q "EXEC dbo.LoadOlistWarehouse"` for the same target database. The saved variables in this local package currently point to this machine’s full dataset folder and `OlistDW_Test`. Update them for the intended machine before running. To run the four-order subset instead, change both argument strings to the same subset folder and an isolated subset database. First validate against an isolated test database; runtime and edition compatibility must be verified on the executing machine.

Run the scripts against a new empty SQL Server database. They create objects in that database and intentionally fail on a second schema installation rather than deleting existing data.

```powershell
sqlcmd -S <server> -E -C -b -d <new-empty-database> -i 3_SSIS/sql/01_warehouse.sql
sqlcmd -S <server> -E -C -b -d <new-empty-database> -i 3_SSIS/sql/02_staging.sql
sqlcmd -S <server> -E -C -b -d <new-empty-database> -i 3_SSIS/sql/03_load_warehouse.sql
sqlcmd -S <server> -E -C -b -d <new-empty-database> -i 3_SSIS/sql/test_schema.sql
sqlcmd -S <server> -E -C -b -d <new-empty-database> -i 3_SSIS/sql/test_staging.sql
```

### Configure the package for the subset

1. Extract the checked archive and create the four-order CSVs using [the subset instructions](../2_Dataset/INTEGRATION_SUBSET.md). Install Python dependencies from `3_SSIS/requirements.txt` and ensure ODBC Driver 17 and `sqlcmd` are available.
2. Create a new, empty test database and run the three installation scripts above against it. Do not select an existing lab database: a successful package run replaces staging and warehouse data in the target.
3. Open `OlistETL.slnx` in Visual Studio with the Integration Services extension, open `OlistETL.dtsx`, and edit the four package variables in the Variables window. Replace every placeholder below with a path or name on the executing machine. These are variable values, not PowerShell commands.

| Variable | Example value |
| --- | --- |
| `PythonExecutable` | `C:\path\to\python.exe` |
| `ImportArguments` | `"C:\path\to\repo\3_SSIS\import_staging.py" --data "C:\path\to\subset" --server "localhost" --database "OlistDW_Subset_Test"` |
| `SqlcmdExecutable` | `C:\path\to\sqlcmd.exe` |
| `SqlcmdArguments` | `-S "localhost" -E -C -b -d "OlistDW_Subset_Test" -Q "EXEC dbo.LoadOlistWarehouse"` |

4. Check that both argument strings name the same server and database, then right-click the package under SSIS Packages and select Execute Package. After it succeeds, run `sqlcmd -S <server> -E -C -b -d <test-database> -i 3_SSIS/sql/test_subset.sql` from the repository root and compare Q4, category, and seller results with the subset handoff. Repeat on the other machine and record the actual outcomes. Do not commit the local variable values.

The subset run succeeded in the local designer using a temporary copy; the portable setup and execution still need verification on the other machine.

The repository package currently retains machine-specific configuration, so each teammate must set their own paths and target database before running it.

A separate local failure-path check used a nonexistent input directory against the isolated subset database. The import task and package reported failure, while the warehouse task did not execute. Existing order keys and subset totals remained unchanged. This checks the missing-directory case; other failure modes still need their own evidence.

Another temporary-package check imported the subset successfully and then ran a SQL command that introduced a missing product inside a transaction before invoking the load procedure. The warehouse task and package reported failure. The same SQL command returned error 50301 when run directly, and the injected staging change rolled back; the existing warehouse keys and subset totals remained unchanged. The staging import committed before the warehouse attempt, as described below.

The staging tables store the columns needed by the agreed design. Product descriptive fields and review comments are intentionally omitted. The SSIS project must account for rejected rows and preserve business keys and source timestamps. The Python staging importer below uses explicit CSV column mapping and a single transaction. It was run on the full checked snapshot in the isolated test database; it is not an SSIS package. A malformed final Reviews CSV row was also tested after earlier tables had been replaced within the transaction. The import failed and the pre-existing staging Orders count remained 99,441, confirming rollback for that scenario.

## Data selection and transformation for the report

Eight CSVs provide orders, customers, items, products, category translations, sellers, payments, and reviews. Geolocation, product descriptive attributes, and review text are outside the current analysis. The load selects orders with at least one item and excludes statuses `canceled` and `unavailable`; other statuses remain in scope. The checked snapshot yields 98,199 orders and 112,101 item rows. Purchase date is the shared analysis date.

The warehouse keeps sales at item grain, payments at payment-row grain, and delivery and review measures at order grain. This prevents multiple payment or review rows from multiplying sales. The latest review is selected using creation time, answer time, review ID, and score as descending tie-breakers; an order without a review retains a null score. Product category uses the English translation when present, otherwise the original category or `Unknown`. Brazilian state codes are mapped to regions, with unrecognized codes assigned `Unknown`.

Missing required customer, product, or seller references and orphan items, payments, or reviews abort the warehouse transaction. The importer also aborts and rolls back on malformed rows. It currently reports the failure rather than producing a separate rejected-row file with counts and amounts; that part of the agreed handoff remains open. Staging replacement and warehouse replacement are separate transactions, so a failed warehouse load can leave new staging data alongside the previous warehouse.

For lookup or orphan failures, run `sqlcmd -S <server> -E -C -b -d <database> -i 3_SSIS/sql/diagnose_load.sql` to list affected keys and totals by reason. An item with both a missing product and seller appears under both reasons; do not add those totals together. This diagnostic reads the current staging tables, so it cannot recover a malformed CSV row from an import that rolled back.

```powershell
python -m pip install -r 3_SSIS/requirements.txt
python 3_SSIS/import_staging.py --data 2_Dataset/raw --server localhost --database OlistDW_Test
sqlcmd -S localhost -E -C -b -d OlistDW_Test -Q "EXEC dbo.LoadOlistWarehouse"
sqlcmd -S localhost -E -C -b -d OlistDW_Test -i 3_SSIS/sql/test_full_snapshot.sql
```

Change server and database arguments for the intended target. This import replaces all eight staging tables and uses Windows authentication with ODBC Driver 17. `EXEC dbo.LoadOlistWarehouse` replaces warehouse data in a separate transaction and aborts on missing required lookups or orphan item, payment or review rows. The four-order subset tests cover totals and rollback on missing lookups and orphan items. `test_full_snapshot.sql` passed after two consecutive warehouse loads and after the full-snapshot SSIS run. Identity surrogate keys can change after reload, so dependent SSAS structures must be reprocessed after each successful reload.

`sql/reference_questions_01_05.sql` contains SQL reference queries for Lam's five questions. `sql/reference_questions_01_05_results.txt` records their output on the checked full snapshot without report filters. These outputs come from the SQL warehouse, not the SSAS cube. Apply identical filters and definitions when comparing them to SSAS, MDX, or Power BI.

`sql/reference_questions_06_08.sql` supplies the Q6 and Q8 group and overall checks for the first cube checkpoint. It deduplicates order membership within each category or seller and computes seller revenue separately at item grain. `sql/reference_questions_06_08_results.txt` records the full-snapshot output. These are warehouse references, pending reconciliation with the cube.

`sql/reference_questions_07_09_10.sql` covers Q7, Q9, and Q10. Its saved output uses the full snapshot; Q9 applies January through August in both years. Delivery averages and late rates use different eligibility counts, and Q10 retains each payment method. These results also await cube reconciliation.

An independent aggregation of the source CSVs matched the warehouse inputs to these results: delivery counts, eligible counts, delivery-day sums and late counts for all 27 states; revenue and freight for all 10 region/year groups; and payment amounts for all 28 weekday/method groups. Ratios are calculated from these sums and counts; the SSAS and Power BI calculations still require their own checks.

`sql/test_group_reconciliation.sql` compares all category and seller groups to independently aggregated staging data, including order counts, review counts, score sums, and seller revenue. It passed on the full snapshot. A temporary change to a warehouse item price caused the seller check to fail; that change was rolled back. The check starts from staging and does not establish that the CSV import is complete.

`sql/test_source_reconciliation.sql` compares eligible staging rows with warehouse sales, payment, and order rows in both directions, including business keys, selected review scores, delivery days, and late flags. It passed on the full snapshot. A transactional change to a sales price made the check fail, and the subsequent unmodified check passed after rollback. This check compares staging to the warehouse and does not independently verify that staging contains every CSV row.

An independent CSV record count on the checked snapshot matched each staging table: Orders 99,441; Customers 99,441; Products 32,951; CategoryTranslation 71; Sellers 3,095; OrderItems 112,650; Payments 103,886; Reviews 99,224. Counts alone do not verify every field value or detect a substituted row.

Independent sums across the complete CSVs also matched staging: item price BRL 13,591,643.70, freight BRL 2,251,909.54, and payment value BRL 16,008,872.12. These include orders outside the warehouse scope, so they differ from the filtered warehouse totals. Matching sums do not establish row-by-row equality.
