# Notebook Operations

Comprehensive guide for working with Fabric notebooks using the Fabric CLI.

## Overview

Fabric notebooks are interactive documents for data engineering, data science, and analytics. They can be executed, scheduled, and managed via the CLI.

## Getting Notebook Information

### Basic Notebook Info

```bash
# Check if notebook exists
fab exists "Production.Workspace/ETL Pipeline.Notebook"

# Get notebook properties
fab get "Production.Workspace/ETL Pipeline.Notebook"

# Get with verbose details
fab get "Production.Workspace/ETL Pipeline.Notebook" -v

# Get only notebook ID
fab get "Production.Workspace/ETL Pipeline.Notebook" -q "id"
```

### Get Notebook Definition

```bash
# Get full notebook definition
fab get "Production.Workspace/ETL Pipeline.Notebook" -q "definition"

# Save definition to file
fab get "Production.Workspace/ETL Pipeline.Notebook" -q "definition" -o /tmp/notebook-def.json

# Get notebook content (cells)
fab get "Production.Workspace/ETL Pipeline.Notebook" -q "definition.parts[?path=='notebook-content.py'].payload | [0]"
```

## Exporting Notebooks

### Export as IPYNB

```bash
# Export notebook
fab export "Production.Workspace/ETL Pipeline.Notebook" -o /tmp/notebooks

# This creates:
# /tmp/notebooks/ETL Pipeline.Notebook/
# ├── notebook-content.py (or .ipynb)
# └── metadata files
```

### Export All Notebooks from Workspace

```bash
# Export all notebooks
WS_ID=$(fab get "Production.Workspace" -q "id")
NOTEBOOKS=$(fab api "workspaces/$WS_ID/items" -q "value[?type=='Notebook'].displayName")

# Native alternative (preferred):
# NOTEBOOKS=$(fab ls "Production.Workspace" -q "[?contains(name, '.Notebook')]")

for NOTEBOOK in $NOTEBOOKS; do
    fab export "Production.Workspace/$NOTEBOOK.Notebook" -o /tmp/notebooks
done
```

## Importing Notebooks

### Import from Local

```bash
# Import notebook from .ipynb format (default)
fab import "Production.Workspace/New ETL.Notebook" -i /tmp/notebooks/ETL\ Pipeline.Notebook

# Import from .py format
fab import "Production.Workspace/Script.Notebook" -i /tmp/script.py --format py
```

### Copy Between Workspaces

```bash
# Copy notebook
fab cp "Dev.Workspace/ETL.Notebook" "Production.Workspace"

# Copy with new name
fab cp "Dev.Workspace/ETL.Notebook" "Production.Workspace/Prod ETL.Notebook"
```

## Creating Notebooks

### Create Blank Notebook

```bash
# Native alternative for empty notebook (preferred):
fab mkdir "Production.Workspace/New Data Processing.Notebook"

# Or via API:
fab get "Production.Workspace" -q "id"
fab api -X post "workspaces/<workspace-id>/notebooks" -i '{"displayName": "New Data Processing"}'
```

### Creating Notebooks for fab import

When creating notebooks locally for `fab import`, use `.ipynb` (JSON) format with proper metadata.

#### Required Metadata Fields

| Field | Required | Value | What happens without it |
|-------|----------|-------|------------------------|
| `metadata.language_info.name` | Yes | `"python"` | `fab job run` fails: "Not supported language" |
| `metadata.kernel_info.name` | Yes | `"synapse_pyspark"` | Spark session may not initialize |
| `metadata.dependencies.lakehouse` | For lakehouse access | See below | `NameError: name 'spark' is not defined` |

