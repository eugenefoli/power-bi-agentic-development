# TOM Object Types -- Full CRUD Reference

Complete create, read, update, and delete examples for every TOM object type accessible via Power BI Desktop's local Analysis Services instance.

All examples assume `$model` is already connected (see SKILL.md section 3).


## Tables

### Create

```powershell
$table = New-Object Microsoft.AnalysisServices.Tabular.Table
$table.Name = "NewTable"

# Tables need at least one partition (data source)
$partition = New-Object Microsoft.AnalysisServices.Tabular.Partition
$partition.Name = "NewTable-Partition"
$partition.Source = New-Object Microsoft.AnalysisServices.Tabular.MPartitionSource
$partition.Source.Expression = 'let Source = #table({"Col1", "Col2"}, {{"a", 1}}) in Source'
$table.Partitions.Add($partition)

$model.Tables.Add($table)
```

### Read

```powershell
# By name
$table = $model.Tables["Sales"]

# All tables
foreach ($t in $model.Tables) {
    Write-Output "[$($t.Name)] Hidden=$($t.IsHidden) Cols=$($t.Columns.Count) Measures=$($t.Measures.Count)"
}

# Filter
$factTables = $model.Tables | Where-Object { -not $_.IsHidden -and $_.Measures.Count -gt 0 }
```

### Update

```powershell
$table.Name = "Renamed Table"
$table.IsHidden = $true
$table.Description = "Archived fact table"
$table.DataCategory = "Time"           # marks as date table
$table.IsPrivate = $true               # hides from field list entirely
```

### Delete

```powershell
$table = $model.Tables["OldTable"]
$model.Tables.Remove($table)
```


## Columns

### Create (Data Column)

```powershell
$col = New-Object Microsoft.AnalysisServices.Tabular.DataColumn
$col.Name = "Region"
$col.DataType = [Microsoft.AnalysisServices.Tabular.DataType]::String
$col.SourceColumn = "region_code"      # maps to source query column
$model.Tables["Sales"].Columns.Add($col)
```

### Create (Calculated Column)

```powershell
$cc = New-Object Microsoft.AnalysisServices.Tabular.CalculatedColumn
$cc.Name = "Full Name"
$cc.Expression = "[FirstName] & "" "" & [LastName]"
$cc.DataType = [Microsoft.AnalysisServices.Tabular.DataType]::String
$model.Tables["Customers"].Columns.Add($cc)
```

### Read

```powershell
$col = $model.Tables["Sales"].Columns["Amount"]

# All columns across all tables
foreach ($t in $model.Tables) {
    foreach ($c in $t.Columns) {
        $type = if ($c -is [Microsoft.AnalysisServices.Tabular.CalculatedColumn]) { "Calc" }
                elseif ($c -is [Microsoft.AnalysisServices.Tabular.DataColumn]) { "Data" }
                else { "Other" }
        Write-Output "[$($t.Name)].[$($c.Name)] $($c.DataType) ($type)"
    }
}
```

### Update

```powershell
$col.Name = "Sales Amount"
$col.DataType = [Microsoft.AnalysisServices.Tabular.DataType]::Decimal
$col.FormatString = "#,0.00"
$col.IsHidden = $true
$col.DisplayFolder = "Financials\Revenue"
$col.Description = "Net sales amount in USD"
$col.SummarizeBy = [Microsoft.AnalysisServices.Tabular.AggregateFunction]::Sum
$col.SortByColumn = $model.Tables["Date"].Columns["MonthNumber"]
```

### Delete

```powershell
$col = $model.Tables["Sales"].Columns["OldColumn"]
$model.Tables["Sales"].Columns.Remove($col)
```


## Measures

### Create

```powershell
$m = New-Object Microsoft.AnalysisServices.Tabular.Measure
$m.Name = "Total Revenue"
$m.Expression = "SUM(Sales[Amount])"
$m.FormatString = "`$#,0.00"
$m.DisplayFolder = "Key Metrics"
$m.Description = "Sum of all sales amounts"
$m.IsHidden = $false
$model.Tables["Sales"].Measures.Add($m)
```

### Create with KPI

```powershell
$m = New-Object Microsoft.AnalysisServices.Tabular.Measure
$m.Name = "Revenue vs Target"
$m.Expression = "DIVIDE([Total Revenue], [Revenue Target])"
$m.FormatString = "0.0%"
$model.Tables["Sales"].Measures.Add($m)

