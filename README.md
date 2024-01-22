Companion repository for this Medium article: [DevOps: Implement CI/CD for a Multi-Tenant Database Solution with Terraform, Azure SQL, and Flyway](https://medium.com/@jslamartina/devops-implement-a-versioned-multi-tenant-database-solution-using-terraform-azure-sql-and-df8189c5f79a)

Example use:
``` bash
sudo bash test_flyway_with_backups.sh
# Note the $commit_sha variable's value and update it in the next script prior to running
sudo bash apply_flyway.sh
```