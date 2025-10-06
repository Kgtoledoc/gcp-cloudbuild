#!/bin/bash

# GCP Technical Test - Escenario 3: CI/CD Setup Script
# This script sets up the complete CI/CD pipeline with Cloud Build and Cloud Run

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="trusty-hangar-474303-t7"
REGION="us-central1"
SERVICE_NAME="web-app"
REPO_NAME="gcp-technical-test"

echo -e "${BLUE}🚀 GCP Technical Test - Escenario 3: CI/CD Setup${NC}"
echo "=================================================="

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed. Please install it first.${NC}"
    exit 1
fi

# Set project
echo -e "${YELLOW}📋 Setting up GCP project...${NC}"
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${YELLOW}🔧 Enabling required APIs...${NC}"
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable certificatemanager.googleapis.com

# Authenticate with Application Default Credentials
echo -e "${YELLOW}🔐 Setting up authentication...${NC}"
gcloud auth application-default login

# Initialize Terraform
echo -e "${YELLOW}🏗️ Initializing Terraform...${NC}"
terraform init

# Plan Terraform deployment
echo -e "${YELLOW}📋 Planning Terraform deployment...${NC}"
terraform plan

# Apply Terraform configuration
echo -e "${YELLOW}🚀 Deploying infrastructure...${NC}"
terraform apply -auto-approve

# Get outputs
echo -e "${GREEN}✅ Infrastructure deployed successfully!${NC}"
echo ""
echo -e "${BLUE}📊 Deployment Information:${NC}"
echo "=================================="

# Get Cloud Run URL
CLOUD_RUN_URL=$(terraform output -raw cloud_run_url)
echo -e "🌐 Cloud Run URL: ${GREEN}$CLOUD_RUN_URL${NC}"

# Get Load Balancer IP
LB_IP=$(terraform output -raw load_balancer_ip)
echo -e "🔗 Load Balancer IP: ${GREEN}$LB_IP${NC}"

# Get Load Balancer URL
LB_URL=$(terraform output -raw load_balancer_url)
echo -e "🔒 HTTPS URL (with Cloud Armor): ${GREEN}$LB_URL${NC}"

# Get Artifact Registry URL
ARTIFACT_REGISTRY_URL=$(terraform output -raw artifact_registry_url)
echo -e "📦 Artifact Registry: ${GREEN}$ARTIFACT_REGISTRY_URL${NC}"

# Get Security Policy Name
SECURITY_POLICY=$(terraform output -raw security_policy_name)
echo -e "🛡️ Security Policy: ${GREEN}$SECURITY_POLICY${NC}"

# Get Blocked IP
BLOCKED_IP=$(terraform output -raw blocked_ip)
echo -e "🚫 Blocked IP: ${GREEN}$BLOCKED_IP${NC}"

echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Update terraform.tfvars with your GitHub repository details"
echo "2. Push your code to GitHub repository"
echo "3. The Cloud Build trigger will automatically deploy your application"
echo "4. Test the application at the URLs above"
echo "5. Test Cloud Armor by trying to access from the blocked IP"

echo ""
echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
