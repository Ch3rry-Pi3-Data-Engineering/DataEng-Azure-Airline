import argparse
import json
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
    "linked_services_description": "Linked services for HTTP source, SQL, and ADLS Gen2 sink",
    "sql_linked_service_name_prefix": "ls-sql-airline",
    "pipeline_name_prefix": "pl-airline-http",
    "http_dataset_name_prefix": "ds_http_airline",
    "sink_dataset_name_prefix": "ds_adls_bronze_airline",
    "sink_file_system": "bronze",
    "airport_pipeline_name_prefix": "pl-airline-airport-json",
    "http_airport_dataset_name_prefix": "ds_http_airport_json",
    "sink_airport_dataset_name_prefix": "ds_adls_bronze_airport_json",
    "airport_url": "https://raw.githubusercontent.com/Ch3rry-Pi3-Data-Engineering/DataEng-Azure-Airline/refs/heads/main/data/DimAirport.json",
    "airport_rel_url": "Ch3rry-Pi3-Data-Engineering/DataEng-Azure-Airline/refs/heads/main/data/DimAirport.json",
    "airport_sink_folder": "airport",
    "airport_sink_file": "airport.json",
    "bookings_pipeline_name_prefix": "pl-airline-bookings",
    "bookings_sql_dataset_name_prefix": "ds_sql_airline",
    "bookings_json_dataset_name_prefix": "ds_json_airline",
    "bookings_parquet_dataset_name_prefix": "ds_parquet_airline",
    "monitor_container": "bronze",
    "monitor_empty_folder": "monitor/emptyjson",
    "monitor_empty_file": "empty.json",
    "monitor_lastload_folder": "monitor/lastload",
    "monitor_lastload_file": "last_load.json",
    "bookings_sink_container": "bronze",
    "bookings_sink_folder": "airport",
    "bookings_sink_file": "fact_bookings.parquet",
    "bookings_sql_schema": "dbo",
    "bookings_sql_table": "FactBookings",
    "master_pipeline_name_prefix": "pl-airline-master",
    "silver_pipeline_name_prefix": "pl-airline-silver-dataflow",
    "dataflow_name_prefix": "df-airline-bronze-silver",
    "dataflow_source_container": "bronze",
    "dataflow_source_folder": "airport",
    "dataflow_airline_source_file": "airline.csv",
    "dataflow_flight_source_file": "flight.csv",
    "dataflow_passenger_source_file": "passenger.csv",
    "dataflow_airport_source_file": "airport.json",
    "dataflow_bookings_source_file": "fact_bookings.parquet",
    "dataflow_sink_container": "silver",
    "dataflow_sink_folder": "airport",
    "dataflow_airline_sink_file": "airline.parquet",
    "dataflow_flight_sink_file": "flight.parquet",
    "dataflow_passenger_sink_file": "passenger.parquet",
    "dataflow_airport_sink_file": "airport.parquet",
    "dataflow_bookings_sink_file": "fact_bookings.parquet",
    "gold_dataflow_name_prefix": "df-airline-gold-sales",
    "gold_source_container": "silver",
    "gold_source_folder": "airport",
    "gold_airline_source_file": "airline.parquet",
    "gold_bookings_source_file": "fact_bookings.parquet",
    "gold_sink_container": "gold",
    "gold_sink_folder": "airport",
    "gold_sink_name": "airline_sales_top5",
    "sql_server_name_prefix": "sql-airline",
    "sql_admin_login": "sqladmin",
    "sql_database_name": "airline-dev",
    "sql_database_sku_name": "GP_S_Gen5_1",
    "sql_max_size_gb": 1,
    "sql_min_capacity": 0.5,
    "sql_auto_pause_delay_in_minutes": 60,
    "sql_public_network_access_enabled": True,
    "sql_zone_redundant": False,
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


def read_tfvars_value(path, key):
    if not path.exists():
        return None
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        name, value = stripped.split("=", 1)
        if name.strip() != key:
            continue
        value = value.strip()
        if value == "null":
            return None
        if value.startswith("\"") and value.endswith("\""):
            return value[1:-1].replace("\\\"", "\"")
        return value
    return None


