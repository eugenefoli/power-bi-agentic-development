# SQL Database Operations

Guide for managing Fabric SQL databases; creating, browsing, and querying via DuckDB.

## Creating a SQL Database

```bash
fab mkdir "ws.Workspace/MyDB.SQLDatabase"
```

## Properties

```bash
fab get "ws.Workspace/MyDB.SQLDatabase" -q "properties" -f
```

Returns `connectionInfo`, `connectionString`, `databaseName`, `serverFqdn`, `collation`, `backupRetentionDays`.

The SQL endpoint uses `.database.fabric.microsoft.com` (not `.datawarehouse.`).

## Browsing Contents

```bash
# List top-level (Audit, Code, Files, Tables)
fab ls "ws.Workspace/MyDB.SQLDatabase"

# List tables
fab ls "ws.Workspace/MyDB.SQLDatabase/Tables"

# Get table schema
fab table schema "ws.Workspace/MyDB.SQLDatabase/Tables/dbo/customers"
```

## Querying SQL Database Data with DuckDB

SQL databases automatically replicate their tables to OneLake as Delta Lake. Query them via DuckDB once replication completes:

```bash
WS_ID=$(fab get "ws.Workspace" -q "id" | tr -d '"')
DB_ID=$(fab get "ws.Workspace/MyDB.SQLDatabase" -q "id" | tr -d '"')

duckdb -c "
LOAD delta; LOAD azure;
CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');
SELECT * FROM delta_scan('abfss://${WS_ID}@onelake.dfs.fabric.microsoft.com/${DB_ID}/Tables/dbo/customers') LIMIT 10;
"
```

For full DuckDB patterns, see [querying-data.md](./querying-data.md).

## Loading Data

SQL databases support full T-SQL DDL/DML. Data can be loaded via:

- **T-SQL** (SSMS, VS Code MSSQL extension, Fabric portal query editor)
- **Notebooks** using `synapsesql` connector
- **Pipelines** and **Dataflows Gen2**

### Via Notebook

```python
df.write.synapsesql("SQLDatabaseName.dbo.table_name", mode="overwrite")
```

### Via T-SQL (Fabric Portal or SSMS)

```sql
CREATE TABLE dbo.customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(100),
    region VARCHAR(50)
);

INSERT INTO dbo.customers VALUES (1, 'Contoso', 'Europe');
```

## Auto-Mirroring to OneLake

SQL database tables are automatically mirrored to OneLake as Delta tables. This means:

- Changes via T-SQL are reflected in OneLake after a short replication delay
- DuckDB queries read the replicated Delta snapshot (not real-time)
- The SQL analytics endpoint provides read-only T-SQL access to the OneLake copy

## Cross-Database Queries

SQL databases support three-part naming for cross-database queries within the same workspace:

```sql
SELECT *
FROM MyWarehouse.dbo.orders o
JOIN MyLakehouse.dbo.customers c ON o.customer_id = c.customer_id;
```

## Key Differences from Lakehouse and Warehouse

| Feature | Lakehouse | Warehouse | SQL Database |
|---------|-----------|-----------|--------------|
| T-SQL DDL/DML | Read-only | Full | Full |
| OneLake Delta tables | Direct | Direct | Mirrored (delayed) |
| DuckDB `delta_scan` | Yes | Yes | Yes (after replication) |
| `fab cp` file upload | Yes | No | No |
| `fab export/import` | No | No | Yes |
| Primary use | Data engineering | Analytics | OLTP applications |

## Deleting

```bash
fab rm "ws.Workspace/MyDB.SQLDatabase" -f
```
