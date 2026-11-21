# First integration subset

Use these four orders from the snapshot identified in [DATASET_PROFILE.md](DATASET_PROFILE.md). Include every associated item, payment, customer, product, seller and review row. Apply the warehouse scope and review selection rules from [WAREHOUSE_DESIGN.md](../WAREHOUSE_DESIGN.md).

To create the eight staging CSVs, run `python 2_Dataset/extract_integration_subset.py --source 2_Dataset/raw --output <new-empty-directory>` from the repository root. The output directory must be empty; a failed extraction can leave partial files, so inspect or remove those files before retrying. Use a separate database for the subset because the importer replaces staging data.

The extracted files were imported into a new isolated local database using the Python importer and SQL load procedure. The subset totals, staging reconciliation, and category/seller checks passed. Missing-product and orphan-item rollback checks passed, and a second warehouse load reproduced the subset totals. A configured temporary SSIS package then ran successfully on the same subset in Visual Studio; the subset and reconciliation checks passed afterward. The second-machine run remains open.

`3_SSIS/sql/test_subset.sql` also checks the payment and category groups below. An injected offset between two payment methods was detected even though the payment grand total was unchanged; the change was rolled back.

| Order ID | Purpose | Items | Price (BRL) | Freight (BRL) | Payment rows | Review score |
| --- | --- | ---: | ---: | ---: | --- | ---: |
| `0016dfedd97fc2950e388d2971d718c7` | Multiple payment types | 1 | 49.75 | 20.80 | voucher 17.92, credit_card 52.63 | 5 |
| `0008288aa423d2a3f00fcb17cd7d8719` | Two items in the same category and seller | 2 | 99.80 | 26.74 | boleto 126.54 | 5 |
| `002f98c0f7efd42638ed6100ca699b42` | Multiple categories and sellers | 2 | 53.89 | 39.73 | credit_card 93.62 | 5 |
| `00143d0f86d6fbd9f9b38ab440ac16f5` | No review | 3 | 63.99 | 45.30 | credit_card 109.29 | NULL |

All four have status `delivered`. Independent CSV checks yield **4 orders, 8 items, 5 payment rows, revenue BRL 267.43, freight BRL 132.57, payment amount BRL 400.00, 3 reviewed orders, review-score sum 15, and average review 5.0**. Do not replace these subset totals with the full-snapshot targets. These are source checks, not results from SSIS or SSAS.

## Warehouse reference for the first cube checks

The following results were queried from the full warehouse with its order dimension restricted to these four IDs. They are SQL references and have not yet been reconciled with SSAS.

| Payment type | Amount BRL | Share |
| --- | ---: | ---: |
| boleto | 126.54 | 31.635% |
| credit_card | 255.54 | 63.885% |
| voucher | 17.92 | 4.480% |

| Category | Orders | Reviewed orders | Average review |
| --- | ---: | ---: | ---: |
| consoles_games | 1 | 1 | 5.0 |
| garden_tools | 2 | 2 | 5.0 |
| sports_leisure | 1 | 0 | NULL |
| toys | 1 | 1 | 5.0 |

| Seller ID | Orders | Reviewed orders | Average review |
| --- | ---: | ---: | ---: |
| `1f50f920176fa81dab994f9023523100` | 1 | 1 | 5.0 |
| `7299e27ed73d2ad986de7f7c77d919fa` | 1 | 1 | 5.0 |
| `a17f621c590ea0fab3d5d883e1630ec6` | 1 | 0 | NULL |
| `a35124e2d763d7ca3fbe3b97d143200f` | 1 | 1 | 5.0 |
| `fa40cc5b934574b62717c68f3d678b6d` | 1 | 1 | 5.0 |

Category and seller groups overlap: their order counts sum to five although the overall count is four. The normal Q6 minimum of 100 reviewed orders is intentionally omitted for this small integration check.
