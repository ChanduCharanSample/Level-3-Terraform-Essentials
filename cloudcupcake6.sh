#!/bin/bash

# Auto-detect project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

echo "✅ Current Project ID: $PROJECT_ID"
read -p "Press Enter to continue with this project or type another Project ID: " NEW_PROJECT
if [ ! -z "$NEW_PROJECT" ]; then
  PROJECT_ID=$NEW_PROJECT
  gcloud config set project $PROJECT_ID
fi

# Ask region and zone
read -p "Enter region (default: us-central1): " REGION
REGION=${REGION:-us-central1}

read -p "Enter zone (default: us-central1-a): " ZONE
ZONE=${ZONE:-us-central1-a}

# Set region & zone
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

echo "🚀 Deploying VM in project: $PROJECT_ID, region: $REGION, zone: $ZONE"

# Create VM instance
gcloud compute instances create nucleus-jumphost \
  --machine-type=e2-medium \
  --image-family=debian-11 \
  --image-project=debian-cloud

# (Optional) open firewall rules for HTTP
gcloud compute firewall-rules create allow-http \
  --allow tcp:80 \
  --target-tags=http-server \
  --description="Allow HTTP traffic" \
  --direction=INGRESS || echo "⚠️ Firewall rule already exists"

# List VM
gcloud compute instances list

# Connect to VM
echo "🔑 Connecting to nucleus-jumphost..."
gcloud compute ssh nucleus-jumphost --zone=$ZONE
