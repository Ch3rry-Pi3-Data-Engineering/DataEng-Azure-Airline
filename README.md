# Azure Airline Data Engineering (IaC)

Terraform-first infrastructure for an airline data engineering project on Azure.

## Quick Start
1) Install prerequisites:
   - Azure CLI (az)
   - Terraform (>= 1.5)
   - Python 3.10+

2) Authenticate to Azure:
```powershell
az login
az account show
```

3) Deploy infrastructure:
```powershell
python scripts\deploy.py
```
This deploys the resource group, storage account, data factory, ADF linked services, and the ADF pipeline.

For SQL deployments, Entra admin login defaults to the signed-in Azure CLI user if `AZUREAD_ADMIN_LOGIN` is not set. Password and client IP are auto-generated/detected if omitted and written to `terraform/07_sql_database/terraform.tfvars` (gitignored):
```powershell
$env:AZUREAD_ADMIN_LOGIN = "your.name@domain.com"
$env:SQL_ADMIN_LOGIN = "sqladmin"
```


## Architecture Overview
```mermaid
flowchart LR
    RG[Resource group] --> SA["ADLS Gen2 (project storage)"]
    SA --> B[bronze]
    SA --> S[silver]
    SA --> G[gold]
    RG --> ADF[Data Factory]
    ADF --> SA
```

## Resource Naming
Resources use a prefix plus a random pet suffix for uniqueness, for example:
`rg-airline-cool-otter`
`stairlinecoolotter`
`adf-airline-cool-otter`
Set `resource_group_name` in `terraform/01_resource_group/terraform.tfvars` (or edit defaults in `scripts/deploy.py`) to override.

## Project Structure
- `terraform/01_resource_group`: Azure resource group
- `terraform/02_storage_account`: ADLS Gen2 storage account + medallion containers
- `terraform/03_data_factory`: Azure Data Factory v2
- `terraform/04_adf_linked_services`: ADF linked services (HTTP via azapi + SQL + ADLS Gen2)
- `terraform/05_adf_pipeline_http`: ADF pipeline + datasets (foreach -> copy with translator parameters)
- `terraform/06_adf_pipeline_airport_json`: ADF pipeline + datasets (web -> copy for JSON airport data)
- `terraform/07_sql_database`: Azure SQL Server + database
- `terraform/08_adf_pipeline_fact_bookings_incremental`: ADF pipeline + datasets (SQL incremental load -> parquet)
- `scripts/`: Deploy/destroy helpers (auto-writes terraform.tfvars)
- `guides/setup.md`: Detailed setup guide
- `data/`: Local data assets
- `parameters/`: Reference JSON for pipeline parameter defaults

Example variables files:
- `terraform/01_resource_group/terraform.tfvars.example`
- `terraform/02_storage_account/terraform.tfvars.example`
- `terraform/03_data_factory/terraform.tfvars.example`
- `terraform/04_adf_linked_services/terraform.tfvars.example`
- `terraform/05_adf_pipeline_http/terraform.tfvars.example`
- `terraform/06_adf_pipeline_airport_json/terraform.tfvars.example`
- `terraform/07_sql_database/terraform.tfvars.example`
- `terraform/08_adf_pipeline_fact_bookings_incremental/terraform.tfvars.example`

## ADF Pipeline Mapping
The pipeline uses translator objects as pipeline parameters (`p_translator_airline`, `p_translator_flight`, `p_translator_passenger`).
The Copy activity chooses the translator per file inside the ForEach, so the mapping is dynamic.
ADF Studio may not render these mappings in the grid; check the Copy activity JSON if you need to verify.

## ADF Airport JSON Pipeline
The airport pipeline runs a Web activity (GET) followed by a Copy activity that writes JSON to ADLS.
The source and sink datasets use JSON schema imported from `data/DimAirport.json`.

## ADF FactBookings Incremental Pipeline
The bookings pipeline reads the last load marker from `bronze/monitor/lastload/last_load.json`,
queries `dbo.FactBookings` for new rows, writes Parquet into `bronze/airport`, and updates the marker.

## Azure SQL
The SQL module provisions an Azure SQL Server + database. After deployment, you can initialize the schema by running `sql_scripts/fact_bookings_full.sql` via `sqlcmd` or the Azure Portal Query Editor. Run `python scripts\deploy.py --sql-only --sql-init` to execute it via `sqlcmd`.

## Deploy/Destroy Options
Deploy:
```powershell
python scripts\deploy.py
python scripts\deploy.py --rg-only
python scripts\deploy.py --storage-only
python scripts\deploy.py --sql-only
python scripts\deploy.py --datafactory-only
python scripts\deploy.py --adf-links-only
python scripts\deploy.py --adf-pipeline-only
python scripts\deploy.py --adf-airport-pipeline-only
python scripts\deploy.py --adf-bookings-pipeline-only
python scripts\deploy.py --sql-only --sql-init
python scripts\deploy.py --skip-sql-init
```

Destroy:
```powershell
python scripts\destroy.py
python scripts\destroy.py --rg-only
python scripts\destroy.py --storage-only
python scripts\destroy.py --sql-only
python scripts\destroy.py --datafactory-only
python scripts\destroy.py --adf-links-only
python scripts\destroy.py --adf-pipeline-only
python scripts\destroy.py --adf-airport-pipeline-only
python scripts\destroy.py --adf-bookings-pipeline-only
```

## Guide
See `guides/setup.md` for detailed instructions.