#### .platform File (Required)

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": { "type": "Notebook", "displayName": "MyNotebook" },
  "config": { "version": "2.0", "logicalId": "00000000-0000-0000-0000-000000000001" }
}
```

#### notebook-content.ipynb (Required)

```json
{
  "nbformat": 4, "nbformat_minor": 5,
  "metadata": {
    "kernel_info": { "name": "synapse_pyspark" },
    "language_info": { "name": "python" },
    "dependencies": {
      "lakehouse": {
        "default_lakehouse": "<lakehouse-guid>",
        "default_lakehouse_name": "LakehouseName",
        "default_lakehouse_workspace_id": "<workspace-guid>"
      }
    }
  },
  "cells": [
    {
      "cell_type": "code",
      "source": ["df = spark.sql('SELECT * FROM my_table')\n", "print(df.count())"],
      "metadata": {},
      "outputs": []
    }
  ]
}
```

#### Directory Structure

```
MyNotebook.Notebook/
├── .platform                    # Required; displayName must match item name
└── notebook-content.ipynb       # Required; must be .ipynb (JSON), not .py
```

#### Import and Run

```bash
fab import "ws.Workspace/MyNotebook.Notebook" -i /tmp/MyNotebook.Notebook -f
fab job run "ws.Workspace/MyNotebook.Notebook"
```

#### Common Failures

| Error | Cause | Fix |
|-------|-------|-----|
| "Not supported language" | Missing `language_info.name` | Add `"language_info": {"name": "python"}` |
| "failed without detail error" (instant) | Missing lakehouse or bad metadata | Attach lakehouse in `dependencies` |
| "failed without detail error" (~40s) | Code error or connector issue | Open notebook in Fabric portal to see Spark logs |
| `NameError: spark` | No lakehouse attached | Add `default_lakehouse` to dependencies |

### Writing to Warehouses and SQL Databases from Notebooks

Notebooks can write to warehouses and SQL databases using the Spark synapsesql connector:

```python
import com.microsoft.spark.fabric
from com.microsoft.spark.fabric.Constants import Constants

# Write DataFrame to a warehouse table
df.write.synapsesql("WarehouseName.dbo.table_name", mode="overwrite")

# Read from a warehouse table
df = spark.read.synapsesql("WarehouseName.dbo.table_name")

# Cross-database: read from lakehouse, write to warehouse
df = spark.sql("SELECT * FROM LakehouseName.schema.table")
df.write.synapsesql("WarehouseName.dbo.target_table", mode="overwrite")
```

The `com.microsoft.spark.fabric` import is required; without it `synapsesql` is not available on the DataFrame reader/writer. The warehouse must be in the same workspace as the notebook's attached lakehouse.

**Known issue**: `fab job run` failures with `synapsesql` show "failed without detail error". Open the notebook in Fabric portal to see the actual Spark exception in cell output. Common causes: warehouse name mismatch, permissions, or the connector not finding the warehouse endpoint.

### Create and Configure Query Notebook

Use this workflow to create a notebook for querying lakehouse tables with Spark SQL.

#### Step 1: Create the notebook

```bash
# Get workspace ID
fab get "Sales.Workspace" -q "id"
# Returns: 4caf7825-81ac-4c94-9e46-306b4c20a4d5

# Create notebook
fab api -X post "workspaces/4caf7825-81ac-4c94-9e46-306b4c20a4d5/notebooks" -i '{"displayName": "Data Query"}'
# Returns notebook ID: 97bbd18d-c293-46b8-8536-82fb8bc9bd58
```

#### Step 2: Get lakehouse ID (required for notebook metadata)

```bash
fab get "Sales.Workspace/SalesLH.Lakehouse" -q "id"
# Returns: ddbcc575-805b-4922-84db-ca451b318755
```

#### Step 3: Create notebook code in Fabric format

```bash
cat > /tmp/notebook.py <<'EOF'
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "ddbcc575-805b-4922-84db-ca451b318755",
# META       "default_lakehouse_name": "SalesLH",
# META       "default_lakehouse_workspace_id": "4caf7825-81ac-4c94-9e46-306b4c20a4d5"
# META     }
# META   }
# META }

# CELL ********************

# Query lakehouse table
df = spark.sql("""
    SELECT
        date_key,
        COUNT(*) as num_records
    FROM gold.sets
    GROUP BY date_key
    ORDER BY date_key DESC
    LIMIT 10
""")

# IMPORTANT: Convert to pandas and print to capture output
# display(df) will NOT show results via API
pandas_df = df.toPandas()
print(pandas_df)
print(f"\nLatest date: {pandas_df.iloc[0]['date_key']}")
EOF
```

#### Step 4: Base64 encode and create update definition

```bash
base64 -i /tmp/notebook.py > /tmp/notebook-b64.txt