$kpi = New-Object Microsoft.AnalysisServices.Tabular.KPI
$kpi.TargetExpression = "1"
$kpi.StatusExpression = "IF([Revenue vs Target] >= 1, 1, IF([Revenue vs Target] >= 0.8, 0, -1))"
$m.KPI = $kpi
```

### Read

```powershell
$m = $model.Tables["Sales"].Measures["Total Revenue"]
Write-Output "Expression: $($m.Expression)"
Write-Output "Format: $($m.FormatString)"
Write-Output "Folder: $($m.DisplayFolder)"
Write-Output "HasKPI: $($m.KPI -ne $null)"

# All measures across model
foreach ($t in $model.Tables) {
    foreach ($m in $t.Measures) {
        Write-Output "[$($t.Name)].[$($m.Name)] = $($m.Expression)"
    }
}
```

### Update

```powershell
$m.Expression = "CALCULATE(SUM(Sales[Amount]), Sales[Status] = ""Active"")"
$m.FormatString = "#,0"
$m.DisplayFolder = "Revenue"
$m.Description = "Active sales revenue"
```

### Delete

```powershell
$m = $model.Tables["Sales"].Measures["Old Measure"]
$model.Tables["Sales"].Measures.Remove($m)
```


## Relationships

### Create

```powershell
$rel = New-Object Microsoft.AnalysisServices.Tabular.SingleColumnRelationship
$rel.Name = "Sales_Date"
$rel.FromColumn = $model.Tables["Sales"].Columns["DateKey"]
$rel.ToColumn = $model.Tables["Date"].Columns["DateKey"]
$rel.FromCardinality = [Microsoft.AnalysisServices.Tabular.RelationshipEndCardinality]::Many
$rel.ToCardinality = [Microsoft.AnalysisServices.Tabular.RelationshipEndCardinality]::One
$rel.IsActive = $true
$rel.CrossFilteringBehavior = [Microsoft.AnalysisServices.Tabular.CrossFilteringBehavior]::OneDirection
$model.Relationships.Add($rel)
```

### Read

```powershell
foreach ($rel in $model.Relationships) {
    $sr = [Microsoft.AnalysisServices.Tabular.SingleColumnRelationship]$rel
    Write-Output "[$($sr.FromTable.Name)].[$($sr.FromColumn.Name)] -> [$($sr.ToTable.Name)].[$($sr.ToColumn.Name)] Active=$($sr.IsActive) CrossFilter=$($sr.CrossFilteringBehavior)"
}
```

### Update

```powershell
$sr = [Microsoft.AnalysisServices.Tabular.SingleColumnRelationship]$model.Relationships[0]
$sr.IsActive = $false
$sr.CrossFilteringBehavior = [Microsoft.AnalysisServices.Tabular.CrossFilteringBehavior]::BothDirections
$sr.SecurityFilteringBehavior = [Microsoft.AnalysisServices.Tabular.SecurityFilteringBehavior]::OneDirection
```

### Delete

```powershell
$model.Relationships.Remove($model.Relationships[0])
```


## Hierarchies

### Create

```powershell
$h = New-Object Microsoft.AnalysisServices.Tabular.Hierarchy
$h.Name = "Geography"
$h.DisplayFolder = "Dimensions"

$l1 = New-Object Microsoft.AnalysisServices.Tabular.Level
$l1.Name = "Country"
$l1.Column = $model.Tables["Geo"].Columns["Country"]
$l1.Ordinal = 0
$h.Levels.Add($l1)

$l2 = New-Object Microsoft.AnalysisServices.Tabular.Level
$l2.Name = "State"
$l2.Column = $model.Tables["Geo"].Columns["State"]
$l2.Ordinal = 1
$h.Levels.Add($l2)

$l3 = New-Object Microsoft.AnalysisServices.Tabular.Level
$l3.Name = "City"
$l3.Column = $model.Tables["Geo"].Columns["City"]
$l3.Ordinal = 2
$h.Levels.Add($l3)

