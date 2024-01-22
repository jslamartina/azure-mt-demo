# test_flyway_with_backups.sh

# Ensure the | (pipe) operation does not cover up any underlying errors by returning the same error code as its underlying processes
set -o pipefail

export subscription_id="00000000-0000-0000-0000-000000000000"
export rg_name="rg-mt-demo"
export server_name="sql-server-mt-demo"
export pool_name="pool-mt-demo"
export mgmt_db_name="mgmt-db-mt-demo"
export mgmt_db_script_path="mgmt-db"
export tenant_db_script_path="tenant-db"
export storage_account_name="artifactstoragemtdemo"
export artifact_storage_container_name="mt-demo-artifact"
export repo_name="azure-mt-demo"

sudo apt-get install zip
sudo apt-get install unzip

git clone -b main https://github.com/jslamartina/azure-mt-demo.git
cd azure-mt-demo
export commit_sha=$(git rev-parse --short HEAD)
if [ -z "${commit_sha}" ]; then
  echo "Commit SHA is empty. Check the logs for errors."
  exit 1
fi

# Make sure you are in the flyway folder when running this script
cd flyway

# Log into Azure and set the current subscription. Subscription ID can be located in the URL when viewing your SQL Server in the Azure Portal.
az login
az account set \
  --subscription $subscription_id

# Dynamically query for a list of Tenant Databases. Send this JSON to map this to a list of names of the Tenant Databases
# We can then loop through this list and apply the scripts in the tenant-db folder
echo -e "\nQuerying for Tenant DBs..."
export TENANT_DBS=$(az sql db list -g $rg_name -s $server_name --elastic-pool $pool_name | jq '.[].name' | tr -d '"')
if [ -z "${TENANT_DBS}" ]; then
  echo "No Tenant DBs found. Check the log for errors."
  exit 1
fi

# Acquire an access token scoped to https://database.windows.net/ and trim the quotes around it
export SQL_ACCESS_TOKEN=$(az account get-access-token --resource=https://database.windows.net/ --query accessToken | tr -d '"')
if [ -z "${SQL_ACCESS_TOKEN}" ]; then
  echo "SQL Access Token is Empty. Check the log for errors."
  exit 1
fi

# Back up all of our databases in parallel, including the Management DB, to test our Flyway Migrations on
export TZ=UTC
export DATE_TIME=$(date +'%FT%T')
export DATE_TIME_TAG=$(date +'%m-%d-%Y')
export MGMT_DB_BACKUP_NAME="${mgmt_db_name}_TestMigration_${DATE_TIME}"
(
    (
        echo "Backing up ${mgmt_db_name} to ${MGMT_DB_BACKUP_NAME}..."
        az sql db restore \
            --dest-name $MGMT_DB_BACKUP_NAME \
            -g $rg_name \
            -s $server_name \
            -n $mgmt_db_name \
            -t $DATE_TIME \
            --output table \
        && echo "Restore completed succesfully for ${MGMT_DB_BACKUP_NAME}"
    ) | while IFS= read -r line; do printf '[%s]\t%s\n' "Backup: ${mgmt_db_name}" "$line"; done
) & PIDS="$PIDS $!"

for db in $TENANT_DBS; do
(
    ( 
        echo "Backing up ${db} to ${db}_TestMigration_${DATE_TIME}..."
        az sql db restore \
            --dest-name "${db}_TestMigration_${DATE_TIME}" \
            -g $rg_name \
            -s $server_name \
            -n $db \
            -t $DATE_TIME \
            --elastic-pool $pool_name \
            --output table \
        && echo " Restore completed succesfully for ${db}_TestMigration_${DATE_TIME}"
    ) | while IFS= read -r line; do printf '[%s]\t%s\n' "Backup: ${db}" "$line"; done
) & PIDS="$PIDS $!"
done

# Wait for all of the sub-shells generated above to finish and validate that they all returned with exit code 0
for PID in $PIDS; do
    wait $PID || let "RESULT=1"
done
PIDS=""
echo -e "\nDone backing up DBs\n"

# Once they are done backing up, run the migrations against them. Don't do this if any of the restores failed.
if [ $RESULT != 1 ]; then
  (
      (
          echo "Testing migrations on ${MGMT_DB_BACKUP_NAME}..."
          flyway \
              -locations="filesystem:./${mgmt_db_script_path}" \
              -url="jdbc:sqlserver://$server_name.database.windows.net;databaseName=${MGMT_DB_BACKUP_NAME};" \
              -user="" \
              -password="" \
              -jdbcProperties.accessToken=$SQL_ACCESS_TOKEN \
              migrate \
          && echo "Migrations applied succesfully to ${MGMT_DB_BACKUP_NAME}..."
      ) | while IFS= read -r line; do printf '[%s]\t%s\n' "Apply Migrations: ${MGMT_DB_BACKUP_NAME}" "$line"; done
  ) & PIDS="$PIDS $!"

  for db in $TENANT_DBS; do
  (
      (
          echo "Testing migrations on ${db}_TestMigration_${DATE_TIME}..."
          flyway \
              -locations="filesystem:./${tenant_db_script_path}" \
              -url="jdbc:sqlserver://$server_name.database.windows.net;databaseName=${db}_TestMigration_${DATE_TIME};" \
              -user="" \
              -password="" \
              -jdbcProperties.accessToken=$SQL_ACCESS_TOKEN \
              migrate \
          && echo "Migrations applied successfully to ${db}_TestMigration_${DATE_TIME}..."
      ) | while IFS= read -r line; do printf '[%s]\t%s\n' "Apply Migrations: ${db}_TestMigration_${DATE_TIME}" "$line"; done
  ) & PIDS="$PIDS $!"
  done
fi

# Wait for all migrations to apply. Set exit status to 1 if any failed.
for PID in $PIDS; do
    wait $PID || let "RESULT=1"
done
PIDS=""
echo -e "\nAll test migrations applied successfully!"

# Finally, delete all of the DBs
(
    ( 
        echo "Deleting ${MGMT_DB_BACKUP_NAME}..." 
        az sql db delete \
            --name $MGMT_DB_BACKUP_NAME \
            -g $rg_name \
            -s $server_name \
            --output table \
            -y \
        && echo "Deleted ${MGMT_DB_BACKUP_NAME}..." 
    ) | while IFS= read -r line; do printf '[%s]\t%s\n' "Delete: ${MGMT_DB_BACKUP_NAME}" "$line"; done
) & PIDS="$PIDS $!" 

for db in $TENANT_DBS; do
(
    (
        echo "Deleting ${db}_TestMigration_${DATE_TIME}..."
        az sql db delete \
            --name "${db}_TestMigration_${DATE_TIME}" \
            -g $rg_name \
            -s $server_name \
            --output table \
            -y  \
        && echo "Deleted ${db}_TestMigration_${DATE_TIME}..."
    )  | while IFS= read -r line; do printf '[%s]\t%s\n' "Delete: ${db}_TestMigration_${DATE_TIME}" "$line"; done
) & PIDS="$PIDS $!"
done

for PID in $PIDS; do
    wait $PID || let "RESULT=1"
done
PIDS=""
if [ "$RESULT" == "1" ];
    then
    exit 1
fi

ARTIFACT_NAME="${commit_sha}.flyway.artifact.zip"
zip -r $ARTIFACT_NAME ./

echo "Uploading ${ARTIFACT_NAME} to ${artifact_storage_account_name}/${artifact_storage_container_name}"
az storage blob upload \
    -f $ARTIFACT_NAME \
    -c $artifact_storage_container_name \
    --account-name $artifact_storage_account_name \
    --overwrite true \
    --output table