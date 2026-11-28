param(
    [string]$SqlServer = 'localhost',
    [string]$Warehouse = 'OlistDW_Test',
    [string]$AnalysisServer = 'localhost\SSAS2022',
    [string]$Database = 'OlistBI',
    [string]$ClientDirectory = 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\SSAS',
    [switch]$Replace
)
$ErrorActionPreference = 'Stop'
[void][Reflection.Assembly]::LoadFrom("$ClientDirectory\Microsoft.AnalysisServices.Core.dll")
[void][Reflection.Assembly]::LoadFrom("$ClientDirectory\Microsoft.AnalysisServices.dll")
$server = New-Object Microsoft.AnalysisServices.Server
$server.Connect($AnalysisServer)
if ($Database -notlike 'OlistBI*') { throw 'Target must start with OlistBI to protect unrelated databases.' }
if ($server.Databases.Contains($Database)) {
    if (!$Replace) { throw 'Database exists. Use -Replace only for an intended OlistBI rebuild.' }
    $server.Databases[$Database].Drop()
}
$db = $server.Databases.Add($Database, $Database)
$db.CompatibilityLevel = 1100
$source = $db.DataSources.Add('Warehouse', 'Warehouse')
$source.ConnectionString = "Provider=MSOLEDBSQL19.1;Data Source=$SqlServer;Initial Catalog=$Warehouse;Integrated Security=SSPI;Use Encryption for Data=Optional;Trust Server Certificate=True"
$source.ImpersonationInfo = New-Object Microsoft.AnalysisServices.ImpersonationInfo
$source.ImpersonationInfo.ImpersonationMode = 'ImpersonateServiceAccount'
$view = $db.DataSourceViews.Add('Warehouse', 'Warehouse')
$view.DataSourceID = $source.ID
$schema = New-Object System.Data.DataSet 'Warehouse'
$sql = New-Object System.Data.SqlClient.SqlConnection("Server=$SqlServer;Database=$Warehouse;Integrated Security=True;TrustServerCertificate=True")
$queries = [ordered]@{
    DimDate = 'SELECT *, [Year]*10+[Quarter] AS YearQuarter, [Year]*100+[Month] AS YearMonth, CONVERT(varchar(7),FullDate,120) AS MonthLabel FROM dbo.DimDate'
    DimCustomer = 'SELECT * FROM dbo.DimCustomer'
    DimProduct = 'SELECT * FROM dbo.DimProduct'
    DimSeller = 'SELECT * FROM dbo.DimSeller'
    DimPayment = 'SELECT * FROM dbo.DimPayment'
    DimOrder = 'SELECT * FROM dbo.DimOrder'
    FactSales = 'SELECT * FROM dbo.FactSales'
    FactOrder = 'SELECT OrderKey,DateKey,CustomerKey,CAST(1 AS int) AS OrderCount,CAST(ReviewScore AS int) AS ReviewScore,CAST(ReviewPresent AS int) AS ReviewPresent,DeliveryDays,CAST(DeliveredFlag AS int) AS DeliveredFlag,CAST(LateFlag AS int) AS LateFlag,CAST(LateEligibleFlag AS int) AS LateEligibleFlag FROM dbo.FactOrder'
    FactPayment = 'SELECT * FROM dbo.FactPayment'
}
foreach ($name in $queries.Keys) {
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter("$($queries[$name]) WHERE 1=0", $sql)
    [void]$adapter.FillSchema($schema, [System.Data.SchemaType]::Source, $name)
    $table = $schema.Tables[$name]
    $table.ExtendedProperties['TableType'] = 'View'
    $table.ExtendedProperties['QueryDefinition'] = $queries[$name]
    $table.ExtendedProperties['FriendlyName'] = $name
}
function DataItem($table, $column) {
    $item = New-Object Microsoft.AnalysisServices.DataItem
    $item.Source = New-Object Microsoft.AnalysisServices.ColumnBinding($table, $column)
    $type = $schema.Tables[$table].Columns[$column].DataType.Name
    $item.DataType = switch ($type) {
        'Int16' { 'SmallInt' }; 'Byte' { 'UnsignedTinyInt' }; 'Int32' { 'Integer' }
        'Decimal' { 'Currency' }; 'DateTime' { 'Date' }; default { 'WChar' }
    }
    if ($item.DataType -eq 'WChar') { $item.DataSize = 200 }
    $item.NullProcessing = 'ZeroOrBlank'
    return $item
}
function Attribute($dim, $name, $keys, $caption) {
    $attr = $dim.Attributes.Add($name, $name)
    $attr.OrderBy = 'Key'
    foreach ($key in $keys) { [void]$attr.KeyColumns.Add((DataItem ('Dim' + $dim.ID) $key)) }
    if ($caption) {
        $attr.NameColumn = DataItem ('Dim' + $dim.ID) $caption
        $attr.NameColumn.DataType = 'WChar'; $attr.NameColumn.DataSize = 200
    }
    return $attr
}
function Dimension($name, $table, $key, $caption, $attributes) {
    $dim = $db.Dimensions.Add($name, $name)
    $dim.Source = New-Object Microsoft.AnalysisServices.DataSourceViewBinding($view.ID)
    $root = Attribute $dim $name @($key) $caption
    $root.Usage = 'Key'
    foreach ($entry in $attributes) {
        $attr = Attribute $dim $entry[0] $entry[1] $entry[2]
        [void]$root.AttributeRelationships.Add($attr.ID)
    }
    return $dim
}
$date = Dimension 'Date' 'DimDate' 'DateKey' 'FullDate' @(
    @('Year', @('Year'), $null), @('Quarter', @('YearQuarter'), $null),
    @('Month', @('YearMonth'), 'MonthLabel'), @('Month Number', @('Month'), $null),
    @('Weekday', @('ISOWeekdayNo'), 'ISOWeekdayName'))
