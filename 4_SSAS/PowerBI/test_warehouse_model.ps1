param(
    [Parameter(Mandatory=$true)][int]$Port,
    [switch]$CheckProjectMeasures,
    [string]$ClientDirectory = 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\SSAS'
)
$ErrorActionPreference = 'Stop'
[void][Reflection.Assembly]::LoadFrom("$ClientDirectory\Microsoft.AnalysisServices.AdomdClient.dll")
$cx = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$Port")
$groups = @(
    @('DimDate[Year]', 'DimDate[Quarter]'), @('DimProduct[CategoryEnglish]'), @('DimCustomer[State]'),
    @('DimPayment[PaymentType]'), @('DimDate[MonthLabel]'), @('DimProduct[CategoryEnglish]'),
    @('DimCustomer[State]'), @('DimSeller[SellerID]', 'DimSeller[State]'),
    @('DimDate[Year]', 'DimCustomer[Region]'), @('DimDate[ISOWeekdayName]', 'DimPayment[PaymentType]')
)
$measureNames = @{
    'Order Count' = 'Sales Orders'
    'Quantity' = 'Item Quantity'
    'Avg Review' = 'Matching Avg Review'
    'Review Count' = 'Matching Reviews'
}
$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$definitions = ''
if ($CheckProjectMeasures) {
    $project = Get-Content "$PSScriptRoot\Olist Warehouse.SemanticModel\model.bim" -Raw | ConvertFrom-Json
    $declarations = foreach ($table in $project.model.tables) {
        foreach ($measure in $table.measures) { "MEASURE '$($table.name)'[$($measure.name)] = $($measure.expression)" }
    }
    $definitions = "DEFINE`n" + ($declarations -join "`n") + "`n"
}
function ReadRows($dax) {
    $cmd=$cx.CreateCommand(); $cmd.CommandText=$definitions + $dax
    $r=$cmd.ExecuteReader()
    try {
        while($r.Read()) {
            $values=New-Object object[] $r.FieldCount
            [void]$r.GetValues($values)
            ,$values
        }
    } finally { $r.Dispose(); $cmd.Dispose() }
}
try {
    $cx.Open()
    for($i=0;$i -lt 10;$i++) {
        $id='Q{0:00}' -f ($i+1)
        $expected=@(Import-Csv "$PSScriptRoot\..\MDX\results\$id.csv")
        $metrics=@($expected[0].PSObject.Properties.Name | Where-Object {$_ -notmatch '^(Member|Key)'})
        $fields=$groups[$i]
        $select=for($m=0;$m -lt $metrics.Count;$m++) {
            $name=$metrics[$m]
            if($id -in @('Q06','Q08') -and $name -eq 'Order Count'){ $name='Matching Orders' }
            elseif($measureNames.ContainsKey($name)){ $name=$measureNames[$name] }
            '"v{0}", [{1} {2}]' -f $m,$id,$name
        }
        $actual=@{}
        foreach($row in @(ReadRows ("EVALUATE SUMMARIZECOLUMNS(" + (($fields + $select) -join ', ') + ")"))) {
            if($id -eq 'Q01'){ $key=([string]$row[0])+([string]$row[1]); $firstMeasure=2 }
            else { $key=($row[0..($fields.Count-1)] -join '|'); $firstMeasure=$fields.Count }
            $actual[$key]=@($row[$firstMeasure..($row.Count-1)])
        }
        if($id -eq 'Q01'){
            foreach($row in @(ReadRows 'EVALUATE SUMMARIZECOLUMNS(DimDate[Year], "Rev", [Revenue], "Orders", [Sales Orders])')){
                $actual[[string]$row[0]]=@($row[1],$row[2])
            }
        }
        if($actual.Count -ne $expected.Count){throw "$id returned $($actual.Count) rows, expected $($expected.Count)"}
        foreach($row in $expected){
            $key=if($fields.Count -eq 2 -and $id -ne 'Q01'){
                $row.Member0+'|'+$row.Member1
            } else { $row.Member0 }
            if(!$actual.ContainsKey($key)){throw "$id missing $key"}
            for($m=0;$m -lt $metrics.Count;$m++){
                $value=$row.($metrics[$m])
                $got=$actual[$key][$m]
                if($value -eq '') { if($got -ne [DBNull]::Value){throw "$id expected a blank for $key"} }
                elseif($got -eq [DBNull]::Value -or [math]::Abs([double]$got-[double]::Parse($value,$invariant)) -gt 0.000001){
                    throw "$id $key $($metrics[$m]) differs: $got versus $value"
                }
            }
        }
        Write-Output "$id matched $($expected.Count) rows from the SSAS exports."
        if($id -eq 'Q02'){
            $total = @(ReadRows 'EVALUATE ROW("Revenue", [Q02 Revenue], "Quantity", [Q02 Item Quantity])')[0]
            for($m=0;$m -lt $metrics.Count;$m++){
                $expectedSum=0
                foreach($row in $expected){$expectedSum += [decimal]::Parse($row.($metrics[$m]),$invariant)}
                if([decimal]$total[$m] -ne $expectedSum){
                    throw "Q02 displayed total for $($metrics[$m]) differs: $($total[$m]) versus $expectedSum"
                }
            }
            Write-Output 'Q02 totals match the ten displayed categories.'
        }
    }
} finally { $cx.Dispose() }
