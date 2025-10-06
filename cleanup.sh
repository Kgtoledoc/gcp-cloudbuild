#!/bin/bash

# GCP Technical Test - Escenario 3: Cleanup Script
# This script removes all resources created for the technical test

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}🧹 GCP Technical Test - Escenario 3: Cleanup${NC}"
echo "============================================="
echo -e "${YELLOW}⚠️ This will destroy ALL resources created for this project${NC}"
echo ""

# Confirmation
read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}❌ Cleanup cancelled${NC}"
    exit 0
fi

echo -e "${YELLOW}🗑️ Starting cleanup process...${NC}"

# Get project ID
PROJECT_ID=$(terraform output -raw project_id 2>/dev/null || echo "trusty-hangar-474303-t7")
echo "Project ID: $PROJECT_ID"

# Set project
gcloud config set project $PROJECT_ID

# Step 1: Delete Cloud Build triggers
echo -e "${YELLOW}🔧 Deleting Cloud Build triggers...${NC}"
if gcloud builds triggers list --filter="name:web-app-trigger" --format="value(name)" | grep -q "web-app-trigger"; then
    gcloud builds triggers delete web-app-trigger --quiet
    echo -e "${GREEN}✅ Cloud Build trigger deleted${NC}"
else
    echo -e "${YELLOW}⚠️ Cloud Build trigger not found${NC}"
fi

# Step 2: Delete Cloud Run services
echo -e "${YELLOW}🚀 Deleting Cloud Run services...${NC}"
if gcloud run services list --filter="metadata.name:web-app" --format="value(metadata.name)" | grep -q "web-app"; then
    gcloud run services delete web-app --region=us-central1 --quiet
    echo -e "${GREEN}✅ Cloud Run service deleted${NC}"
else
    echo -e "${YELLOW}⚠️ Cloud Run service not found${NC}"
fi

# Step 3: Delete Artifact Registry repositories
echo -e "${YELLOW}📦 Deleting Artifact Registry repositories...${NC}"
if gcloud artifacts repositories list --location=us-central1 --filter="name:gcp-technical-test" --format="value(name)" | grep -q "gcp-technical-test"; then
    gcloud artifacts repositories delete gcp-technical-test --location=us-central1 --quiet
    echo -e "${GREEN}✅ Artifact Registry repository deleted${NC}"
else
    echo -e "${YELLOW}⚠️ Artifact Registry repository not found${NC}"
fi

# Step 4: Delete Cloud Armor security policies
echo -e "${YELLOW}🛡️ Deleting Cloud Armor security policies...${NC}"
if gcloud compute security-policies list --filter="name:web-app-security-policy" --format="value(name)" | grep -q "web-app-security-policy"; then
    gcloud compute security-policies delete web-app-security-policy --quiet
    echo -e "${GREEN}✅ Cloud Armor security policy deleted${NC}"
else
    echo -e "${YELLOW}⚠️ Cloud Armor security policy not found${NC}"
fi

# Step 5: Delete Load Balancer resources
echo -e "${YELLOW}⚖️ Deleting Load Balancer resources...${NC}"

# Delete forwarding rules
if gcloud compute forwarding-rules list --global --filter="name:web-app-forwarding-rule" --format="value(name)" | grep -q "web-app-forwarding-rule"; then
    gcloud compute forwarding-rules delete web-app-forwarding-rule --global --quiet
    echo -e "${GREEN}✅ Forwarding rule deleted${NC}"
fi

# Delete target HTTPS proxy
if gcloud compute target-https-proxies list --filter="name:web-app-https-proxy" --format="value(name)" | grep -q "web-app-https-proxy"; then
    gcloud compute target-https-proxies delete web-app-https-proxy --quiet
    echo -e "${GREEN}✅ Target HTTPS proxy deleted${NC}"
fi

# Delete URL map
if gcloud compute url-maps list --filter="name:web-app-url-map" --format="value(name)" | grep -q "web-app-url-map"; then
    gcloud compute url-maps delete web-app-url-map --quiet
    echo -e "${GREEN}✅ URL map deleted${NC}"
fi

# Delete backend service
if gcloud compute backend-services list --global --filter="name:web-app-backend" --format="value(name)" | grep -q "web-app-backend"; then
    gcloud compute backend-services delete web-app-backend --global --quiet
    echo -e "${GREEN}✅ Backend service deleted${NC}"