$date.Type = 'Time'
$date.Attributes['Date'].Type = 'Date'
$date.Attributes['Year'].Type = 'Years'
$date.Attributes['Quarter'].Type = 'Quarters'
$date.Attributes['Month'].Type = 'Months'
[void]$date.Attributes['Month'].AttributeRelationships.Add('Quarter')
[void]$date.Attributes['Quarter'].AttributeRelationships.Add('Year')
$calendar = $date.Hierarchies.Add('Calendar', 'Calendar')
foreach ($level in @('Year','Quarter','Month','Date')) {
    $l = $calendar.Levels.Add($level, $level); $l.SourceAttributeID = $level
}
$customer = Dimension 'Customer' 'DimCustomer' 'CustomerKey' 'CustomerID' @(
    @('State', @('State'), $null), @('Region', @('Region'), $null), @('City', @('State','City'), 'City'))
$product = Dimension 'Product' 'DimProduct' 'ProductKey' 'ProductID' (,@('Category', @('CategoryEnglish'), $null))
$seller = Dimension 'Seller' 'DimSeller' 'SellerKey' 'SellerID' @(
    @('State', @('State'), $null), @('Region', @('Region'), $null), @('City', @('State','City'), 'City'))
$payment = Dimension 'Payment' 'DimPayment' 'PaymentKey' 'PaymentType' @()
$order = Dimension 'Order' 'DimOrder' 'OrderKey' 'OrderID' @()
$cube = $db.Cubes.Add('Olist', 'Olist')
$cube.Source = New-Object Microsoft.AnalysisServices.DataSourceViewBinding($view.ID)
foreach ($dim in $db.Dimensions) { [void]$cube.Dimensions.Add($dim.ID) }
$cube.Dimensions['Order'].Visible = $false
function MeasureGroup($name, $table, $dimensions, $measures) {
    $group = $cube.MeasureGroups.Add($name, $name)
    $group.StorageMode = 'Molap'
    $group.IgnoreUnrelatedDimensions = $false
    foreach ($entry in $measures) {
        $measure = $group.Measures.Add($entry[0], $entry[0])
        $measure.Source = DataItem $table $entry[1]
        $measure.AggregateFunction = 'Sum'
        $measure.FormatString = $entry[2]
    }
    foreach ($dimName in $dimensions) {
        $key = $dimName + 'Key'
        $link = $schema.Relations.Add("$table-Dim$dimName",
            $schema.Tables["Dim$dimName"].Columns[$key], $schema.Tables[$table].Columns[$key], $false)
        $link.ExtendedProperties['IsLogical'] = 'True'
        $relation = New-Object Microsoft.AnalysisServices.RegularMeasureGroupDimension($dimName)
        [void]$group.Dimensions.Add($relation)
        $attr = $relation.Attributes.Add($dimName)
        $attr.Type = 'Granularity'
        [void]$attr.KeyColumns.Add((DataItem $table $key))
    }
    $partition = $group.Partitions.Add($name, $name)
    $partition.Source = New-Object Microsoft.AnalysisServices.QueryBinding($source.ID, $queries[$table])
    $partition.StorageMode = 'Molap'
    return $group
}
$sales = MeasureGroup 'Sales' 'FactSales' @('Date','Customer','Order','Product','Seller') @(
    @('Revenue','Price','#,##0.00'), @('Freight Value','FreightValue','#,##0.00'), @('Quantity','Quantity','#,##0'))