cat > /tmp/update.json <<EOF
{
  "definition": {
    "parts": [
      {
        "path": "notebook-content.py",
        "payload": "$(cat /tmp/notebook-b64.txt)",
        "payloadType": "InlineBase64"
      }
    ]
  }
}
EOF
```

#### Step 5: Update notebook with code

```bash
# Alternative for updating notebook from local file (preferred):
fab import "Sales.Workspace/Data Query.Notebook" -i /tmp/notebook.py --format py -f

# Or via API (manual base64 encoding required):
fab api -X post "workspaces/4caf7825-81ac-4c94-9e46-306b4c20a4d5/notebooks/97bbd18d-c293-46b8-8536-82fb8bc9bd58/updateDefinition" -i /tmp/update.json --show_headers
# Returns operation ID in Location header
```

#### Step 6: Check update completed

```bash
fab api "operations/<operation-id>"
# Wait for status: "Succeeded"
```

#### Step 7: Run the notebook

```bash
fab job start "Sales.Workspace/Data Query.Notebook"
# Returns job instance ID
```

#### Step 8: Check execution status

```bash
fab job run-status "Sales.Workspace/Data Query.Notebook" --id <job-id>
# Wait for status: "Completed"
```

#### Step 9: Get results (download from Fabric UI)

- Open notebook in Fabric UI after execution
- Print output will be visible in cell outputs
- Download .ipynb file to see printed results locally

#### Critical Requirements

1. **File format**: Must be `notebook-content.py` (NOT `.ipynb`)
2. **Lakehouse ID**: Must include `default_lakehouse` ID in metadata (not just name)
3. **Spark session**: Will be automatically available when lakehouse is attached
4. **Capturing output**: Use `df.toPandas()` and `print()` - `display()` won't show in API
5. **Results location**: Print output visible in UI and downloaded .ipynb, NOT in definition

#### Common Issues

- `NameError: name 'spark' is not defined` - Lakehouse not attached (missing default_lakehouse ID)
- Job "Completed" but no results - Used display() instead of print()
- Update fails - Used .ipynb path instead of .py

### Create from Template

```bash
# Export template
fab export "Templates.Workspace/Template Notebook.Notebook" -o /tmp/templates

# Import as new notebook
fab import "Production.Workspace/Custom Notebook.Notebook" -i /tmp/templates/Template\ Notebook.Notebook
```

## Running Notebooks

### Run Synchronously (Wait for Completion)

```bash
# Run notebook and wait
fab job run "Production.Workspace/ETL Pipeline.Notebook"

# Run with timeout (seconds)
fab job run "Production.Workspace/Long Process.Notebook" --timeout 600

# Run with custom polling interval (seconds) for status checks
fab job run "Production.Workspace/ETL Pipeline.Notebook" --polling_interval 30
```

### Run with Parameters

```bash
# Run with basic parameters
fab job run "Production.Workspace/ETL Pipeline.Notebook" -P \
  date:string=2024-01-01,\
  batch_size:int=1000,\
  debug_mode:bool=false,\
  threshold:float=0.95

# Parameters must match types defined in notebook
# Supported types: string, int, float, bool
```

### Run with Spark Configuration

```bash
# Run with custom Spark settings
fab job run "Production.Workspace/Big Data Processing.Notebook" -C '{
  "conf": {
    "spark.executor.memory": "8g",
    "spark.executor.cores": "4",
    "spark.dynamicAllocation.enabled": "true"
  },
  "environment": {
    "id": "<environment-id>",
    "name": "Production Environment"
  }
}'

# Run with default lakehouse
fab job run "Production.Workspace/Data Ingestion.Notebook" -C '{
  "defaultLakehouse": {
    "name": "MainLakehouse",
    "id": "<lakehouse-id>",
    "workspaceId": "<workspace-id>"
  }
}'

# Run with workspace Spark pool
fab job run "Production.Workspace/Analytics.Notebook" -C '{
  "useStarterPool": false,
  "useWorkspacePool": "HighMemoryPool"
}'
```

### Run with Combined Parameters and Configuration

```bash
# Combine parameters and configuration
fab job run "Production.Workspace/ETL Pipeline.Notebook" \
  -P date:string=2024-01-01,batch:int=500 \
  -C '{
    "defaultLakehouse": {"name": "StagingLH", "id": "<lakehouse-id>"},
    "conf": {"spark.sql.shuffle.partitions": "200"}
  }'
