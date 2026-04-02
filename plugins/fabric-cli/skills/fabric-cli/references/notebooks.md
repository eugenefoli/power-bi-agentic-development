# Notebook Operations

Guide for working with Fabric notebooks via `fab`. Covers both Python and PySpark kernels, metadata formats, data item attachments, and reading/writing from OneLake.

## Choosing a Kernel

Fabric notebooks support two runtime types. **Prefer Python for agent work**; it starts in seconds, has DuckDB/Polars/delta-rs pre-installed, and can run T-SQL against warehouses via `notebookutils.data`.

| | Python Notebook | PySpark Notebook |
|---|---|---|
| Startup | ~5 seconds | 5s-5min (cold start) |
| Compute | Single-node container (2 vCores) | Spark cluster (4+ vCores) |
| Delta Lake | via delta-rs (< v1.0.0) | Native; full support |
| T-SQL (warehouse/SQL DB) | `notebookutils.data.connect_to_artifact()` | Not available |
| DuckDB/Polars | Pre-installed | Not pre-installed |
| Use when | Data fits in memory; T-SQL; quick tasks | Distributed compute; large data; Spark SQL |

## Notebook Metadata Format

The kernel type is determined by metadata fields in the `.ipynb` file. Getting these wrong causes silent failures or the wrong kernel.

### Python Notebook

```json
{
  "kernel_info": { "name": "jupyter", "jupyter_kernel_name": "python3.11" },
  "language_info": { "name": "python" },
  "microsoft": { "language": "python", "language_group": "jupyter_python" },
  "kernelspec": { "name": "jupyter", "display_name": "Jupyter" }
}
```

### PySpark Notebook

```json
{
  "kernel_info": { "name": "synapse_pyspark" },
  "language_info": { "name": "python" },
  "microsoft": { "language": "python", "language_group": "synapse_pyspark" }
}
```

### Key Differentiators

| Field | Python | PySpark |
|---|---|---|
| `kernel_info.name` | `"jupyter"` | `"synapse_pyspark"` |
| `kernel_info.jupyter_kernel_name` | `"python3.11"` or `"python3.10"` | not present |
| `microsoft.language_group` | `"jupyter_python"` | `"synapse_pyspark"` |
| `kernelspec.name` | `"jupyter"` | `"python3"` |

### Cell Metadata

Each cell carries `cell_type` (`"code"` or `"markdown"`) and its own `microsoft.language_group`:

```json
{
  "cell_type": "code",
  "source": ["print('hello')"],
  "outputs": [],
  "execution_count": null,
  "metadata": {
    "microsoft": { "language": "python", "language_group": "jupyter_python" }
  }
}
```

Markdown cells use `"cell_type": "markdown"` with the same metadata structure.

## Attaching Data Items

Data items (lakehouse, warehouse, SQL database) are attached via the `dependencies` field in notebook metadata. Without attachments, lakehouse paths and `notebookutils.data` calls may fail.

### Lakehouse Attachment

```json
"dependencies": {
  "lakehouse": {
    "default_lakehouse": "<lakehouse-guid>",
    "default_lakehouse_name": "<LakehouseName>",
    "default_lakehouse_workspace_id": "<workspace-guid>",
    "known_lakehouses": [{ "id": "<lakehouse-guid>" }]
  }
}
```

### Warehouse Attachment

```json
"dependencies": {
  "warehouse": {
    "default_warehouse": "<warehouse-guid>",
    "known_warehouses": [
      { "id": "<warehouse-guid>", "type": "Datawarehouse" }
    ]
  }
}
```

Warehouse types: `Datawarehouse` (warehouse), `Lakewarehouse` (lakehouse SQL endpoint), `MountedWarehouse` (SQL database).

### Combined Attachments

Lakehouse and warehouse can coexist:

```json
"dependencies": {
  "lakehouse": { ... },
  "warehouse": { ... }
}
```

Get the GUIDs with `fab get "ws.Workspace/Item.Type" -q "id"`.

## Creating and Importing Notebooks

### Directory Structure

```
MyNotebook.Notebook/
  .platform                    # Required; displayName must match item name
  notebook-content.ipynb       # Required; .ipynb JSON format
```