def get_azuread_admin_login(sql_dir):
    env_value = os.environ.get("AZUREAD_ADMIN_LOGIN")
    if env_value:
        return env_value
    existing = read_tfvars_value(sql_dir / "terraform.tfvars", "azuread_admin_login")
    if existing:
        return existing
    user_login, _ = resolve_signed_in_user()
    if user_login:
        return user_login
    raise RuntimeError("AZUREAD_ADMIN_LOGIN not found for SQL destroy.")


def get_azuread_admin_object_id(sql_dir):
    env_value = os.environ.get("AZUREAD_ADMIN_OBJECT_ID")
    if env_value:
        return env_value
    existing = read_tfvars_value(sql_dir / "terraform.tfvars", "azuread_admin_object_id")
    if existing:
        return existing
    _, user_object_id = resolve_signed_in_user()
    return user_object_id


def get_sql_admin_password(sql_dir):
    env_password = os.environ.get("SQL_ADMIN_PASSWORD")
    if env_password:
        return env_password
    existing = read_tfvars_value(sql_dir / "terraform.tfvars", "sql_admin_password")
    if existing:
        return existing
    raise RuntimeError("SQL admin password not found for SQL destroy.")


def get_sql_admin_login(sql_dir):
    env_login = os.environ.get("SQL_ADMIN_LOGIN")
    if env_login:
        return env_login
    existing = read_tfvars_value(sql_dir / "terraform.tfvars", "sql_admin_login")
    if existing:
        return existing
    return DEFAULTS["sql_admin_login"]


def get_sql_client_ip(sql_dir):
    env_ip = os.environ.get("SQL_CLIENT_IP")
    if env_ip:
        return env_ip
    existing = read_tfvars_value(sql_dir / "terraform.tfvars", "client_ip_address")
    if existing:
        return existing
    return None


def get_output_optional(tf_dir, output_name):
    output = run_capture_optional(["terraform", f"-chdir={tf_dir}", "-no-color", "output", "-raw", output_name])
    if output:
        return output
    return get_output_from_state(tf_dir, output_name)


def get_tfstate_path(tf_dir):
    workspace = run_capture_optional(["terraform", f"-chdir={tf_dir}", "workspace", "show"])
    if workspace and workspace != "default":
        workspace_state = tf_dir / "terraform.tfstate.d" / workspace / "terraform.tfstate"
        if workspace_state.exists():
            return workspace_state
    default_state = tf_dir / "terraform.tfstate"
    if default_state.exists():
        return default_state
    return None


def get_output_from_state(tf_dir, output_name):
    state_path = get_tfstate_path(tf_dir)
    if not state_path or not state_path.exists():
        return None
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    outputs = state.get("outputs", {})
    if output_name not in outputs:
        return None
    value = outputs[output_name].get("value")
    if value is None or value == "null":
        return None
    if isinstance(value, (dict, list)):
        return json.dumps(value)
    return str(value)


def get_rg_name(rg_dir):
    run(["terraform", f"-chdir={rg_dir}", "init"])
    return get_output_optional(rg_dir, "resource_group_name")


def resolve_rg_name(rg_dir, storage_dir, data_factory_dir, sql_dir=None):
    rg_name = get_rg_name(rg_dir)
    if rg_name:
        return rg_name
    rg_name = os.environ.get("RESOURCE_GROUP_NAME") or os.environ.get("RG_NAME")
    if rg_name:
        return rg_name
    rg_name = read_tfvars_value(storage_dir / "terraform.tfvars", "resource_group_name")
    if rg_name:
        return rg_name
    rg_name = read_tfvars_value(data_factory_dir / "terraform.tfvars", "resource_group_name")
    if rg_name:
        return rg_name
    if sql_dir is not None:
        rg_name = read_tfvars_value(sql_dir / "terraform.tfvars", "resource_group_name")
        if rg_name:
            return rg_name
    return None


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


