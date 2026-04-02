# Querying Data

How to query semantic models in DAX and lakehouses or data warehouses in SQL.

## Query Lakehouse or Warehouse Data with DuckDB

DuckDB can query Delta Lake tables and raw files directly from OneLake using the `delta` and `azure` core extensions. This is the fastest way to explore, validate, and analyze lakehouse data without creating a semantic model.

### Prerequisites

- DuckDB installed (`brew install duckdb` on macOS)
- Azure CLI authenticated (`az login`); the same session used by `fab`

### Setup

```sql
INSTALL delta;
INSTALL azure;
```

### Querying Delta Tables

Delta tables in a lakehouse are stored at `Tables/<schema>/<table>`. Query them with `delta_scan()`:

```bash
# 1. Get workspace and lakehouse IDs
WS_ID=$(fab get "ws.Workspace" -q "id" | tr -d '"')
LH_ID=$(fab get "ws.Workspace/LH.Lakehouse" -q "id" | tr -d '"')

# 2. Query a delta table
duckdb -c "
LOAD delta; LOAD azure;
CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');

SELECT * FROM delta_scan(
  'abfss://${WS_ID}@onelake.dfs.fabric.microsoft.com/${LH_ID}/Tables/schema/table_name'
) LIMIT 10;
"
```

The `CHAIN 'cli'` parameter tells the azure extension to use Azure CLI credentials; without it, DuckDB tries managed identity first (which fails on local machines).

### Querying Raw Files

Files stored under `Files/` can be queried directly by format:

```bash
BASE="abfss://${WS_ID}@onelake.dfs.fabric.microsoft.com/${LH_ID}/Files"

duckdb -c "
LOAD azure;
CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');

-- CSV files
SELECT * FROM read_csv('${BASE}/data/sales.csv') LIMIT 10;

-- JSON files
SELECT * FROM read_json('${BASE}/exports/report.json') LIMIT 10;

-- Parquet files
SELECT * FROM read_parquet('${BASE}/warehouse/facts.parquet') LIMIT 10;

-- Glob pattern: read all JSON files in a directory tree
SELECT count(*) FROM read_json('${BASE}/2025/01/*/activity_*.json');
"
```

Supported formats: CSV, JSON, Parquet. Glob patterns (`*`, `**`) work for reading multiple files at once.

### OneLake Path Format

All Fabric data stores use the same OneLake path format; substitute the item ID:

```
abfss://<workspace-id>@onelake.dfs.fabric.microsoft.com/<item-id>/Tables/<schema>/<table>
abfss://<workspace-id>@onelake.dfs.fabric.microsoft.com/<item-id>/Files/<path>
```

| Item type | `<item-id>` source | Notes |
|-----------|-------------------|-------|
| Lakehouse | `fab get "ws/LH.Lakehouse" -q "id"` | Direct Delta tables |
| Warehouse | `fab get "ws/WH.Warehouse" -q "id"` | Direct Delta tables |
| SQL Database | `fab get "ws/DB.SQLDatabase" -q "id"` | Auto-mirrored Delta; slight replication delay |

Cross-item joins work in a single DuckDB query; use different `abfss://` paths for each item.

### Common Use Cases

#### Data freshness check

```sql
-- Find the most recent records in a table
SELECT max(date_column) as latest_date, count(*) as total_rows
FROM delta_scan('abfss://.../<lh-id>/Tables/gold/orders');
```

#### Data quality validation

```sql
-- Check for nulls, duplicates, and value distributions
SELECT
  count(*) as total,
  count(DISTINCT customer_id) as unique_customers,
  count(*) FILTER (WHERE amount IS NULL) as null_amounts,
  min(order_date) as earliest,
  max(order_date) as latest
FROM delta_scan('abfss://.../<lh-id>/Tables/silver/orders');
```

#### Schema discovery for semantic model design

```sql
-- Explore column names, types, and sample values before building a model
DESCRIBE SELECT * FROM delta_scan('abfss://.../<lh-id>/Tables/gold/customers');

-- Profile a table to understand cardinality and distributions
SELECT
  column_name,
  column_type,
  count,
  approx_count_distinct,
  null_percentage
FROM (SUMMARIZE delta_scan('abfss://.../<lh-id>/Tables/gold/customers'));
```

#### Cross-table joins without a semantic model

```sql
-- Join multiple lakehouse tables directly
SELECT o.order_date, c.customer_name, sum(o.amount) as total
FROM delta_scan('.../Tables/gold/orders') o
JOIN delta_scan('.../Tables/gold/customers') c ON o.customer_id = c.customer_id
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;
```

#### Row count audit across schemas

```sql
SELECT 'gold.orders' as tbl, count(*) as rows FROM delta_scan('.../Tables/gold/orders')
UNION ALL
SELECT 'gold.customers', count(*) FROM delta_scan('.../Tables/gold/customers')
UNION ALL
SELECT 'silver.orders', count(*) FROM delta_scan('.../Tables/silver/orders')
ORDER BY tbl;
```

