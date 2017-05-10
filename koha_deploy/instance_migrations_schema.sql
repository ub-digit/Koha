CREATE TABLE koha_deploy_instance_migrations (
  revision TEXT PRIMARY KEY,
  migration_date DATETIME DEFAULT CURRENT_TIMESTAMP
);