def write_sql_tfvars(sql_dir, rg_name):
    admin_login = get_sql_admin_login(sql_dir)
    admin_password = get_sql_admin_password(sql_dir)
    azuread_admin_login = get_azuread_admin_login(sql_dir)
    azuread_admin_object_id = get_azuread_admin_object_id(sql_dir)
    client_ip_address = get_sql_client_ip(sql_dir)
    items = [
        ("resource_group_name", rg_name),
        ("location", DEFAULTS["location"]),
        ("sql_server_name_prefix", DEFAULTS["sql_server_name_prefix"]),
        ("sql_admin_login", admin_login),
        ("sql_admin_password", admin_password),
        ("azuread_admin_login", azuread_admin_login),
        ("azuread_admin_object_id", azuread_admin_object_id),
        ("client_ip_address", client_ip_address),
        ("database_name", DEFAULTS["sql_database_name"]),
        ("database_sku_name", DEFAULTS["sql_database_sku_name"]),
        ("max_size_gb", DEFAULTS["sql_max_size_gb"]),
        ("min_capacity", DEFAULTS["sql_min_capacity"]),
        ("auto_pause_delay_in_minutes", DEFAULTS["sql_auto_pause_delay_in_minutes"]),
        ("public_network_access_enabled", DEFAULTS["sql_public_network_access_enabled"]),
        ("zone_redundant", DEFAULTS["sql_zone_redundant"]),
    ]
    write_tfvars(sql_dir / "terraform.tfvars", items)


def write_adf_linked_services_tfvars(linked_services_dir, data_factory_dir, storage_dir, sql_dir):
    data_factory_id = get_output_optional(data_factory_dir, "data_factory_id")
    storage_dfs_endpoint = get_output_optional(storage_dir, "primary_dfs_endpoint")
    storage_account_key = get_output_optional(storage_dir, "storage_account_primary_access_key")
    sql_server_fqdn = get_output_optional(sql_dir, "sql_server_fqdn")
    sql_database_name = get_output_optional(sql_dir, "sql_database_name")
    sql_username = get_sql_admin_login(sql_dir)
    sql_password = get_sql_admin_password(sql_dir)
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for linked services destroy.")
    if not storage_dfs_endpoint or not storage_account_key:
        raise RuntimeError("Storage outputs not found for linked services destroy.")
    if not sql_server_fqdn or not sql_database_name:
        raise RuntimeError("SQL outputs not found for linked services destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("http_linked_service_name_prefix", DEFAULTS["http_linked_service_name_prefix"]),
        ("http_base_url", DEFAULTS["http_base_url"]),
        ("http_authentication_type", DEFAULTS["http_authentication_type"]),
        ("http_enable_certificate_validation", DEFAULTS["http_enable_certificate_validation"]),
        ("adls_linked_service_name_prefix", DEFAULTS["adls_linked_service_name_prefix"]),
        ("storage_dfs_endpoint", storage_dfs_endpoint),
        ("storage_account_key", storage_account_key),
        ("sql_linked_service_name_prefix", DEFAULTS["sql_linked_service_name_prefix"]),
        ("sql_server_fqdn", sql_server_fqdn),
        ("sql_database_name", sql_database_name),
        ("sql_username", sql_username),
        ("sql_password", sql_password),
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
        ("sink_dataset_name_prefix", DEFAULTS["sink_dataset_name_prefix"]),
        ("sink_file_system", DEFAULTS["sink_file_system"]),
    ]
    write_tfvars(pipeline_dir / "terraform.tfvars", items)


def write_adf_airport_pipeline_tfvars(pipeline_dir, data_factory_dir, linked_services_dir):
    data_factory_id = get_output_optional(data_factory_dir, "data_factory_id")
    http_linked_service_name = get_output_optional(linked_services_dir, "http_linked_service_name")
    adls_linked_service_name = get_output_optional(linked_services_dir, "adls_linked_service_name")
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for airport pipeline destroy.")
    if not http_linked_service_name or not adls_linked_service_name:
        raise RuntimeError("Linked service outputs not found for airport pipeline destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("http_linked_service_name", http_linked_service_name),
        ("adls_linked_service_name", adls_linked_service_name),
        ("pipeline_name_prefix", DEFAULTS["airport_pipeline_name_prefix"]),
        ("http_dataset_name_prefix", DEFAULTS["http_airport_dataset_name_prefix"]),
        ("sink_dataset_name_prefix", DEFAULTS["sink_airport_dataset_name_prefix"]),
        ("sink_file_system", DEFAULTS["sink_file_system"]),
        ("sink_folder", DEFAULTS["airport_sink_folder"]),
        ("sink_file", DEFAULTS["airport_sink_file"]),
        ("airport_url", DEFAULTS["airport_url"]),
        ("airport_rel_url", DEFAULTS["airport_rel_url"]),
    ]
    write_tfvars(pipeline_dir / "terraform.tfvars", items)


