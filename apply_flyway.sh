# Ensure the | (pipe) operation does not cover up any underlying errors by returning the same error code as its underlying processes
set -o pipefail

export rg_name="rg-mt-demo"
export server_name="sql-server-mt-demo"
export pool_name="pool-mt-demo"
export commit_sha="SET THIS TO COMMIT SHA OUTPUT FROM TEST"
export mgmt_db_name="mgmt-db-mt-demo"
export mgmt_db_script_path="mgmt-db"
export tenant_db_script_path="tenant-db"
export storage_account_name="artifactstoragemtdemo"
export artifact_storage_container_name="mt-demo-artifact"
export repo_name="azure-mt-demo"

# Make sure you are in the flyway folder when running this script
cd flyway

# Log into Azure and set the current subscription. Subscription ID can be located in the URL when viewing your SQL Server in the Azure Portal.
az login
az account set \
  --subscription "<INSERT YOUR SUBSCRIPTION ID HERE>"

echo -e "\nDownloading flyway artifact..."
az storage blob download \
    --account-name $ \
    -c $artifact_storage_container_name \
    -n "${repo_name}.${commit_sha}.flyway.artifact.zip" \
    -f flyway_artifact.zip \
    --output table

echo -e "\nUnzipping artifact..."
unzip flyway_artifact.zip

# Acquire an access token scoped to https://database.windows.net/ and trim the quotes around it
export SQL_ACCESS_TOKEN=$(az account get-access-token --resource=https://database.windows.net/ --query accessToken | tr -d '"')
if [ -z "${SQL_ACCESS_TOKEN}" ]; then
  echo "SQL Access Token is Empty. Check the log for errors."
  exit 1
fi

# Run flyway info to verify connectivity without making any changes
flyway \
  -locations="filesystem:./mgmt-db" \
  -url="jdbc:sqlserver://${server_name}.database.windows.net;databaseName=mgmt-db-mt-demo;" \
  -user="" \
  -password="" \
  -jdbcProperties.accessToken=$SQL_ACCESS_TOKEN \
  migrate

# Dynamically query for a list of Tenant Databases. Send this JSON to map this to a list of names of the Tenant Databases
# We can then loop through this list and apply the scripts in the tenant-db folder
echo -e "\nQuerying for Tenant DBs..."
export TENANT_DBS=$(az sql db list -g $rg_name -s $server_name --elastic-pool $pool_name | jq '.[].name' | tr -d '"')
if [ -z "${TENANT_DBS}" ]; then
  echo "No Tenant DBs found. Check the log for errors."
  exit 1
fi

for db in $TENANT_DBS; do
(
  flyway \
    -locations="filesystem:./tenant-db" \
    -url="jdbc:sqlserver://${server_name}.database.windows.net;databaseName=${db};" \
    -user="" \
    -password="" \
    -jdbcProperties.accessToken=$SQL_ACCESS_TOKEN \
    migrate
)