fi

# Delete network endpoint group
if gcloud compute network-endpoint-groups list --filter="name:web-app-neg" --format="value(name)" | grep -q "web-app-neg"; then
    gcloud compute network-endpoint-groups delete web-app-neg --region=us-central1 --quiet
    echo -e "${GREEN}✅ Network endpoint group deleted${NC}"
fi

# Delete global IP address
if gcloud compute addresses list --global --filter="name:web-app-ip" --format="value(name)" | grep -q "web-app-ip"; then
    gcloud compute addresses delete web-app-ip --global --quiet
    echo -e "${GREEN}✅ Global IP address deleted${NC}"
fi

# Step 6: Delete Certificate Manager resources
echo -e "${YELLOW}🔐 Deleting Certificate Manager resources...${NC}"

# Delete certificate map entry
if gcloud certificate-manager maps entries list --map=web-app-cert-map --format="value(name)" | grep -q "web-app-cert-entry"; then
    gcloud certificate-manager maps entries delete web-app-cert-entry --map=web-app-cert-map --quiet
    echo -e "${GREEN}✅ Certificate map entry deleted${NC}"
fi

# Delete certificate map
if gcloud certificate-manager maps list --filter="name:web-app-cert-map" --format="value(name)" | grep -q "web-app-cert-map"; then
    gcloud certificate-manager maps delete web-app-cert-map --quiet
    echo -e "${GREEN}✅ Certificate map deleted${NC}"
fi

# Delete certificate
if gcloud certificate-manager certificates list --filter="name:web-app-cert" --format="value(name)" | grep -q "web-app-cert"; then
    gcloud certificate-manager certificates delete web-app-cert --quiet
    echo -e "${GREEN}✅ Certificate deleted${NC}"
fi

# Step 7: Delete IAM custom role
echo -e "${YELLOW}👤 Deleting IAM custom role...${NC}"
if gcloud iam roles describe cloudRunAdmin --project=$PROJECT_ID > /dev/null 2>&1; then
    gcloud iam roles delete cloudRunAdmin --project=$PROJECT_ID --quiet
    echo -e "${GREEN}✅ Custom IAM role deleted${NC}"
else
    echo -e "${YELLOW}⚠️ Custom IAM role not found${NC}"
fi

# Step 8: Delete service account
echo -e "${YELLOW}🔑 Deleting service account...${NC}"
if gcloud iam service-accounts list --filter="email:cloud-build-sa@$PROJECT_ID.iam.gserviceaccount.com" --format="value(email)" | grep -q "cloud-build-sa"; then
    gcloud iam service-accounts delete cloud-build-sa@$PROJECT_ID.iam.gserviceaccount.com --quiet
    echo -e "${GREEN}✅ Service account deleted${NC}"
else
    echo -e "${YELLOW}⚠️ Service account not found${NC}"
fi

# Step 9: Run Terraform destroy
echo -e "${YELLOW}🏗️ Running Terraform destroy...${NC}"
if [ -f "main.tf" ]; then
    terraform destroy -auto-approve
    echo -e "${GREEN}✅ Terraform resources destroyed${NC}"
else
    echo -e "${YELLOW}⚠️ Terraform files not found${NC}"
fi

# Step 10: Clean up local files
echo -e "${YELLOW}🧹 Cleaning up local files...${NC}"
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform.tfstate*
echo -e "${GREEN}✅ Local files cleaned up${NC}"

echo ""
echo -e "${GREEN}🎉 Cleanup completed successfully!${NC}"
echo -e "${BLUE}📊 Summary:${NC}"
echo "- Cloud Build triggers: Deleted"
echo "- Cloud Run services: Deleted"
echo "- Artifact Registry: Deleted"
echo "- Cloud Armor policies: Deleted"
echo "- Load Balancer resources: Deleted"
echo "- Certificate Manager: Deleted"
echo "- IAM resources: Deleted"
echo "- Terraform state: Cleaned"
echo ""
echo -e "${YELLOW}⚠️ Note: Some resources may take a few minutes to be fully deleted${NC}"
echo -e "${GREEN}✅ All resources have been removed from your GCP project${NC}"
