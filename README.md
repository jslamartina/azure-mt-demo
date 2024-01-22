Companion repository for this Medium article: [DevOps: Implement CI/CD for a Multi-Tenant Database Solution with Terraform, Azure SQL, and Flyway](https://medium.com/@jslamartina/devops-implement-a-versioned-multi-tenant-database-solution-using-terraform-azure-sql-and-df8189c5f79a)

Example use:
``` bash
# In your CI step, you would run the following script to ensure that the migrations being applied will work across all Tenants
sudo bash test_flyway_with_backups.sh
# You would output the $commit_sha variable's value and give it to the CD step to download and apply the migrations
sudo bash apply_flyway.sh
```
