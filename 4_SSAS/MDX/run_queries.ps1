param(
    [string]$Server = 'localhost\SSAS2022',
    [string]$Database = 'OlistBI',
    [string]$OutputDirectory = "$PSScriptRoot\results",
    [string]$ClientDirectory = 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\SSAS'
)
$ErrorActionPreference = 'Stop'
[void][Reflection.Assembly]::LoadFrom("$ClientDirectory\Microsoft.AnalysisServices.AdomdClient.dll")
$connection = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=$Server;Initial Catalog=$Database")
try {
    $connection.Open()
    [void](New-Item -ItemType Directory -Force -Path $OutputDirectory)
    foreach ($file in Get-ChildItem "$PSScriptRoot\Q*.mdx" | Sort-Object Name) {
        $command = $connection.CreateCommand(); $command.CommandText = Get-Content $file.FullName -Raw
        $cells = $command.ExecuteCellSet()
        $rows = for ($r = 0; $r -lt $cells.Axes[1].Positions.Count; $r++) {
            $row = [ordered]@{}
            $members = $cells.Axes[1].Positions[$r].Members
            for ($m = 0; $m -lt $members.Count; $m++) {
                $row["Member$m"] = $members[$m].Caption
                $row["Key$m"] = $members[$m].UniqueName
            }
            for ($c = 0; $c -lt $cells.Axes[0].Positions.Count; $c++) {
                $value = $cells.Cells[$c,$r].Value
                if ($value -is [Exception]) { throw $value }
                $row[$cells.Axes[0].Positions[$c].Members[0].Caption] = $value
            }
            [pscustomobject]$row
        }
        $rows | Export-Csv "$OutputDirectory\$($file.BaseName).csv" -NoTypeInformation -Encoding UTF8
        Write-Output "$($file.BaseName): $(@($rows).Count) rows"
    }
} finally { $connection.Dispose() }
