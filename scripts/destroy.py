import argparse
import os
import subprocess
import sys
from pathlib import Path

DEFAULTS = {
    "location": "eastus2",
    "storage_account_name_prefix": "stairline",
    "account_replication_type": "LRS",
    "account_tier": "Standard",
    "public_network_access_enabled": True,
    "is_hns_enabled": True,
    "data_factory_name_prefix": "adf-airline",
    "http_linked_service_name_prefix": "ls-http-airline",
    "http_base_url": "https://raw.githubusercontent.com",
    "http_authentication_type": "Anonymous",
    "http_enable_certificate_validation": True,
    "adls_linked_service_name_prefix": "ls-adls-airline",
    "linked_services_description": "Linked services for HTTP source and ADLS Gen2 sink",
    "pipeline_name_prefix": "pl-airline-http",
    "http_dataset_name_prefix": "ds_http_airline",
    "parameters_dataset_name_prefix": "ds_parameters_airline",
    "sink_dataset_name_prefix": "ds_adls_bronze_airline",
    "parameters_container": "bronze",
    "parameters_path": "parameters",
    "parameters_file": "parameters.json",
    "sink_file_system": "bronze",
}


def run(cmd):
    print("\n$ " + " ".join(cmd))
    subprocess.check_call(cmd)


def run_capture(cmd):
    print("\n$ " + " ".join(cmd))
    return subprocess.check_output(cmd, text=True).strip()


def run_capture_optional(cmd):
    try:
        return run_capture(cmd)
    except subprocess.CalledProcessError:
        return None


def get_az_exe():
    return "az.cmd" if os.name == "nt" else "az"


def resolve_signed_in_user():
    az_exe = get_az_exe()
    user_login = run_capture_optional([
        az_exe,
        "account", "show",
        "--query", "user.name",
        "-o", "tsv",
    ])
    user_object_id = run_capture_optional([
        az_exe,
        "ad", "signed-in-user", "show",
        "--query", "id",
        "-o", "tsv",
    ])
    return user_login or None, user_object_id or None


def hcl_value(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (list, tuple)):
        rendered = ", ".join(hcl_value(item) for item in value)
        return f"[{rendered}]"
    escaped = str(value).replace("\"", "\\\"")
    return f"\"{escaped}\""


def write_tfvars(path, items):
    lines = [f"{key} = {hcl_value(value)}" for key, value in items]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def load_env_file(path):
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        key = key.strip()
        value = value.strip()
        if key and key not in os.environ:
            os.environ[key] = value


def get_output_optional(tf_dir, output_name):
    try:
        return run_capture(["terraform", f"-chdir={tf_dir}", "-no-color", "output", "-raw", output_name])
    except subprocess.CalledProcessError:
        return None


def get_rg_name(rg_dir):
    run(["terraform", f"-chdir={rg_dir}", "init"])
    return get_output_optional(rg_dir, "resource_group_name")


def write_storage_tfvars(storage_dir, rg_name):
    storage_blob_contributor_object_id = os.environ.get("STORAGE_BLOB_CONTRIBUTOR_OBJECT_ID")
    if not storage_blob_contributor_object_id:
        _, user_object_id = resolve_signed_in_user()
        storage_blob_contributor_object_id = user_object_id
    items = [
        ("resource_group_name", rg_name),
        ("location", DEFAULTS["location"]),
        ("storage_account_name_prefix", DEFAULTS["storage_account_name_prefix"]),
        ("account_replication_type", DEFAULTS["account_replication_type"]),
        ("account_tier", DEFAULTS["account_tier"]),
        ("public_network_access_enabled", DEFAULTS["public_network_access_enabled"]),
        ("is_hns_enabled", DEFAULTS["is_hns_enabled"]),
    ]
    if storage_blob_contributor_object_id:
        items.append(("storage_blob_contributor_object_id", storage_blob_contributor_object_id))
    write_tfvars(storage_dir / "terraform.tfvars", items)


def write_data_factory_tfvars(data_factory_dir, rg_name):
    items = [
        ("resource_group_name", rg_name),
        ("location", DEFAULTS["location"]),
        ("data_factory_name_prefix", DEFAULTS["data_factory_name_prefix"]),
    ]
    write_tfvars(data_factory_dir / "terraform.tfvars", items)


def write_adf_linked_services_tfvars(linked_services_dir, data_factory_dir, storage_dir):
    data_factory_id = get_output_optional(data_factory_dir, "data_factory_id")
    storage_dfs_endpoint = get_output_optional(storage_dir, "primary_dfs_endpoint")
    storage_account_key = get_output_optional(storage_dir, "storage_account_primary_access_key")
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for linked services destroy.")
    if not storage_dfs_endpoint or not storage_account_key:
        raise RuntimeError("Storage outputs not found for linked services destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("http_linked_service_name_prefix", DEFAULTS["http_linked_service_name_prefix"]),
        ("http_base_url", DEFAULTS["http_base_url"]),
        ("http_authentication_type", DEFAULTS["http_authentication_type"]),
        ("http_enable_certificate_validation", DEFAULTS["http_enable_certificate_validation"]),
        ("adls_linked_service_name_prefix", DEFAULTS["adls_linked_service_name_prefix"]),
        ("storage_dfs_endpoint", storage_dfs_endpoint),
        ("storage_account_key", storage_account_key),
        ("description", DEFAULTS["linked_services_description"]),
    ]
    write_tfvars(linked_services_dir / "terraform.tfvars", items)


