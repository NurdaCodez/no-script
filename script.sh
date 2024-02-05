#!/bin/bash

# Install Terraform
sudo snap install terraform --classic

# Authenticate with Google Cloud using service account (non-interactively)
gcloud auth activate-service-account --key-file=/tmp/credentials.json --quiet

# Promote the specified replica to primary
gcloud sql instances promote-replica new-primary --project=playground-s-11-76fcabeb

# Clone the Terraform configuration repository
git clone https://github.com/NurdaCodez/no-script.git
cd no-script

# Set the credentials environment variable
export GOOGLE_APPLICATION_CREDENTIALS=/tmp/credentials.json

# Initialize Terraform
terraform init

# Remove unnecessary Terraform state
terraform state rm google_sql_database_instance.instance2
terraform state rm google_sql_database_instance.instance1
terraform state rm google_sql_database.db
terraform state rm google_sql_user.user

# Import resources into Terraform state
terraform import google_sql_database_instance.instance1 playground-s-11-76fcabeb/new-primary
terraform import google_sql_database.db playground-s-11-76fcabeb/new-primary/test-db
terraform import google_sql_user.user playground-s-11-76fcabeb/new-primary/test-user

# Plan and apply Terraform changes, promoting to new primary
terraform plan -var='promote_to_new_primary=true'
terraform apply -var='promote_to_new_primary=true' -auto-approve