$model.Tables["Geo"].Hierarchies.Add($h)
```

### Read

```powershell
foreach ($t in $model.Tables) {
    foreach ($h in $t.Hierarchies) {
        $levels = ($h.Levels | Sort-Object Ordinal | ForEach-Object { $_.Name }) -join " > "
        Write-Output "[$($t.Name)].[$($h.Name)]: $levels"
    }
}
```

### Update

```powershell
$h = $model.Tables["Geo"].Hierarchies["Geography"]
$h.IsHidden = $true
$h.DisplayFolder = "Navigation"
$h.Description = "Drill-down hierarchy for geographic analysis"
```

### Delete

```powershell
$h = $model.Tables["Geo"].Hierarchies["Geography"]
$model.Tables["Geo"].Hierarchies.Remove($h)
```


## Roles (RLS/OLS)

### Create

```powershell
$role = New-Object Microsoft.AnalysisServices.Tabular.ModelRole
$role.Name = "Sales Region"
$role.ModelPermission = [Microsoft.AnalysisServices.Tabular.ModelPermission]::Read
$role.Description = "Row-level security by region"
$model.Roles.Add($role)

# Add table permission (RLS filter)
$tp = New-Object Microsoft.AnalysisServices.Tabular.TablePermission
$tp.Table = $model.Tables["Sales"]
$tp.FilterExpression = "[Region] = USERNAME()"
$role.TablePermissions.Add($tp)

# Add OLS (column-level security)
$cp = New-Object Microsoft.AnalysisServices.Tabular.ColumnPermission
$cp.Column = $model.Tables["Sales"].Columns["Margin"]
$cp.MetadataPermission = [Microsoft.AnalysisServices.Tabular.MetadataPermission]::None
$tp.ColumnPermissions.Add($cp)
```

### Read

```powershell
foreach ($role in $model.Roles) {
    Write-Output "Role: [$($role.Name)] Permission=$($role.ModelPermission)"
    foreach ($tp in $role.TablePermissions) {
        Write-Output "  Table: [$($tp.Table.Name)] Filter: $($tp.FilterExpression)"
    }
}
```

### Update

```powershell
$role = $model.Roles["Sales Region"]
$role.ModelPermission = [Microsoft.AnalysisServices.Tabular.ModelPermission]::ReadRefresh
$role.TablePermissions["Sales"].FilterExpression = "[Region] = USERPRINCIPALNAME()"
```

### Delete

```powershell
$role = $model.Roles["Sales Region"]
$model.Roles.Remove($role)
```


## Perspectives

### Create

```powershell
$p = New-Object Microsoft.AnalysisServices.Tabular.Perspective
$p.Name = "Sales View"
$p.Description = "Restricted view for sales analysts"
$model.Perspectives.Add($p)
```

### Toggle Membership

```powershell
# Include a table in perspective
$model.Tables["Sales"].InPerspective["Sales View"] = $true
$model.Tables["Date"].InPerspective["Sales View"] = $true

# Include specific columns
$model.Tables["Sales"].Columns["Amount"].InPerspective["Sales View"] = $true

# Include specific measures
$model.Tables["Sales"].Measures["Total Revenue"].InPerspective["Sales View"] = $true
```

### Delete

```powershell
$model.Perspectives.Remove($model.Perspectives["Sales View"])
```


## Cultures (Translations)

### Create

```powershell
$culture = New-Object Microsoft.AnalysisServices.Tabular.Culture
$culture.Name = "de-DE"
$model.Cultures.Add($culture)
```

### Add Translations

```powershell
$culture = $model.Cultures["de-DE"]

# Translate a table name
$model.Tables["Sales"].TranslatedNames["de-DE"] = "Verkauf"

# Translate a column name
$model.Tables["Sales"].Columns["Amount"].TranslatedNames["de-DE"] = "Betrag"