def write_adf_pipeline_tfvars(pipeline_dir, data_factory_dir, linked_services_dir):
    data_factory_id = get_output_optional(data_factory_dir, "data_factory_id")
    http_linked_service_name = get_output_optional(linked_services_dir, "http_linked_service_name")
    adls_linked_service_name = get_output_optional(linked_services_dir, "adls_linked_service_name")
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for pipeline destroy.")
    if not http_linked_service_name or not adls_linked_service_name:
        raise RuntimeError("Linked service outputs not found for pipeline destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("http_linked_service_name", http_linked_service_name),
        ("adls_linked_service_name", adls_linked_service_name),
        ("pipeline_name_prefix", DEFAULTS["pipeline_name_prefix"]),
        ("http_dataset_name_prefix", DEFAULTS["http_dataset_name_prefix"]),
        ("parameters_dataset_name_prefix", DEFAULTS["parameters_dataset_name_prefix"]),
        ("sink_dataset_name_prefix", DEFAULTS["sink_dataset_name_prefix"]),
        ("parameters_container", DEFAULTS["parameters_container"]),
        ("parameters_path", DEFAULTS["parameters_path"]),
        ("parameters_file", DEFAULTS["parameters_file"]),
        ("sink_file_system", DEFAULTS["sink_file_system"]),
    ]
    write_tfvars(pipeline_dir / "terraform.tfvars", items)


def destroy_stack(tf_dir):
    if not tf_dir.exists():
        raise FileNotFoundError(f"Missing Terraform dir: {tf_dir}")
    run(["terraform", f"-chdir={tf_dir}", "destroy", "-auto-approve"])


if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser(description="Destroy Terraform stacks for the Airline project.")
        group = parser.add_mutually_exclusive_group()
        group.add_argument("--rg-only", action="store_true", help="Destroy only the resource group stack")
        group.add_argument("--storage-only", action="store_true", help="Destroy only the storage account stack")
        group.add_argument("--datafactory-only", action="store_true", help="Destroy only the data factory stack")
        group.add_argument("--adf-links-only", action="store_true", help="Destroy only the ADF linked services stack")
        group.add_argument("--adf-pipeline-only", action="store_true", help="Destroy only the ADF pipeline stack")
        args = parser.parse_args()

        repo_root = Path(__file__).resolve().parent.parent
        load_env_file(repo_root / ".env")

        rg_dir = repo_root / "terraform" / "01_resource_group"
        storage_dir = repo_root / "terraform" / "02_storage_account"
        data_factory_dir = repo_root / "terraform" / "03_data_factory"
        linked_services_dir = repo_root / "terraform" / "04_adf_linked_services"
        pipeline_dir = repo_root / "terraform" / "05_adf_pipeline_http"

        if args.storage_only:
            rg_name = get_rg_name(rg_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for storage destroy.")
            write_storage_tfvars(storage_dir, rg_name)
            destroy_stack(storage_dir)
            sys.exit(0)

        if args.datafactory_only:
            rg_name = get_rg_name(rg_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for data factory destroy.")
            write_data_factory_tfvars(data_factory_dir, rg_name)
            destroy_stack(data_factory_dir)
            sys.exit(0)

        if args.adf_pipeline_only:
            run(["terraform", f"-chdir={data_factory_dir}", "init"])
            run(["terraform", f"-chdir={linked_services_dir}", "init"])
            write_adf_pipeline_tfvars(pipeline_dir, data_factory_dir, linked_services_dir)
            destroy_stack(pipeline_dir)
            sys.exit(0)

        if args.adf_links_only:
            run(["terraform", f"-chdir={data_factory_dir}", "init"])
            run(["terraform", f"-chdir={storage_dir}", "init"])
            write_adf_linked_services_tfvars(linked_services_dir, data_factory_dir, storage_dir)
            destroy_stack(linked_services_dir)
            sys.exit(0)

        if args.rg_only:
            destroy_stack(rg_dir)
            sys.exit(0)

        rg_name = get_rg_name(rg_dir)
        if not rg_name:
            raise RuntimeError("Resource group name not found for destroy.")

        run(["terraform", f"-chdir={data_factory_dir}", "init"])
        run(["terraform", f"-chdir={storage_dir}", "init"])
        run(["terraform", f"-chdir={linked_services_dir}", "init"])
        write_adf_pipeline_tfvars(pipeline_dir, data_factory_dir, linked_services_dir)
        write_adf_linked_services_tfvars(linked_services_dir, data_factory_dir, storage_dir)
        write_data_factory_tfvars(data_factory_dir, rg_name)
        write_storage_tfvars(storage_dir, rg_name)
        destroy_stack(pipeline_dir)
        destroy_stack(linked_services_dir)
        destroy_stack(data_factory_dir)
        destroy_stack(storage_dir)
        destroy_stack(rg_dir)

    except subprocess.CalledProcessError as exc:
        print(f"Command failed: {exc}")
        sys.exit(exc.returncode)