### .platform File

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": { "type": "Notebook", "displayName": "MyNotebook" },
  "config": { "version": "2.0", "logicalId": "00000000-0000-0000-0000-000000000001" }
}
```

### Import and Run

```bash
mkdir -p /tmp/MyNotebook.Notebook
# Create .platform and notebook-content.ipynb files (see examples/)
fab import "ws.Workspace/MyNotebook.Notebook" -i /tmp/MyNotebook.Notebook -f
fab job run "ws.Workspace/MyNotebook.Notebook"
```

### Common Import Failures

| Error | Cause | Fix |
|---|---|---|
| "Not supported language" | Missing `language_info.name` | Add `"language_info": {"name": "python"}` |
| "failed without detail error" (instant) | Bad metadata or missing attachment | Check `kernel_info`, `language_group`, `dependencies` |
| "failed without detail error" (~40s) | Code error; no detail via CLI | Open in portal (`fab open`) to see Spark/Python traceback |
| `NameError: spark` | No lakehouse attached (PySpark only) | Add `default_lakehouse` to dependencies |
| `module has no attribute` | Wrong API name | Check `notebookutils.data.help()` for correct methods |

## Reading and Writing Data

### PySpark: Lakehouse Tables

```python
# Read with three-part naming
df = spark.sql("SELECT * FROM LakehouseName.schema.table")

# Write to lakehouse table
df.write.mode("overwrite").option("overwriteSchema", "true").saveAsTable("LakehouseName.schema.table")
```

### Python: Lakehouse with delta-rs

```python
from deltalake import DeltaTable

# Local path (attached lakehouse)
dt = DeltaTable('/lakehouse/default/Tables/my_table')
df = dt.to_pandas()

# ABFS path (any lakehouse; no attachment needed)
access_token = notebookutils.credentials.getToken('storage')
storage_options = {'bearer_token': access_token, 'use_fabric_endpoint': 'true'}
dt = DeltaTable(
    'abfss://<ws-guid>@onelake.dfs.fabric.microsoft.com/<lh-guid>/Tables/schema/table',
    storage_options=storage_options
)
df = dt.to_pandas()
```

### Python: Lakehouse with DuckDB

```python
import duckdb
from deltalake import DeltaTable

access_token = notebookutils.credentials.getToken('storage')
storage_options = {'bearer_token': access_token, 'use_fabric_endpoint': 'true'}
dt = DeltaTable('abfss://...', storage_options=storage_options)
arrow_ds = dt.to_pyarrow_dataset()

# DuckDB queries Arrow datasets with filter pushdown
result = duckdb.sql("SELECT count(*) FROM arrow_ds").df()
```

### Python: Write to Lakehouse with delta-rs

```python
from deltalake.writer import write_deltalake
write_deltalake('/lakehouse/default/Tables/output', df, mode='overwrite')
```

### Python: T-SQL via notebookutils.data (Warehouse, SQL Database, Lakehouse)

```python
# connect_to_artifact supports: Warehouse (full DML), Lakehouse (read-only),
# SQLDatabase (full DML), MirroredDatabase (read-only)
with notebookutils.data.connect_to_artifact('WarehouseName') as conn:
    conn.query('CREATE TABLE dbo.test (id INT, name VARCHAR(100))')
    conn.query("INSERT INTO dbo.test VALUES (1, 'hello')")
    df = conn.query('SELECT * FROM dbo.test')
    print(df)

# Cross-workspace
conn = notebookutils.data.connect_to_artifact(
    'warehouse_name', workspace='<workspace-guid>', artifact_type='Warehouse'
)
```

`notebookutils.data` is Python notebook only; not available in PySpark.

### PySpark: Write to Warehouse (synapsesql connector)

```python
import com.microsoft.spark.fabric
from com.microsoft.spark.fabric.Constants import Constants

df.write.synapsesql("WarehouseName.dbo.table", mode="overwrite")
df = spark.read.synapsesql("WarehouseName.dbo.table")
```

Requires Runtime 1.3+. Known to fail with opaque errors from `fab job run`; use `fab open` to check Spark logs in the portal.

## Running Notebooks

```bash
# Synchronous (wait for completion)
fab job run "ws.Workspace/ETL.Notebook"

# With timeout
fab job run "ws.Workspace/ETL.Notebook" --timeout 600

# Asynchronous
fab job start "ws.Workspace/ETL.Notebook"
fab job run-status "ws.Workspace/ETL.Notebook" --id <job-id>

