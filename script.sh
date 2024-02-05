gcloud sql instances promote-replica new-primary --project=playground-s-11-5b36ab01 --region=us-east1

terraform import google_sql_database_instance.instance1 playground-s-11-5b36ab01/new-primary

terraform state rm google_sql_database.db
terraform import google_sql_database.db playground-s-11-5b36ab01/new-primary/test-db

# import the new-primary user as "db"
terraform state rm google_sql_user.user
terraform import google_sql_user.user playground-s-11-5b36ab01/new-primary/test-user