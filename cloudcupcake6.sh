#!/bin/bash
# ======================================================
# Terraform Essentials: VPC and Subnet - Qwiklabs Script
# ======================================================

# --- Step 1: Get Project, Region, and Zone ---
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [[ -z "$PROJECT_ID" ]]; then
  echo "❌ No active project found. Please set a project first."
  exit 1
fi

echo "✅ Using Project ID: $PROJECT_ID"

read -p "Enter region [us-central1]: " REGION
REGION=${REGION:-us-central1}

read -p "Enter zone [us-central1-b]: " ZONE
ZONE=${ZONE:-us-central1-b}

echo "🌍 Region: $REGION | 📍 Zone: $ZONE"

# --- Step 2: Configure gcloud ---
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# --- Step 3: Create GCS bucket for Terraform state ---
BUCKET_NAME="${PROJECT_ID}-terraform-state"
echo "🔹 Creating GCS bucket: $BUCKET_NAME"
gcloud storage buckets create gs://$BUCKET_NAME --project=$PROJECT_ID --location=us || true

# --- Step 4: Enable required APIs ---
echo "🔹 Enabling Cloud Resource Manager API..."
gcloud services enable cloudresourcemanager.googleapis.com --project=$PROJECT_ID

# --- Step 5: Create Terraform configuration files ---
mkdir -p terraform-vpc
cd terraform-vpc || exit

cat > main.tf <<EOF
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "$BUCKET_NAME"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = "$PROJECT_ID"
  region  = "$REGION"
}

resource "google_compute_network" "vpc_network" {
  name                    = "custom-vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet_us" {
  name            = "subnet-us"
  ip_cidr_range   = "10.10.1.0/24"
  region          = "$REGION"
  network         = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_icmp" {
  name    = "allow-icmp"
  network = google_compute_network.vpc_network.name
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}
EOF

cat > variables.tf <<EOF
variable "project_id" {
  type        = string
  description = "The ID of the Google Cloud project"
  default     = "$PROJECT_ID"
}

variable "region" {
  type        = string
  description = "The region to deploy resources in"
  default     = "$REGION"
}
EOF

cat > outputs.tf <<EOF
output "network_name" {
  value       = google_compute_network.vpc_network.name
  description = "The name of the VPC network"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet_us.name
  description = "The name of the subnetwork"
}
EOF

# --- Step 6: Run Terraform ---
echo "🔹 Initializing Terraform..."
terraform init -reconfigure

echo "🔹 Planning Terraform deployment..."
terraform plan

echo "🔹 Applying Terraform..."
terraform apply --auto-approve

# --- Step 7: Verification ---
echo "✅ Verifying resources..."
gcloud compute networks list --filter="name=custom-vpc-network"
gcloud compute networks subnets list --filter="name=subnet-us"
gcloud compute firewall-rules list --filter="name~'allow-ssh|allow-icmp'"

echo "🎯 Lab resources deployed successfully. Run the grader now!"
