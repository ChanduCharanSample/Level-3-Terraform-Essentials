#!/bin/bash
YELLOW=$(tput setaf 3)
BOLD=$(tput bold)
RESET=$(tput sgr0)

echo
echo "${YELLOW}${BOLD}############################################${RESET}"
echo "${YELLOW}${BOLD}#     📢 Subscribe to cloudcupcake 📢      #${RESET}"
echo "${YELLOW}${BOLD}############################################${RESET}"
echo

ZONE=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
REGION=$(gcloud compute project-info describe \
  --format="value(commonInstanceMetadata.items[google-compute-default-region])")
PROJECT_ID=$(gcloud config get-value project)


gcloud storage buckets create gs://$PROJECT_ID-tf-state --project=$PROJECT_ID --location=$REGION --uniform-bucket-level-access

gsutil versioning set on gs://$PROJECT_ID-tf-state


cat > firewall.tf <<EOF_END
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-from-anywhere"
  network = "default"
  project = "$PROJECT_ID"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-allowed"]
}
EOF_END


cat > variables.tf <<EOF_END
variable "project_id" {
  type        = string
  default     = "$PROJECT_ID"
}

variable "bucket_name" {
  type = string
  default = "$PROJECT_ID-tf-state"
}

variable "region" {
  type = string
  default = "$REGION"
}
EOF_END


cat > outputs.tf <<EOF_END
output "firewall_name" {
  value = google_compute_firewall.allow_ssh.name
}
EOF_END

terraform init

terraform plan

terraform apply --auto-approve