def write_adf_bookings_pipeline_tfvars(pipeline_dir, data_factory_dir, linked_services_dir):
    data_factory_id = get_output_optional(data_factory_dir, "data_factory_id")
    sql_linked_service_name = get_output_optional(linked_services_dir, "sql_linked_service_name")
    adls_linked_service_name = get_output_optional(linked_services_dir, "adls_linked_service_name")
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for bookings pipeline destroy.")
    if not sql_linked_service_name or not adls_linked_service_name:
        raise RuntimeError("Linked service outputs not found for bookings pipeline destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("sql_linked_service_name", sql_linked_service_name),
        ("adls_linked_service_name", adls_linked_service_name),
        ("pipeline_name_prefix", DEFAULTS["bookings_pipeline_name_prefix"]),
        ("sql_dataset_name_prefix", DEFAULTS["bookings_sql_dataset_name_prefix"]),
        ("json_dataset_name_prefix", DEFAULTS["bookings_json_dataset_name_prefix"]),
        ("parquet_dataset_name_prefix", DEFAULTS["bookings_parquet_dataset_name_prefix"]),
        ("monitor_container", DEFAULTS["monitor_container"]),
        ("monitor_empty_folder", DEFAULTS["monitor_empty_folder"]),
        ("monitor_empty_file", DEFAULTS["monitor_empty_file"]),
        ("monitor_lastload_folder", DEFAULTS["monitor_lastload_folder"]),
        ("monitor_lastload_file", DEFAULTS["monitor_lastload_file"]),
        ("sink_container", DEFAULTS["bookings_sink_container"]),
        ("sink_folder", DEFAULTS["bookings_sink_folder"]),
        ("sink_file", DEFAULTS["bookings_sink_file"]),
        ("sql_schema", DEFAULTS["bookings_sql_schema"]),
        ("sql_table", DEFAULTS["bookings_sql_table"]),
    ]
    write_tfvars(pipeline_dir / "terraform.tfvars", items)


def write_adf_master_pipeline_tfvars(
    pipeline_dir,
    data_factory_dir,
    http_pipeline_dir,
    airport_pipeline_dir,
    bookings_pipeline_dir,
    silver_pipeline_dir,
):
    data_factory_id = get_output_optional(data_factory_dir, "data_factory_id")
    http_pipeline_name = get_output_optional(http_pipeline_dir, "pipeline_name")
    airport_pipeline_name = get_output_optional(airport_pipeline_dir, "pipeline_name")
    bookings_pipeline_name = get_output_optional(bookings_pipeline_dir, "pipeline_name")
    silver_pipeline_name = get_output_optional(silver_pipeline_dir, "pipeline_name")
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for master pipeline destroy.")
    if not http_pipeline_name or not airport_pipeline_name or not bookings_pipeline_name or not silver_pipeline_name:
        raise RuntimeError("Pipeline outputs not found for master pipeline destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("http_pipeline_name", http_pipeline_name),
        ("airport_pipeline_name", airport_pipeline_name),
        ("bookings_pipeline_name", bookings_pipeline_name),
        ("silver_pipeline_name", silver_pipeline_name),
        ("pipeline_name_prefix", DEFAULTS["master_pipeline_name_prefix"]),
        ("airport_url", DEFAULTS["airport_url"]),
        ("airport_rel_url", DEFAULTS["airport_rel_url"]),
    ]
    write_tfvars(pipeline_dir / "terraform.tfvars", items)


