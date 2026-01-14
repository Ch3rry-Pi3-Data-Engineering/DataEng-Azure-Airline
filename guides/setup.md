# Project Setup Guide

This project provisions Azure resources using Terraform and includes helper scripts.

## Prerequisites
- Azure CLI (az) installed and authenticated
- Terraform installed (>= 1.5)
- Python 3.10+ (for running the helper scripts)

## Azure CLI
Check your Azure CLI and login status:

```powershell
az --version
az login
az account show
```

If you need to switch subscriptions:

```powershell
az account list --output table
az account set --subscription "<subscription-id-or-name>"
az account show
```

## Terraform Setup
Check if Terraform is installed and on PATH:

```powershell
terraform version
```

Install or update Terraform on Windows:

```powershell
winget install HashiCorp.Terraform
```

```powershell
choco install terraform -y
```

After installing, re-open PowerShell and re-run terraform version.

## Project Structure
- `terraform/01_resource_group`: Azure resource group
- `terraform/02_storage_account`: ADLS Gen2 storage account + medallion containers
- `terraform/03_data_factory`: Azure Data Factory v2
- `terraform/04_adf_linked_services`: ADF linked services (HTTP via azapi + ADLS Gen2)
- `terraform/05_adf_pipeline_http`: ADF pipeline + datasets (foreach -> copy with translator parameters)
- `scripts/`: Helper scripts to deploy/destroy Terraform resources
- `guides/setup.md`: This guide
- `data/`: Local data assets
- `parameters/`: Reference JSON for pipeline parameter defaults

## Configure Terraform
The deploy script writes `terraform/01_resource_group/terraform.tfvars`,
`terraform/02_storage_account/terraform.tfvars`, and
`terraform/03_data_factory/terraform.tfvars` automatically.
If you want different defaults, edit `DEFAULTS` in `scripts/deploy.py` before running.

Example variables files:
- `terraform/01_resource_group/terraform.tfvars.example`
- `terraform/02_storage_account/terraform.tfvars.example`
- `terraform/03_data_factory/terraform.tfvars.example`
- `terraform/04_adf_linked_services/terraform.tfvars.example`
- `terraform/05_adf_pipeline_http/terraform.tfvars.example`

## Resource Naming
Resource names are built from a prefix plus a random pet suffix.
Override them by setting explicit name variables or changing the prefixes.

## Deploy Resources
From the repo root or scripts folder, run:

```powershell
python scripts\deploy.py
```

The deploy script applies the pipeline in two steps (target the pipeline resource, then full apply) to avoid ADF update ordering issues.

Optional flags:

```powershell
python scripts\deploy.py --rg-only
python scripts\deploy.py --storage-only
python scripts\deploy.py --datafactory-only
python scripts\deploy.py --adf-links-only
python scripts\deploy.py --adf-pipeline-only
```

## Destroy Resources
To tear down resources:

```powershell
python scripts\destroy.py
```

Optional flags:

```powershell
python scripts\destroy.py --rg-only
python scripts\destroy.py --storage-only
python scripts\destroy.py --datafactory-only
python scripts\destroy.py --adf-links-only
python scripts\destroy.py --adf-pipeline-only
```

## Notes
- If you run Terraform directly in a module (not via the scripts), run `terraform init` first to create/update the provider lock file.
- Storage defaults to Standard performance, LRS, ADLS Gen2 (HNS enabled), and public network access.
- Containers created by default: bronze, silver, gold.
- Linked services include an HTTP source (via azapi) and ADLS Gen2 sink (account key).
- The ADF pipeline stores the file list plus translator objects as pipeline parameters (`p_translator_*`).
- The Copy activity selects the translator per file inside the ForEach, so mappings are dynamic.
- ADF Studio may show an empty Mapping grid; verify mappings in the Copy activity JSON instead.
- The pipeline copies each HTTP CSV into `bronze/airport/<file>` using the per-file translator.
- Data Factory is provisioned as v2 with a random pet suffix by default.
- Terraform state and tfvars files are gitignored by default.
- The random suffix keeps resource names unique per deployment.
