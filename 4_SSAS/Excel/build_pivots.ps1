param(
    [string]$Server = 'localhost\SSAS2022',
    [string]$Database = 'OlistBI',
    [string]$Output = "$PSScriptRoot\Olist Pivot Analyses.xlsx"
)
$ErrorActionPreference = 'Stop'
$excel = New-Object -ComObject Excel.Application
$excel.DisplayAlerts = $false
try {
    $book = $excel.Workbooks.Add(-4167)
    $specs = @(
        @{Name='Payment share'; Hierarchy='[Payment].[Payment]'; Measures=@('Payment Amount','Payment Share'); Total=15738221.95},
        @{Name='Annual orders'; Hierarchy='[Date].[Year]'; Measures=@('Order Count','Revenue'); Total=98199},
        @{Name='Delivery by state'; Hierarchy='[Customer].[State]'; Measures=@('Delivered Count','Avg Delivery Days','Late Rate'); Total=96470}
    )
    if ($Database -eq 'OlistBI_Subset') {
        $specs = @($specs[0])
        $specs[0].Total = 400.00
    }
    for ($i=0; $i -lt $specs.Count; $i++) {
        $spec = $specs[$i]
        if ($i -eq 0) { $sheet = $book.Worksheets.Item(1) }
        else { $sheet = $book.Worksheets.Add([Type]::Missing,$book.Worksheets.Item($i)) }
        $sheet.Name = $spec.Name
        $sheet.Range('A1').Value2 = $spec.Name
        $sheet.Range('A1').Font.Size = 20
        $sheet.Range('A1').Font.Bold = $true
        $sheet.Range('A2').Value2 = 'Olist warehouse snapshot | live Analysis Services connection'
        $sheet.Activate()
        $cache = $book.PivotCaches().Create(2)
        $cache.Connection = "OLEDB;Provider=MSOLAP;Data Source=$Server;Initial Catalog=$Database;Integrated Security=SSPI;"
        $cache.CommandType = 1
        $cache.CommandText = 'Olist'
        $pivot = $cache.CreatePivotTable($sheet.Range('A4'), "OlistPivot$($i+1)")
        $pivot.CubeFields.Item($spec.Hierarchy).Orientation = 1
        foreach ($name in $spec.Measures) {
            [void]$pivot.AddDataField($pivot.CubeFields.Item("[Measures].[$name]"))
        }
        [void]$pivot.RefreshTable()
        $result = $pivot.TableRange1
        $total = $result.Cells.Item($result.Rows.Count,2).Value2
        if ([math]::Abs([double]$total - $spec.Total) -gt 0.000001) {
            throw "$($spec.Name) total should be $($spec.Total), got $total"
        }
        if ($spec.Name -eq 'Payment share') {
            $expected = if ($Database -eq 'OlistBI_Subset') {
                @{credit_card=255.54; boleto=126.54; voucher=17.92}
            } else {
                @{credit_card=12349453.71; boleto=2826476.09; voucher=349874.40; debit_card=212417.75}
            }
            $seen = @{}
            $firstDataRow = $pivot.DataBodyRange.Row - $result.Row + 1
            for ($row = $firstDataRow; $row -lt $result.Rows.Count; $row++) {
                $method = $result.Cells.Item($row,1).Value2
                if (!$expected.ContainsKey($method)) { throw "Unexpected payment method $method" }
                $amount = $result.Cells.Item($row,2).Value2
                $share = $result.Cells.Item($row,3).Value2
                if ([math]::Abs($amount - $expected[$method]) -gt 0.000001 -or
                    [math]::Abs($share - $expected[$method]/$spec.Total) -gt 0.000001) {
                    throw "Payment amount or share differs for $method"
                }
                $seen[$method] = $true
            }
            if ($seen.Count -ne $expected.Count) { throw 'One or more payment methods are missing' }
        }
        $sheet.Columns.Item(1).ColumnWidth = 30
        $sheet.Range('B:D').ColumnWidth = 20
        Write-Output "$($spec.Name): $total (matched reference)"
    }
    $book.Worksheets.Item(1).Activate()
    $book.SaveAs($Output,51)
    $book.Close($false)
} finally { $excel.Quit() }