```

### Run Asynchronously

```bash
# Start notebook and return immediately
JOB_ID=$(fab job start "Production.Workspace/ETL Pipeline.Notebook" | grep -o '"id": "[^"]*"' | cut -d'"' -f4)

# Check status later
fab job run-status "Production.Workspace/ETL Pipeline.Notebook" --id "$JOB_ID"
```

## Monitoring Notebook Executions

### Get Job Status

```bash
# Check specific job
fab job run-status "Production.Workspace/ETL Pipeline.Notebook" --id <job-id>

# Get detailed status via API
WS_ID=$(fab get "Production.Workspace" -q "id")
NOTEBOOK_ID=$(fab get "Production.Workspace/ETL Pipeline.Notebook" -q "id")
fab api "workspaces/$WS_ID/items/$NOTEBOOK_ID/jobs/instances/<job-id>"
```

### List Execution History

```bash
# List all job runs
fab job run-list "Production.Workspace/ETL Pipeline.Notebook"

# List only scheduled runs
fab job run-list "Production.Workspace/ETL Pipeline.Notebook" --schedule

# Get latest run status
fab job run-list "Production.Workspace/ETL Pipeline.Notebook" | head -n 1
```

### Cancel Running Job

```bash
fab job run-cancel "Production.Workspace/ETL Pipeline.Notebook" --id <job-id>
```

## Scheduling Notebooks

### Create Cron Schedule

```bash
# Run every 30 minutes
fab job run-sch "Production.Workspace/ETL Pipeline.Notebook" \
  --type cron \
  --interval 30 \
  --start 2024-11-15T00:00:00 \
  --end 2025-12-31T23:59:00 \
  --enable
```

### Create Daily Schedule

```bash
# Run daily at 2 AM and 2 PM
fab job run-sch "Production.Workspace/ETL Pipeline.Notebook" \
  --type daily \
  --interval 02:00,14:00 \
  --start 2024-11-15T00:00:00 \
  --end 2025-12-31T23:59:00 \
  --enable
```

### Create Weekly Schedule

```bash
# Run Monday and Friday at 9 AM
fab job run-sch "Production.Workspace/Weekly Report.Notebook" \
  --type weekly \
  --interval 09:00 \
  --days Monday,Friday \
  --start 2024-11-15T00:00:00 \
  --enable
```

### Update Schedule

```bash
# Modify existing schedule
fab job run-update "Production.Workspace/ETL Pipeline.Notebook" \
  --id <schedule-id> \
  --type daily \
  --interval 03:00 \
  --enable

# Disable schedule
fab job run-update "Production.Workspace/ETL Pipeline.Notebook" \
  --id <schedule-id> \
  --disable
```

## Notebook Configuration

### Set Default Lakehouse

```bash
# Via notebook properties
fab set "Production.Workspace/ETL.Notebook" -q lakehouse -i '{
  "known_lakehouses": [{"id": "<lakehouse-id>"}],
  "default_lakehouse": "<lakehouse-id>",
  "default_lakehouse_name": "MainLakehouse",
  "default_lakehouse_workspace_id": "<workspace-id>"
}'
```

### Set Default Environment

```bash
fab set "Production.Workspace/ETL.Notebook" -q environment -i '{
  "environmentId": "<environment-id>",
  "workspaceId": "<workspace-id>"
}'
```

### Set Default Warehouse

```bash
fab set "Production.Workspace/Analytics.Notebook" -q warehouse -i '{
  "known_warehouses": [{"id": "<warehouse-id>", "type": "Datawarehouse"}],
  "default_warehouse": "<warehouse-id>"
}'
```

## Updating Notebooks

### Update Display Name

```bash
fab set "Production.Workspace/ETL.Notebook" -q displayName -i "ETL Pipeline v2"
```

### Update Description

```bash
fab set "Production.Workspace/ETL.Notebook" -q description -i "Daily ETL pipeline for sales data ingestion and transformation"
```

## Deleting Notebooks

```bash
# Delete with confirmation (interactive)
fab rm "Dev.Workspace/Old Notebook.Notebook"