# With parameters
fab job run "ws.Workspace/ETL.Notebook" -P date:string=2025-01-01,batch:int=500

# With Spark configuration (PySpark only)
fab job run "ws.Workspace/ETL.Notebook" -C '{
  "defaultLakehouse": {"name": "MainLH", "id": "<lh-id>", "workspaceId": "<ws-id>"},
  "conf": {"spark.sql.shuffle.partitions": "200"}
}'
```

## Getting Notebook Run Outputs

Cell outputs from completed runs are **not available via any REST API**. The `fab export` and `fab get -q definition` commands return cell source code only; outputs are stored in portal-only snapshots.

**Workaround**: write notebook results to a lakehouse table or file, then read them back with DuckDB or `fab cp`:

```python
# In notebook: write results to lakehouse instead of just printing
import pandas as pd
from deltalake.writer import write_deltalake

results = pd.DataFrame({'metric': ['latest_date', 'row_count'], 'value': ['2025-10-14', '541']})
write_deltalake('/lakehouse/default/Tables/notebook_results', results, mode='overwrite')
```

```bash
# From CLI: read results with DuckDB
duckdb -c "
LOAD delta; LOAD azure;
CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');
SELECT * FROM delta_scan('abfss://<ws-id>@onelake.../<lh-id>/Tables/notebook_results');
"
```

## Reducing Startup Times

| Scenario | Approach | Startup |
|----------|----------|---------|
| No custom libs | Starter pool (default) | 5-10s |
| Need T-SQL, DuckDB, or quick tasks | Python notebook | ~5s |
| Custom libs, scheduled work | Custom Live Pool + Full mode env | ~5s |
| Multiple notebooks, same config | High Concurrency Mode | First: normal; rest: instant |
| Private Link / Managed VNet | Custom pool (unavoidable) | 2-5 min |

**Custom Live Pools**: Workspace Settings > Spark > Pool > New Pool; attach Environment with Full mode publish; enable Live Pool schedule.

**High Concurrency Mode**: Multiple notebooks share one Spark session. Enable in Workspace Settings > Spark > High Concurrency. Use session tags in pipelines to group notebooks.

**Python notebooks**: Skip Spark entirely. DuckDB, Polars, and delta-rs handle most single-node workloads.

## Python %%configure (Scale Up)

Python notebooks default to 2 vCores / 16GB. Scale up with `%%configure` in the first cell:

```json
%%configure -f
{
    "vCores": 8,
    "defaultLakehouse": {
        "name": "MyLH",
        "id": "<lakehouse-guid>",
        "workspaceId": "<workspace-guid>"
    },
    "mountPoints": [
        {
            "mountPoint": "/myMount",
            "source": "abfss://<container>@<account>.dfs.core.windows.net/<path>"
        }
    ]
}
```

Supported vCores: 4, 8, 16, 32, 64 (8GB RAM per vCore).

## Scheduling, Monitoring, and Management

```bash
# Schedule (cron, daily, weekly)
fab job run-sch "ws.Workspace/ETL.Notebook" --type daily --interval 02:00 --enable

# List execution history
fab job run-list "ws.Workspace/ETL.Notebook"

# Cancel running job
fab job run-cancel "ws.Workspace/ETL.Notebook" --id <job-id>

# Export / import
fab export "ws.Workspace/ETL.Notebook" -o /tmp/notebooks -f
fab import "ws.Workspace/ETL.Notebook" -i /tmp/notebooks/ETL.Notebook -f

# Copy between workspaces
fab cp "Dev.Workspace/ETL.Notebook" "Prod.Workspace" -f

# Delete
fab rm "ws.Workspace/Old.Notebook" -f

# Open in browser
fab open "ws.Workspace/ETL.Notebook"

# Open in VS Code (Synapse extension required)
# vscode://SynapseVSCode.synapse?workspaceId=<ws-id>&artifactId=<nb-id>&tenantId=<tenant-id>
```

## Example Notebooks

Working examples in `examples/`:

- **`examples/python-notebook.ipynb`** -- Python kernel with delta-rs, DuckDB, and `notebookutils.data` T-SQL patterns
- **`examples/pyspark-notebook.ipynb`** -- PySpark kernel with Spark SQL read and `saveAsTable` write patterns