### Limitations

- **Read-only**: DuckDB reads Delta tables but cannot write back (append-only writes exist but are not recommended for lakehouse tables)
- **Auth**: Requires Azure CLI login or service principal; does not work with Fabric-only tokens
- **IDs required**: Workspace and lakehouse GUIDs are needed for path construction; get them with `fab get ... -q "id"`

## Query a Semantic Model (DAX)

DAX queries run against semantic models via the Power BI API. This is the standard approach for querying modeled data; measures, calculated columns, relationships, and RLS are all applied.

### SUMMARIZECOLUMNS (Preferred)

`SUMMARIZECOLUMNS` is the preferred function for querying semantic models. It groups by columns, adds extension columns (measures or expressions), and accepts filter arguments.

```
SUMMARIZECOLUMNS (
    <GroupBy_Column> [, <GroupBy_Column> [, ...]],
    [<FilterTable> [, <FilterTable> [, ...]]],
    ["<Name>", <Expression> [, "<Name>", <Expression> [, ...]]]
)
```

- **GroupBy columns**: Column references like `'Table'[Column]` to group by
- **Extension columns**: Named columns prefixed with `@`; paired as `"@Name", <Expression>`
- **Filter arguments**: Table expressions that restrict results; use `TREATAS` to apply filter values from outside the model

Rows where all extension columns evaluate to BLANK are automatically excluded.

### Escaping in DAX via fab API

DAX queries are embedded inside a JSON string passed to `fab api`. This creates two layers of escaping:

| Character | In DAX | Escaped in JSON string |
|-----------|--------|----------------------|
| Single quote `'` | `'Table'[Column]` | `'\''Table'\''[Column]` (break out of bash single-quote) |
| Double quote `"` | `"@ExtCol"` | `\"@ExtCol\"` (escaped for JSON) |

The safest approach is to write the JSON payload to a temp file:

```bash
WS_ID=$(fab get "ws.Workspace" -q "id" | tr -d '"')
MODEL_ID=$(fab get "ws.Workspace/Model.SemanticModel" -q "id" | tr -d '"')

cat > /tmp/dax-query.json << 'DAXEOF'
{
  "queries": [{
    "query": "EVALUATE SUMMARIZECOLUMNS ( 'Date'[Year], 'Product'[Category], \"@TotalSales\", [Total Sales], \"@AvgPrice\", AVERAGE ( 'Product'[UnitPrice] ) )"
  }],
  "serializerSettings": { "includeNulls": false }
}
DAXEOF

fab api -A powerbi "groups/$WS_ID/datasets/$MODEL_ID/executeQueries" \
  -X post -i /tmp/dax-query.json
```

### Filtering with TREATAS

Apply ad-hoc filters without needing a relationship by using `TREATAS` as a filter argument:

```json
{
  "queries": [{
    "query": "EVALUATE SUMMARIZECOLUMNS ( 'Date'[Year], 'Customer'[Region], \"@Revenue\", [Total Revenue], \"@Orders\", COUNTROWS ( 'Sales' ), TREATAS ( { \"Europe\", \"Asia\" }, 'Customer'[Region] ) )"
  }]
}
```

### Inline (without temp file)

For simple queries, inline works; escape `"` as `\"` inside the JSON:

```bash
fab api -A powerbi "groups/$WS_ID/datasets/$MODEL_ID/executeQueries" \
  -X post -i "{\"queries\":[{\"query\":\"EVALUATE SUMMARIZECOLUMNS ( 'Date'[Year], \\\"@Total\\\", [Total Sales] )\"}]}"
```

### Helper script

```bash
python3 scripts/execute_dax.py "ws.Workspace/Model.SemanticModel" \
  -q "EVALUATE SUMMARIZECOLUMNS ( 'Date'[Year], \"@Total\", [Total Sales] )"
```

For full DAX query patterns, parameters, and troubleshooting, see [semantic-models.md](./semantic-models.md).

## Query a Lakehouse Table via Direct Lake (Alternative)

When DuckDB is not available, create a temporary Direct Lake semantic model to query lakehouse tables via DAX:

```bash
# 1. Create Direct Lake model from lakehouse table
python3 scripts/create_direct_lake_model.py \
  "src.Workspace/LH.Lakehouse" \
  "dest.Workspace/Model.SemanticModel" \
  -t schema.table

# 2. Query via DAX
python3 scripts/execute_dax.py "dest.Workspace/Model.SemanticModel" -q "EVALUATE TOPN(10, 'table')"

# 3. (Optional) Delete temporary model
fab rm "dest.Workspace/Model.SemanticModel" -f
```

For lakehouse properties, endpoints, and file/table operations, see [lakehouses.md](./lakehouses.md).