# Translate a measure
$model.Tables["Sales"].Measures["Total Revenue"].TranslatedNames["de-DE"] = "Gesamtumsatz"
```

### Delete

```powershell
$model.Cultures.Remove($model.Cultures["de-DE"])
```


## Partitions

### Read

```powershell
foreach ($t in $model.Tables) {
    foreach ($p in $t.Partitions) {
        Write-Output "[$($t.Name)] Partition=[$($p.Name)] SourceType=$($p.SourceType) Mode=$($p.Mode)"
        if ($p.Source -is [Microsoft.AnalysisServices.Tabular.MPartitionSource]) {
            Write-Output "  M Expression: $($p.Source.Expression)"
        }
    }
}
```

### Update M Expression

```powershell
$partition = $model.Tables["Sales"].Partitions[0]
$mSource = [Microsoft.AnalysisServices.Tabular.MPartitionSource]$partition.Source
$mSource.Expression = 'let Source = Sql.Database("server", "db"), Sales = Source{[Schema="dbo",Item="Sales"]}[Data] in Sales'
```


## Annotations (Custom Metadata)

### Create

```powershell
$ann = New-Object Microsoft.AnalysisServices.Tabular.Annotation
$ann.Name = "PBI_Description"
$ann.Value = "This measure tracks quarterly revenue"
$model.Tables["Sales"].Measures["Total Revenue"].Annotations.Add($ann)
```

### Read

```powershell
foreach ($ann in $model.Tables["Sales"].Annotations) {
    Write-Output "[$($ann.Name)] = $($ann.Value)"
}
```

### Update

```powershell
$model.Tables["Sales"].Annotations["PBI_Description"].Value = "Updated description"
```

### Delete

```powershell
$ann = $model.Tables["Sales"].Annotations["PBI_Description"]
$model.Tables["Sales"].Annotations.Remove($ann)
```


## Named Expressions (Shared M Queries)

### Create

```powershell
$expr = New-Object Microsoft.AnalysisServices.Tabular.NamedExpression
$expr.Name = "DatabaseConnection"
$expr.Kind = [Microsoft.AnalysisServices.Tabular.ExpressionKind]::M
$expr.Expression = 'Sql.Database("myserver.database.windows.net", "mydb")'
$model.Expressions.Add($expr)
```

### Read

```powershell
foreach ($e in $model.Expressions) {
    Write-Output "[$($e.Name)] Kind=$($e.Kind)"
    Write-Output "  $($e.Expression)"
}
```

### Update

```powershell
$model.Expressions["DatabaseConnection"].Expression = 'Sql.Database("newserver", "newdb")'
```

### Delete

```powershell
$model.Expressions.Remove($model.Expressions["DatabaseConnection"])
```


## Calculation Groups

### Create

```powershell
# A calculation group is a special table
$cgTable = New-Object Microsoft.AnalysisServices.Tabular.Table
$cgTable.Name = "Time Intelligence"
$cgTable.CalculationGroup = New-Object Microsoft.AnalysisServices.Tabular.CalculationGroup
$cgTable.CalculationGroup.Precedence = 10

# Add partition (required)
$partition = New-Object Microsoft.AnalysisServices.Tabular.Partition
$partition.Name = "Time Intelligence"
$partition.Source = New-Object Microsoft.AnalysisServices.Tabular.CalculationGroupSource
$cgTable.Partitions.Add($partition)

# Add calculation items
$ytd = New-Object Microsoft.AnalysisServices.Tabular.CalculationItem
$ytd.Name = "YTD"
$ytd.Expression = "CALCULATE(SELECTEDMEASURE(), DATESYTD('Date'[Date]))"
$ytd.Ordinal = 0
$cgTable.CalculationGroup.CalculationItems.Add($ytd)

$py = New-Object Microsoft.AnalysisServices.Tabular.CalculationItem
$py.Name = "Prior Year"
$py.Expression = "CALCULATE(SELECTEDMEASURE(), DATEADD('Date'[Date], -1, YEAR))"
$py.Ordinal = 1
$cgTable.CalculationGroup.CalculationItems.Add($py)

$model.Tables.Add($cgTable)
```

### Read

```powershell
foreach ($t in $model.Tables | Where-Object { $_.CalculationGroup -ne $null }) {
    Write-Output "Calc Group: [$($t.Name)] Precedence=$($t.CalculationGroup.Precedence)"
    foreach ($item in $t.CalculationGroup.CalculationItems) {
        Write-Output "  [$($item.Name)] Ordinal=$($item.Ordinal)"
        Write-Output "    $($item.Expression)"
    }
}
```


## Saving All Changes

After any combination of the above operations:

```powershell
$model.SaveChanges()
```

This persists all pending modifications in a single transaction. If validation fails, the entire batch is rolled back and an error is thrown with details.
