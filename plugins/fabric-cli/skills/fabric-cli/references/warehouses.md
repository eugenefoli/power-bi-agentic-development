# Warehouse Operations

Guide for managing Fabric warehouses; creating, browsing, querying via DuckDB, and loading data.

## Creating a Warehouse

```bash
fab mkdir "ws.Workspace/MyWarehouse.Warehouse"
```

## Properties

```bash
fab get "ws.Workspace/MyWarehouse.Warehouse" -q "properties"
```

Returns `connectionInfo` (SQL endpoint), `connectionString`, `createdDate`, `collationType`.

## Browsing Contents

```bash
# List top-level (Tables, Files)
fab ls "ws.Workspace/MyWarehouse.Warehouse"

# List tables
fab ls "ws.Workspace/MyWarehouse.Warehouse/Tables"

# List tables in a schema
fab ls "ws.Workspace/MyWarehouse.Warehouse/Tables/dbo"

# Get table schema
fab table schema "ws.Workspace/MyWarehouse.Warehouse/Tables/dbo/orders"
```

## Querying Warehouse Data with DuckDB

Warehouse tables are stored as Delta Lake in OneLake. Query them the same way as lakehouse tables:

```bash
WS_ID=$(fab get "ws.Workspace" -q "id" | tr -d '"')
WH_ID=$(fab get "ws.Workspace/MyWarehouse.Warehouse" -q "id" | tr -d '"')

duckdb -c "
LOAD delta; LOAD azure;
CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');
SELECT * FROM delta_scan('abfss://${WS_ID}@onelake.dfs.fabric.microsoft.com/${WH_ID}/Tables/dbo/orders') LIMIT 10;
"
```

For full DuckDB patterns, see [querying-data.md](./querying-data.md).

## Loading Data

Warehouses do not support `fab cp` to Files or `fab table load`. Data must be loaded via T-SQL (SSMS, notebooks) or pipelines.

### Via Notebook (Recommended for Agents)

```python
# Write a Spark DataFrame to warehouse
df.write.synapsesql("WarehouseName.dbo.table_name", mode="overwrite")

# CTAS from lakehouse (cross-database)
df = spark.sql("SELECT * FROM LakehouseName.schema.source_table")
df.write.synapsesql("WarehouseName.dbo.target_table", mode="overwrite")
```

See [notebooks.md](./notebooks.md) for creating and running notebooks via `fab`.

### Via T-SQL (SSMS or Warehouse Editor)

```sql
-- CTAS from external Parquet
CREATE TABLE dbo.orders AS
SELECT * FROM OPENROWSET(BULK 'https://storage.blob.core.windows.net/data/orders.parquet');

-- INSERT from lakehouse (cross-database)
INSERT INTO dbo.orders
SELECT * FROM MyLakehouse.dbo.orders;
```

## Key Differences from Lakehouse

| Feature | Lakehouse | Warehouse |
|---------|-----------|-----------|
| File upload (`fab cp`) | Supported | Not supported on Files path |
| `fab table load` | Supported | Not supported |
| Shortcuts (`fab ln`) | Supported | Not supported |
| T-SQL DDL/DML | Read-only (SQL endpoint) | Full support |
| OneLake Delta tables | Yes | Yes |
| DuckDB `delta_scan` | Yes | Yes |

## Deleting

```bash
fab rm "ws.Workspace/MyWarehouse.Warehouse" -f
```