$orders = MeasureGroup 'Orders' 'FactOrder' @('Date','Customer','Order') @(
    @('Order Count','OrderCount','#,##0'), @('Review Score Sum','ReviewScore','#,##0'), @('Review Count','ReviewPresent','#,##0'),
    @('Delivery Days Sum','DeliveryDays','#,##0'), @('Delivered Count','DeliveredFlag','#,##0'),
    @('Late Count','LateFlag','#,##0'), @('Late Eligible Count','LateEligibleFlag','#,##0'))
$payments = MeasureGroup 'Payments' 'FactPayment' @('Date','Customer','Order','Payment') (,@('Payment Amount','PaymentValue','#,##0.00'))
foreach ($name in @('Product','Seller')) {
    $relation = New-Object Microsoft.AnalysisServices.ManyToManyMeasureGroupDimension
    $relation.CubeDimensionID = $name; $relation.MeasureGroupID = 'Sales'
    [void]$orders.Dimensions.Add($relation)
}
$script = $cube.MdxScripts.Add('Calculations','Calculations')
$command = New-Object Microsoft.AnalysisServices.Command
$command.Text = @'
CALCULATE;
CREATE MEMBER CURRENTCUBE.[Measures].[Avg Review] AS IIF([Measures].[Review Count]=0,NULL,[Measures].[Review Score Sum]/[Measures].[Review Count]), FORMAT_STRING='0.0000', VISIBLE=1;
CREATE MEMBER CURRENTCUBE.[Measures].[Avg Delivery Days] AS IIF([Measures].[Delivered Count]=0,NULL,[Measures].[Delivery Days Sum]/[Measures].[Delivered Count]), FORMAT_STRING='0.00', VISIBLE=1;
CREATE MEMBER CURRENTCUBE.[Measures].[Late Rate] AS IIF([Measures].[Late Eligible Count]=0,NULL,[Measures].[Late Count]/[Measures].[Late Eligible Count]), FORMAT_STRING='0.00%', VISIBLE=1;
CREATE MEMBER CURRENTCUBE.[Measures].[Freight Ratio] AS IIF([Measures].[Revenue]=0,NULL,[Measures].[Freight Value]/[Measures].[Revenue]), FORMAT_STRING='0.00%', VISIBLE=1;
CREATE MEMBER CURRENTCUBE.[Measures].[Avg Order Value] AS IIF([Measures].[Order Count]=0,NULL,[Measures].[Revenue]/[Measures].[Order Count]), FORMAT_STRING='#,##0.00', VISIBLE=1;
CREATE MEMBER CURRENTCUBE.[Measures].[Payment Share] AS IIF(([Measures].[Payment Amount],[Payment].[Payment].[All])=0,NULL,[Measures].[Payment Amount]/([Measures].[Payment Amount],[Payment].[Payment].[All])), FORMAT_STRING='0.000%', VISIBLE=1;
CREATE MEMBER CURRENTCUBE.[Measures].[MoM Growth] AS IIF(IsEmpty(([Measures].[Revenue],[Date].[Calendar].CurrentMember.PrevMember)) OR ([Measures].[Revenue],[Date].[Calendar].CurrentMember.PrevMember)=0,NULL,([Measures].[Revenue]-([Measures].[Revenue],[Date].[Calendar].CurrentMember.PrevMember))/([Measures].[Revenue],[Date].[Calendar].CurrentMember.PrevMember)), FORMAT_STRING='0.00%', VISIBLE=1;
'@
[void]$script.Commands.Add($command)
$view.Schema = $schema
$db.Update([Microsoft.AnalysisServices.UpdateOptions]::ExpandFull)
$db.Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull)
Write-Output "Processed $AnalysisServer / $Database / Olist from $SqlServer / $Warehouse"
$server.Disconnect()
