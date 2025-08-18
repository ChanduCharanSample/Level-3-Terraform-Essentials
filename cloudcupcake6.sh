#!/bin/bash
# ======================================================
# Terraform Essentials Lab + Cloudcupcake VM Setup
# Combined Script for Qwiklabs
# ======================================================

# --- Step 1: Detect Project ---
PROJECT_ID=$(gcloud config get-value project 2> /dev/null)

if [[ -z "$PROJECT_ID" ]]; then
  echo "❌ No active project found. Please set a project first:"
  echo "gcloud config set project PROJECT_ID"
  exit 1
fi

echo "✅ Current Project ID: $PROJECT_ID"

# --- Step 2: Ask for region/zone (with defaults) ---
read -p "Enter region [us-central1]: " REGION
REGION=${REGION:-us-central1}

read -p "Enter zone [us-central1-b]: " ZONE
ZONE=${ZONE:-us-central1-b}

# --- Step 3: Configure gcloud defaults ---
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

echo "🌍 Using Project: $PROJECT_ID"
echo "📍 Region: $REGION"
echo "📍 Zone: $ZONE"

# --- Step 4: Create GCS bucket for Terraform state ---
BUCKET_NAME="${PROJECT_ID}-terraform-state"
echo "🔹 Creating GCS bucket: $BUCKET_NAME"
gcloud storage buckets create gs://$BUCKET_NAME --project=$PROJECT_ID --location=us

# --- Step 5: Enable required APIs ---
echo "🔹 Enabling Cloud Resource Manager API..."
gcloud services enable cloudresourcemanager.googleapis.com --project=$PROJECT_ID

# --- Step 6: Generate Terraform configuration ---
mkdir -p terraform-vpc
cd terraform-vpc

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

# --- Step 7: Deploy Terraform ---
echo "🔹 Initializing Terraform..."
terraform init -reconfigure

echo "🔹 Planning Terraform deployment..."
terraform plan

echo "🔹 Applying Terraform..."
terraform apply --auto-approve

# --- Step 8: Verification of resources ---
echo "✅ Checking resources..."
gcloud compute networks list --filter="name=custom-vpc-network"
gcloud compute networks subnets list --filter="name=subnet-us"
gcloud compute firewall-rules list --filter="name~'allow-ssh|allow-icmp'"

# --- Step 9: Create test VM ---
echo "🔹 Creating test VM: cloudcupcake-vm"
gcloud compute instances create cloudcupcake-vm \
  --machine-type=e2-medium \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --boot-disk-size=10GB \
  --boot-disk-type=pd-balanced \
  --subnet=subnet-us

echo "🎉 Setup complete!"
echo "➡ Project: $PROJECT_ID"
echo "➡ Region: $REGION"
echo "➡ Zone: $ZONE"
echo "➡ VM: cloudcupcake-vm"
echo "⚠️ Do NOT destroy resources until grader checks."