def write_adf_dataflow_tfvars(
    dataflow_dir,
    data_factory_dir,
    linked_services_dir,
):
    data_factory_id = get_output_optional(data_factory_dir, "data_factory_id")
    adls_linked_service_name = get_output_optional(linked_services_dir, "adls_linked_service_name")
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for data flow destroy.")
    if not adls_linked_service_name:
        raise RuntimeError("ADLS linked service output not found for data flow destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("adls_linked_service_name", adls_linked_service_name),
        ("dataflow_name_prefix", DEFAULTS["dataflow_name_prefix"]),
        ("source_container", DEFAULTS["dataflow_source_container"]),
        ("source_folder", DEFAULTS["dataflow_source_folder"]),
        ("airline_source_file", DEFAULTS["dataflow_airline_source_file"]),
        ("flight_source_file", DEFAULTS["dataflow_flight_source_file"]),
        ("passenger_source_file", DEFAULTS["dataflow_passenger_source_file"]),
        ("airport_source_file", DEFAULTS["dataflow_airport_source_file"]),
        ("bookings_source_file", DEFAULTS["dataflow_bookings_source_file"]),
        ("sink_container", DEFAULTS["dataflow_sink_container"]),
        ("sink_folder", DEFAULTS["dataflow_sink_folder"]),
        ("airline_sink_file", DEFAULTS["dataflow_airline_sink_file"]),
        ("flight_sink_file", DEFAULTS["dataflow_flight_sink_file"]),
        ("passenger_sink_file", DEFAULTS["dataflow_passenger_sink_file"]),
        ("airport_sink_file", DEFAULTS["dataflow_airport_sink_file"]),
        ("bookings_sink_file", DEFAULTS["dataflow_bookings_sink_file"]),
    ]
    write_tfvars(dataflow_dir / "terraform.tfvars", items)


def write_adf_gold_dataflow_tfvars(
    dataflow_dir,
    data_factory_dir,
    linked_services_dir,
):
    data_factory_id = get_output_optional(data_factory_dir, "data_factory_id")
    adls_linked_service_name = get_output_optional(linked_services_dir, "adls_linked_service_name")
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for gold data flow destroy.")
    if not adls_linked_service_name:
        raise RuntimeError("ADLS linked service output not found for gold data flow destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("adls_linked_service_name", adls_linked_service_name),
        ("dataflow_name_prefix", DEFAULTS["gold_dataflow_name_prefix"]),
        ("source_container", DEFAULTS["gold_source_container"]),
        ("source_folder", DEFAULTS["gold_source_folder"]),
        ("airline_source_file", DEFAULTS["gold_airline_source_file"]),
        ("bookings_source_file", DEFAULTS["gold_bookings_source_file"]),
        ("sink_container", DEFAULTS["gold_sink_container"]),
        ("sink_folder", DEFAULTS["gold_sink_folder"]),
        ("sink_name", DEFAULTS["gold_sink_name"]),
    ]
    write_tfvars(dataflow_dir / "terraform.tfvars", items)