# Force delete without confirmation
fab rm "Dev.Workspace/Old Notebook.Notebook" -f
```

## Advanced Workflows

### Parameterized Notebook Execution

```python
# Create parametrized notebook with cell tagged as "parameters"
# In notebook, create cell:
date = "2024-01-01"  # default
batch_size = 1000    # default
debug = False        # default

# Execute with different parameters
fab job run "Production.Workspace/Parameterized.Notebook" -P \
  date:string=2024-02-15,\
  batch_size:int=2000,\
  debug:bool=true
```

### Notebook Orchestration Pipeline

```bash
#!/bin/bash

WORKSPACE="Production.Workspace"
DATE=$(date +%Y-%m-%d)

# 1. Run ingestion notebook
echo "Starting data ingestion..."
fab job run "$WORKSPACE/1_Ingest_Data.Notebook" -P date:string=$DATE

# 2. Run transformation notebook
echo "Running transformations..."
fab job run "$WORKSPACE/2_Transform_Data.Notebook" -P date:string=$DATE

# 3. Run analytics notebook
echo "Generating analytics..."
fab job run "$WORKSPACE/3_Analytics.Notebook" -P date:string=$DATE

# 4. Run reporting notebook
echo "Creating reports..."
fab job run "$WORKSPACE/4_Reports.Notebook" -P date:string=$DATE

echo "Pipeline completed for $DATE"
```

### Monitoring Long-Running Notebook

```bash
#!/bin/bash

NOTEBOOK="Production.Workspace/Long Process.Notebook"

