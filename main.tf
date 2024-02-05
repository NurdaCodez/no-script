provider "google" {
  project = var.project
  # credentials = file("./cred.json")
}

terraform {
 backend "gcs" {
   bucket  = "nur23-bucket-23"
   prefix  = "terraform/state"
 }
}


resource "google_sql_database_instance" "instance1" {
  name             = var.promote_to_new_primary ? "new-primary" : "old-primary"
  region               = var.promote_to_new_primary ? "us-east4" : "us-central1"
  database_version     = "POSTGRES_14"
  settings {
    tier = "db-f1-micro"
    disk_type = "PD_HDD"
    disk_size = "10"
  }

  lifecycle {
    ignore_changes = all
  }


}

resource "google_sql_database" "db" {
  name     = "test-db"
  instance = google_sql_database_instance.instance1.name

}


resource "google_sql_user" "user" {
  name     = "test-user"
  instance = google_sql_database_instance.instance1.name
  password = var.db_password
  lifecycle {
    ignore_changes = all
  }
}


resource "google_sql_database_instance" "instance2" {
  name             = var.promote_to_new_primary ? "old-primary${var.instance_name}" : "new-primary"
  master_instance_name = google_sql_database_instance.instance1.name
  region               = var.promote_to_new_primary ? "us-central1" : "us-east1"
  database_version     = "POSTGRES_14"

  replica_configuration {
    failover_target = false
  }

  settings {
    tier = "db-f1-micro"
    disk_type = "PD_HDD"
    disk_size = "10"
  }
lifecycle {
  ignore_changes = all 
}
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
}

resource "google_compute_instance" "default" {
  provider = google
  name = "default"
  machine_type = "e2-micro"
  zone = "us-central1-b"

  network_interface {
    network = "default"
        access_config {
          nat_ip = google_compute_address.static.address
            }
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-focal-v20220712"
    }
  }

  # allow_stopping_for_update = 

   service_account {
     # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
     email  = google_service_account.default.email
     scopes = ["cloud-platform"]
   }

 connection {
    user        = "ubuntu"
    agent       = false
    private_key = tls_private_key.ssh.private_key_pem
    host        = self.network_interface.0.access_config.0.nat_ip
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.ssh.public_key_openssh}"
  }

    metadata_startup_script = <<-EOF
    #!/bin/bash
    # Your post-promotion logic here
    # sudo snap install google-cloud-sdk --classic
    # sudo snap install terraform --classic
    # echo "it has worked" > cat.txt
    # gcloud auth login
    # terraform state rm google_sql_database_instance.instance2

    # # import the new-primary as "instance1"
    # terraform state rm google_sql_database_instance.instance1
    # terraform import google_sql_database_instance.instance1 your-project-id/new-primary

    # # import the new-primary db as "db"
    # terraform state rm google_sql_database.db
    # terraform import google_sql_database.db your-project-id/new-primary/test-db

    # # import the new-primary user as "db"
    # terraform state rm google_sql_user.user
    # terraform import google_sql_user.user your-project-id/new-primary/test-user
  EOF

lifecycle {
  ignore_changes = all
}

depends_on = [ google_sql_database_instance.instance1, google_sql_database_instance.instance2 ]

}

resource "null_resource" "configure_vm" {
  connection {
    user        = "ubuntu"
    agent       = false
    private_key = tls_private_key.ssh.private_key_pem
    host        = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
  }

    provisioner "file" {
    source      = "./cred.json"
    destination = "/tmp/credentials.json"
  }

    provisioner "remote-exec" {
      inline = [
        "sudo snap install terraform --classic",
        "terraform --help",
        "gcloud auth activate-service-account --key-file=/tmp/credentials.json --quiet",
        # "gcloud sql instances promote-replica new-primary --project=playground-s-11-76fcabeb --quiet",
        "git clone https://github.com/NurdaCodez/no-script.git",
        "cd no-script",
#credentials
        "export GOOGLE_APPLICATION_CREDENTIALS=/tmp/credentials.json",
#init        
        "terraform init",
        "terraform plan -var='promote_to_new_primary=true' -lock=false",
#state rm 
        "terraform state rm google_sql_database_instance.instance2",
        "terraform state rm google_sql_database_instance.instance1",
        "terraform state rm google_sql_database.db",
        "terraform state rm google_sql_user.user",
#state import  
        "terraform import google_sql_database_instance.instance1 playground-s-11-76fcabeb/new-primary",
        "terraform import google_sql_database.db playground-s-11-76fcabeb/new-primary/test-db",
        "terraform import google_sql_user.user playground-s-11-76fcabeb/new-primary/test-user",
#plan and apply        
        "terraform plan -var='promote_to_new_primary=true' -lock=false",
        "terraform apply -var='promote_to_new_primary=true' -lock=false",

      ]
    }
    }

resource "google_compute_address" "static" {
  name = "reserved-ip"
  project = var.project
  region = "us-central1"
  address_type = "EXTERNAL"   
}

resource "google_service_account" "default" {
  account_id   = "sa-gce"
  project = var.project
  display_name = "Service Account"
}




# data "google_compute_instance" "gce" {
#   name = "default"
#   zone = google_compute_instance.default.zone
# }

# data "google_iam_policy" "admin" {
#   binding {
#     role    = "roles/storage.admin"
#     members = ["serviceAccount:${google_compute_instance.default.service_account[0].email}"]
#   }
# }



# resource "google_project_iam_policy" "project" {
#   project     = google_compute_instance.default.project
#   policy_data = data.google_iam_policy.admin.policy_data
# }



# output "gce_sa" {
#   value = data.google_compute_instance.gce.service_account[0].email
  
# }