# Ensure the | (pipe) operation does not cover up any underlying errors by returning the same error code as its underlying processes
set -o pipefail

# Make sure you are in the flyway folder when running this script
cd flyway

# Log into Azure and set the current subscription. Subscription ID can be located in the URL when viewing your SQL Server in the Azure Portal.
az login
az account set \
    --subscription "<INSERT YOUR SUBSCRIPTION ID HERE>"

# Acquire an access token scoped to https://database.windows.net/ and trim the quotes around it
export SQL_ACCESS_TOKEN=$(az account get-access-token --resource=https://database.windows.net/ --query accessToken | tr -d '"')

# Run flyway info to verify connectivity without making any changes
flyway \
    -locations="filesystem:./mgmt-db" \
    -url="jdbc:sqlserver://sql-server-mt-demo.database.windows.net;databaseName=mgmt-db-mt-demo;" \
    -user="" \
    -password="" \
    -jdbcProperties.accessToken=$SQL_ACCESS_TOKEN \
    info