def write_adf_silver_pipeline_tfvars(
    pipeline_dir,
    data_factory_dir,
    dataflow_dir,
):
    data_factory_id = get_output_optional(data_factory_dir, "data_factory_id")
    dataflow_name = get_output_optional(dataflow_dir, "dataflow_name")
    if not data_factory_id:
        raise RuntimeError("Data Factory ID not found for silver pipeline destroy.")
    if not dataflow_name:
        raise RuntimeError("Data flow output not found for silver pipeline destroy.")
    items = [
        ("data_factory_id", data_factory_id),
        ("dataflow_name", dataflow_name),
        ("pipeline_name_prefix", DEFAULTS["silver_pipeline_name_prefix"]),
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
        group.add_argument("--sql-only", action="store_true", help="Destroy only the SQL server + database stack")
        group.add_argument("--datafactory-only", action="store_true", help="Destroy only the data factory stack")
        group.add_argument("--adf-links-only", action="store_true", help="Destroy only the ADF linked services stack")
        group.add_argument("--adf-pipeline-only", action="store_true", help="Destroy only the ADF pipeline stack")
        group.add_argument(
            "--adf-airport-pipeline-only",
            action="store_true",
            help="Destroy only the ADF airport JSON pipeline stack",
        )
        group.add_argument(
            "--adf-bookings-pipeline-only",
            action="store_true",
            help="Destroy only the ADF bookings SQL pipeline stack",
        )
        group.add_argument(
            "--adf-master-pipeline-only",
            action="store_true",
            help="Destroy only the ADF master pipeline stack",
        )
        group.add_argument(
            "--adf-dataflow-only",
            action="store_true",
            help="Destroy only the ADF bronze-to-silver data flow stack",
        )
        group.add_argument(
            "--adf-silver-pipeline-only",
            action="store_true",
            help="Destroy only the ADF silver data flow pipeline stack",
        )
        group.add_argument(
            "--adf-gold-dataflow-only",
            action="store_true",
            help="Destroy only the ADF gold data flow stack",
        )
        args = parser.parse_args()

        repo_root = Path(__file__).resolve().parent.parent
        load_env_file(repo_root / ".env")

        rg_dir = repo_root / "terraform" / "01_resource_group"
        storage_dir = repo_root / "terraform" / "02_storage_account"
        sql_dir = repo_root / "terraform" / "07_sql_database"
        data_factory_dir = repo_root / "terraform" / "03_data_factory"
        linked_services_dir = repo_root / "terraform" / "04_adf_linked_services"
        pipeline_dir = repo_root / "terraform" / "05_adf_pipeline_http"
        pipeline_airport_dir = repo_root / "terraform" / "06_adf_pipeline_airport_json"
        pipeline_bookings_dir = repo_root / "terraform" / "08_adf_pipeline_fact_bookings_incremental"
        pipeline_master_dir = repo_root / "terraform" / "09_adf_pipeline_master"
        dataflow_dir = repo_root / "terraform" / "10_adf_dataflow_bronze_silver"
        pipeline_silver_dir = repo_root / "terraform" / "11_adf_pipeline_silver_dataflow"
        gold_dataflow_dir = repo_root / "terraform" / "12_adf_dataflow_gold_sales"

        if args.storage_only:
            rg_name = resolve_rg_name(rg_dir, storage_dir, data_factory_dir, sql_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for storage destroy.")
            write_storage_tfvars(storage_dir, rg_name)
            destroy_stack(storage_dir)
            sys.exit(0)

        if args.sql_only:
            rg_name = resolve_rg_name(rg_dir, storage_dir, data_factory_dir, sql_dir)
            if not rg_name:
                raise RuntimeError("Resource group name not found for SQL destroy.")
            write_sql_tfvars(sql_dir, rg_name)
            destroy_stack(sql_dir)
            sys.exit(0)

        if args.datafactory_only:
            rg_name = resolve_rg_name(rg_dir, storage_dir, data_factory_dir, sql_dir)
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

        if args.adf_airport_pipeline_only:
            run(["terraform", f"-chdir={data_factory_dir}", "init"])
            run(["terraform", f"-chdir={linked_services_dir}", "init"])
            write_adf_airport_pipeline_tfvars(pipeline_airport_dir, data_factory_dir, linked_services_dir)
            destroy_stack(pipeline_airport_dir)
            sys.exit(0)

        if args.adf_bookings_pipeline_only:
            run(["terraform", f"-chdir={data_factory_dir}", "init"])
            run(["terraform", f"-chdir={linked_services_dir}", "init"])
            write_adf_bookings_pipeline_tfvars(pipeline_bookings_dir, data_factory_dir, linked_services_dir)
            destroy_stack(pipeline_bookings_dir)
            sys.exit(0)

        if args.adf_master_pipeline_only:
            run(["terraform", f"-chdir={data_factory_dir}", "init"])
            run(["terraform", f"-chdir={pipeline_dir}", "init"])
            run(["terraform", f"-chdir={pipeline_airport_dir}", "init"])
            run(["terraform", f"-chdir={pipeline_bookings_dir}", "init"])
            run(["terraform", f"-chdir={pipeline_silver_dir}", "init"])
            write_adf_master_pipeline_tfvars(
                pipeline_master_dir,
                data_factory_dir,
                pipeline_dir,
                pipeline_airport_dir,
                pipeline_bookings_dir,
                pipeline_silver_dir,
            )
            destroy_stack(pipeline_master_dir)
            sys.exit(0)

        if args.adf_dataflow_only:
            run(["terraform", f"-chdir={data_factory_dir}", "init"])
            run(["terraform", f"-chdir={linked_services_dir}", "init"])
            write_adf_dataflow_tfvars(
                dataflow_dir,
                data_factory_dir,
                linked_services_dir,
            )
            destroy_stack(dataflow_dir)
            sys.exit(0)

        if args.adf_silver_pipeline_only:
            run(["terraform", f"-chdir={data_factory_dir}", "init"])
            run(["terraform", f"-chdir={dataflow_dir}", "init"])
            write_adf_silver_pipeline_tfvars(
                pipeline_silver_dir,
                data_factory_dir,
                dataflow_dir,
            )
            destroy_stack(pipeline_silver_dir)
            sys.exit(0)

        if args.adf_gold_dataflow_only:
            run(["terraform", f"-chdir={data_factory_dir}", "init"])
            run(["terraform", f"-chdir={linked_services_dir}", "init"])
            write_adf_gold_dataflow_tfvars(
                gold_dataflow_dir,
                data_factory_dir,
                linked_services_dir,
            )
            destroy_stack(gold_dataflow_dir)
            sys.exit(0)

        if args.adf_links_only:
            run(["terraform", f"-chdir={data_factory_dir}", "init"])
            run(["terraform", f"-chdir={storage_dir}", "init"])
            run(["terraform", f"-chdir={sql_dir}", "init"])
            write_adf_linked_services_tfvars(linked_services_dir, data_factory_dir, storage_dir, sql_dir)
            destroy_stack(linked_services_dir)
            sys.exit(0)

        if args.rg_only:
            destroy_stack(rg_dir)
            sys.exit(0)

        rg_name = resolve_rg_name(rg_dir, storage_dir, data_factory_dir, sql_dir)
        if not rg_name:
            raise RuntimeError("Resource group name not found for destroy.")

        run(["terraform", f"-chdir={data_factory_dir}", "init"])
        run(["terraform", f"-chdir={storage_dir}", "init"])
        run(["terraform", f"-chdir={linked_services_dir}", "init"])
        run(["terraform", f"-chdir={sql_dir}", "init"])
        write_adf_pipeline_tfvars(pipeline_dir, data_factory_dir, linked_services_dir)
        write_adf_airport_pipeline_tfvars(pipeline_airport_dir, data_factory_dir, linked_services_dir)
        write_adf_bookings_pipeline_tfvars(pipeline_bookings_dir, data_factory_dir, linked_services_dir)
        write_adf_master_pipeline_tfvars(
            pipeline_master_dir,
            data_factory_dir,
            pipeline_dir,
            pipeline_airport_dir,
            pipeline_bookings_dir,
            pipeline_silver_dir,
        )
        write_adf_dataflow_tfvars(dataflow_dir, data_factory_dir, linked_services_dir)
        write_adf_silver_pipeline_tfvars(
            pipeline_silver_dir,
            data_factory_dir,
            dataflow_dir,
        )
        write_adf_gold_dataflow_tfvars(
            gold_dataflow_dir,
            data_factory_dir,
            linked_services_dir,
        )
        write_adf_linked_services_tfvars(linked_services_dir, data_factory_dir, storage_dir, sql_dir)
        write_data_factory_tfvars(data_factory_dir, rg_name)
        write_storage_tfvars(storage_dir, rg_name)
        write_sql_tfvars(sql_dir, rg_name)
        destroy_stack(pipeline_master_dir)
        destroy_stack(pipeline_silver_dir)
        destroy_stack(gold_dataflow_dir)
        destroy_stack(dataflow_dir)
        destroy_stack(pipeline_bookings_dir)
        destroy_stack(pipeline_airport_dir)
        destroy_stack(pipeline_dir)
        destroy_stack(linked_services_dir)
        destroy_stack(data_factory_dir)
        destroy_stack(sql_dir)
        destroy_stack(storage_dir)
        destroy_stack(rg_dir)

    except subprocess.CalledProcessError as exc:
        print(f"Command failed: {exc}")
        sys.exit(exc.returncode)
