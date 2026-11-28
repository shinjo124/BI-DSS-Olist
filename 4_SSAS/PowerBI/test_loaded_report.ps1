param(
    [Parameter(Mandatory=$true)][int]$Port,
    [string]$ClientDirectory = 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\SSAS'
)
$ErrorActionPreference = 'Stop'
[void][Reflection.Assembly]::LoadFrom("$ClientDirectory\Microsoft.AnalysisServices.AdomdClient.dll")
$connection = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$Port")
try {
    $connection.Open()
    $command = $connection.CreateCommand()
    for ($q=1; $q -le 10; $q++) {
        $name = 'Q{0:00}' -f $q
        $rows = @(Import-Csv "$PSScriptRoot\..\MDX\results\$name.csv")
        $command.CommandText = "EVALUATE '$name' ORDER BY '$name'[Row]"
        $reader = $command.ExecuteReader()
        try {
            foreach ($row in $rows) {
                if (!$reader.Read()) { throw "$name is missing rows" }
                $cols = $row.psobject.Properties | Where-Object Name -NotLike 'Key*'
                $i = 1
                foreach ($col in $cols) {
                    $actual = $reader.GetValue($i)
                    if ($col.Name -like 'Member*') {
                        $expected = $col.Value
                        if ($q -eq 1 -and $expected.Length -eq 5) {
                            $expected = $expected.Substring(0,4) + ' Q' + $expected[4]
                        }
                        if ($actual -cne $expected) { throw "$name group mismatch: $actual / $expected" }
                    } elseif ($col.Value -eq '') {
                        if (!$reader.IsDBNull($i)) { throw "$name expected an empty $($col.Name)" }
                    } elseif ([math]::Abs([double]$actual - [double]$col.Value) -gt 0.000001) {
                        throw "$name value mismatch for $($col.Name): $actual / $($col.Value)"
                    }
                    $i++
                }
            }
            if ($reader.Read()) { throw "$name has extra rows" }
            Write-Output "$name Power BI rows match SSAS ($($rows.Count))."
        } finally { $reader.Dispose() }
    }
} finally { $connection.Dispose() }