# Start job
JOB_ID=$(fab job start "$NOTEBOOK" -P date:string=$(date +%Y-%m-%d) | \
  grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "Started job: $JOB_ID"

# Poll status every 30 seconds
while true; do
  STATUS=$(fab job run-status "$NOTEBOOK" --id "$JOB_ID" | \
    grep -o '"status": "[^"]*"' | cut -d'"' -f4)

  echo "[$(date +%H:%M:%S)] Status: $STATUS"

  if [[ "$STATUS" == "Completed" ]] || [[ "$STATUS" == "Failed" ]]; then
    break
  fi

  sleep 30
done

if [[ "$STATUS" == "Completed" ]]; then
  echo "Job completed successfully"
  exit 0
else
  echo "Job failed"
  exit 1
fi
```

### Conditional Notebook Execution

```bash
#!/bin/bash

WORKSPACE="Production.Workspace"

# Check if data is ready
DATA_READY=$(fab api "workspaces/<ws-id>/lakehouses/<lh-id>/Files/ready.flag" 2>&1 | grep -c "200")

if [ "$DATA_READY" -eq 1 ]; then
  echo "Data ready, running notebook..."
  fab job run "$WORKSPACE/Process Data.Notebook" -P date:string=$(date +%Y-%m-%d)
else
  echo "Data not ready, skipping execution"
fi
```

## Notebook Definition Structure

Notebook definition contains:

NotebookName.Notebook/
├── .platform                  # Git integration metadata
├── notebook-content.py        # Python code (or .ipynb format)
└── metadata.json             # Notebook metadata

### Query Notebook Content

```bash
NOTEBOOK="Production.Workspace/ETL.Notebook"

# Get Python code content
fab get "$NOTEBOOK" -q "definition.parts[?path=='notebook-content.py'].payload | [0]" | base64 -d

# Get metadata
fab get "$NOTEBOOK" -q "definition.parts[?path=='metadata.json'].payload | [0]" | base64 -d | jq .
```

## Troubleshooting

### Notebook Execution Failures

```bash
# Check recent execution
fab job run-list "Production.Workspace/ETL.Notebook" | head -n 5

# Get detailed error
fab job run-status "Production.Workspace/ETL.Notebook" --id <job-id> -q "error"

# Common issues:
# - Lakehouse not attached
# - Invalid parameters
# - Spark configuration errors
# - Missing dependencies
```

### Parameter Type Mismatches

```bash
# Parameters must match expected types
# ❌ Wrong: -P count:string=100    (should be int)
# ✅ Right: -P count:int=100

# Check notebook definition for parameter types
fab get "Production.Workspace/ETL.Notebook" -q "definition.parts[?path=='notebook-content.py']"
```

### Lakehouse Access Issues

```bash
# Verify lakehouse exists and is accessible
fab exists "Production.Workspace/MainLakehouse.Lakehouse"

# Check notebook's lakehouse configuration
fab get "Production.Workspace/ETL.Notebook" -q "properties.lakehouse"

# Re-attach lakehouse
fab set "Production.Workspace/ETL.Notebook" -q lakehouse -i '{
  "known_lakehouses": [{"id": "<lakehouse-id>"}],
  "default_lakehouse": "<lakehouse-id>",
  "default_lakehouse_name": "MainLakehouse",
  "default_lakehouse_workspace_id": "<workspace-id>"
}'
```

## Reducing Spark Cold Start Times

Spark cold starts (2-5 minutes) are the main pain point when running notebooks via `fab job run`. Options from fastest to slowest:

| Scenario | Approach | Expected startup |
|----------|----------|-----------------|
| No custom libs, no VNet | Starter pool (default) | 5-10s |
| Custom libs, scheduled work | Custom Live Pool + Full mode env | ~5s |
| Many notebooks, same config | High Concurrency Mode | First: normal; rest: instant |
| Don't need Spark | Python notebook kernel | ~5s |
| Custom libs, no live pool | Full mode environment | 1-3 min |
| Private Link / Managed VNet | Custom pool (unavoidable) | 2-5 min |

### Starter Pools (Default)

Pre-warmed, Microsoft-managed. Fast (~5-10s) if all conditions are met:
- No custom libraries or Spark properties
- Medium node size (8 vCore / 64 GB)
- No Private Links or Managed VNets

Any of those conditions forces on-demand provisioning (2-5 min).

### Custom Live Pools (Best for Scheduled Workloads)

Pre-warmed clusters on a schedule with libraries pre-baked:

1. Workspace Settings > Data Engineering > Spark Settings > Pool > New Pool
2. Attach an Environment with libraries published in **Full mode**
3. Enable Live Pool schedule covering working hours (add 60-90 min buffer for hydration)

Monitoring: Monitoring Hub > Environment > View Details > Live pool status

### High Concurrency Mode (Session Reuse)

Multiple notebooks share one Spark session; first pays cold start, rest attach instantly:

- **Interactive**: Run tab > Session type > "New high concurrency session"; other notebooks attach to it
- **Pipeline**: Workspace Settings > Spark > High Concurrency > enable for pipelines; use session tags to group notebooks
- Requirements: same user, same default lakehouse, same compute settings, same libraries
- Default limit: 5 notebooks per session; increase via Environment Spark property `spark.highConcurrency.max = 20`

### Python Notebooks (Skip Spark)

For workloads that fit in memory (<1GB), switch kernel to Python. Runs on a lightweight 2-core container; no Spark cluster. Pre-installed: DuckDB, Polars, Pandas, delta-rs.

### Diagnosing Slow Starts

Open notebook > session status > Session Details. Check **delay reason** and **session source** (starter pool vs on-demand). Common causes: custom Spark properties, Full mode snapshot deployment, Managed VNet.

## Best Practices

1. **Tag parameter cells**: Use "parameters" tag for injected params
2. **Handle failures gracefully**: Add error handling and logging
3. **Version control notebooks**: Export and commit to Git
4. **Use descriptive names**: Clear naming for scheduled jobs
5. **Document parameters**: Add comments explaining expected inputs
6. **Test locally first**: Validate in development workspace
7. **Monitor schedules**: Review execution history regularly
8. **Clean up old notebooks**: Remove unused notebooks
9. **Prefer DuckDB for read-only queries**: When exploring lakehouse data, DuckDB avoids Spark entirely; see [querying-data.md](./querying-data.md)

## Security Considerations

1. **Credential management**: Use Key Vault for secrets
2. **Workspace permissions**: Control who can execute notebooks
3. **Parameter validation**: Sanitize inputs in notebook code
4. **Data access**: Respect lakehouse/warehouse permissions
5. **Logging**: Don't log sensitive information

## Related Scripts

- `scripts/run_notebook_pipeline.py` - Orchestrate multiple notebooks
- `scripts/monitor_notebook.py` - Monitor long-running executions
- `scripts/export_notebook.py` - Export with validation
- `scripts/schedule_notebook.py` - Simplified scheduling interface
