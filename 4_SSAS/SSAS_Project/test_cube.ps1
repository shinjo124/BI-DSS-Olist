param(
    [string]$Server = 'localhost\SSAS2022',
    [string]$Database = 'OlistBI',
    [string]$ClientDirectory = 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\SSAS'
)
$ErrorActionPreference = 'Stop'
[void][Reflection.Assembly]::LoadFrom("$ClientDirectory\Microsoft.AnalysisServices.AdomdClient.dll")
$connection = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=$Server;Initial Catalog=$Database")
try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = 'SELECT {[Measures].[Order Count], [Measures].[Revenue], [Measures].[Payment Amount], [Measures].[Review Count]} ON 0 FROM [Olist]'
    $cells = $command.ExecuteCellSet()
    $expected = if ($Database -eq 'OlistBI_Subset') { @(4, 267.43, 400, 3) }
                else { @(98199, 13494400.74, 15738221.95, 97467) }
    for ($i = 0; $i -lt $expected.Count; $i++) {
        $actual = [decimal]$cells.Cells[$i].Value
        if ([math]::Abs($actual - $expected[$i]) -gt 0.000001) {
            throw "Grand total $i expected $($expected[$i]), got $actual"
        }
    }
    Write-Output "PASS: $Database cube order, revenue, payment and review totals."
    if ($Database -eq 'OlistBI_Subset') {
        $expectedGroups = [ordered]@{
            Product=@{consoles_games=@(1,1); garden_tools=@(2,2); sports_leisure=@(1,0); toys=@(1,1)}
            Seller=@{'1f50f920176fa81dab994f9023523100'=@(1,1); '7299e27ed73d2ad986de7f7c77d919fa'=@(1,1)
                     'a17f621c590ea0fab3d5d883e1630ec6'=@(1,0); 'a35124e2d763d7ca3fbe3b97d143200f'=@(1,1)
                     'fa40cc5b934574b62717c68f3d678b6d'=@(1,1)}
        }
        foreach ($group in $expectedGroups.Keys) {
            $attribute = if ($group -eq 'Product') { 'Category' } else { 'Seller' }
            $command.CommandText = "SELECT {[Measures].[Order Count], [Measures].[Review Count], [Measures].[Avg Review]} ON 0, NonEmpty([$group].[$attribute].[$attribute].Members,[Measures].[Order Count]) ON 1 FROM [Olist]"
            $cells = $command.ExecuteCellSet()
            $expectedMembers = $expectedGroups[$group]
            if ($cells.Axes[1].Positions.Count -ne $expectedMembers.Count) { throw "Wrong $group group count" }
            for ($i=0; $i -lt $cells.Axes[1].Positions.Count; $i++) {
                $name = $cells.Axes[1].Positions[$i].Members[0].Caption
                $expectedGroup = $expectedMembers[$name]
                $average = $cells.Cells[2,$i].Value
                if (!$expectedGroup -or $cells.Cells[0,$i].Value -ne $expectedGroup[0] -or
                    [int]$cells.Cells[1,$i].Value -ne $expectedGroup[1] -or
                    ($expectedGroup[1] -and $average -ne 5) -or
                    (!$expectedGroup[1] -and $null -ne $average)) { throw "Wrong $group counts or average for $name" }
            }
        }
        Write-Output 'PASS: category and seller counts deduplicate within each subset group and preserve the overall count.'
    }
} finally { $connection.Dispose() }
