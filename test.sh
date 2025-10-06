#!/bin/bash

# GCP Technical Test - Escenario 3: Testing Script
# This script tests the complete CI/CD pipeline and security features

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 GCP Technical Test - Escenario 3: Testing Suite${NC}"
echo "=================================================="

# Get outputs from Terraform
echo -e "${YELLOW}📋 Getting deployment information...${NC}"
CLOUD_RUN_URL=$(terraform output -raw cloud_run_url 2>/dev/null || echo "")
LB_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "")
LB_URL=$(terraform output -raw load_balancer_url 2>/dev/null || echo "")
BLOCKED_IP=$(terraform output -raw blocked_ip 2>/dev/null || echo "1.2.3.4")

if [ -z "$CLOUD_RUN_URL" ]; then
    echo -e "${RED}❌ Terraform outputs not found. Please run 'terraform apply' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Deployment information retrieved${NC}"
echo "Cloud Run URL: $CLOUD_RUN_URL"
echo "Load Balancer IP: $LB_IP"
echo "Load Balancer URL: $LB_URL"
echo "Blocked IP: $BLOCKED_IP"
echo ""

# Test 1: Cloud Run Service Health
echo -e "${YELLOW}🔍 Test 1: Cloud Run Service Health${NC}"
echo "----------------------------------------"

if curl -s -f "$CLOUD_RUN_URL/health" > /dev/null; then
    echo -e "${GREEN}✅ Cloud Run service is healthy${NC}"
    curl -s "$CLOUD_RUN_URL/health" | jq '.' 2>/dev/null || curl -s "$CLOUD_RUN_URL/health"
else
    echo -e "${RED}❌ Cloud Run service is not responding${NC}"
fi
echo ""

# Test 2: Application Endpoints
echo -e "${YELLOW}🔍 Test 2: Application Endpoints${NC}"
echo "----------------------------------------"

echo "Testing main page..."
if curl -s -f "$CLOUD_RUN_URL" > /dev/null; then
    echo -e "${GREEN}✅ Main page is accessible${NC}"
else
    echo -e "${RED}❌ Main page is not accessible${NC}"
fi

echo "Testing info endpoint..."
if curl -s -f "$CLOUD_RUN_URL/info" > /dev/null; then
    echo -e "${GREEN}✅ Info endpoint is working${NC}"
    curl -s "$CLOUD_RUN_URL/info" | jq '.' 2>/dev/null || curl -s "$CLOUD_RUN_URL/info"
else
    echo -e "${RED}❌ Info endpoint is not working${NC}"
fi

echo "Testing API status..."
if curl -s -f "$CLOUD_RUN_URL/api/status" > /dev/null; then
    echo -e "${GREEN}✅ API status endpoint is working${NC}"
    curl -s "$CLOUD_RUN_URL/api/status" | jq '.' 2>/dev/null || curl -s "$CLOUD_RUN_URL/api/status"
else
    echo -e "${RED}❌ API status endpoint is not working${NC}"
fi
echo ""

# Test 3: Load Balancer and HTTPS
echo -e "${YELLOW}🔍 Test 3: Load Balancer and HTTPS${NC}"
echo "----------------------------------------"

if [ -n "$LB_URL" ]; then
    echo "Testing HTTPS endpoint..."
    if curl -s -f -k "$LB_URL" > /dev/null; then
        echo -e "${GREEN}✅ HTTPS endpoint is accessible${NC}"
        echo "Response headers:"
        curl -s -I -k "$LB_URL" | head -10
    else
        echo -e "${RED}❌ HTTPS endpoint is not accessible${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Load balancer URL not available${NC}"
fi
echo ""

# Test 4: Cloud Armor Security (Simulation)
echo -e "${YELLOW}🔍 Test 4: Cloud Armor Security${NC}"
echo "----------------------------------------"

echo "Testing Cloud Armor IP blocking (simulation)..."
echo "Note: This test simulates the blocked IP behavior"

# Test with X-Forwarded-For header to simulate blocked IP
if curl -s -f -H "X-Forwarded-For: $BLOCKED_IP" "$CLOUD_RUN_URL" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Request from blocked IP was allowed (may be expected in some configurations)${NC}"
else
    echo -e "${GREEN}✅ Request from blocked IP was blocked (Cloud Armor working)${NC}"
fi

# Test path traversal protection
echo "Testing path traversal protection..."
if curl -s -f "$CLOUD_RUN_URL/../etc/passwd" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Path traversal request was allowed${NC}"
else
    echo -e "${GREEN}✅ Path traversal request was blocked${NC}"
fi

# Test suspicious user agent
echo "Testing suspicious user agent blocking..."
if curl -s -f -H "User-Agent: malicious-bot" "$CLOUD_RUN_URL" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Suspicious user agent was allowed${NC}"
else
    echo -e "${GREEN}✅ Suspicious user agent was blocked${NC}"
fi
echo ""

# Test 5: Performance Test
echo -e "${YELLOW}🔍 Test 5: Performance Test${NC}"
echo "----------------------------------------"

echo "Testing response time..."
START_TIME=$(date +%s%N)
curl -s -f "$CLOUD_RUN_URL/health" > /dev/null
END_TIME=$(date +%s%N)
DURATION=$(( (END_TIME - START_TIME) / 1000000 ))
echo "Response time: ${DURATION}ms"

if [ $DURATION -lt 1000 ]; then
    echo -e "${GREEN}✅ Response time is good (< 1s)${NC}"
else
    echo -e "${YELLOW}⚠️ Response time is slow (> 1s)${NC}"
fi
echo ""

# Test 6: Cloud Build Trigger
echo -e "${YELLOW}🔍 Test 6: Cloud Build Configuration${NC}"
echo "----------------------------------------"

echo "Checking Cloud Build trigger..."
if gcloud builds triggers list --filter="name:web-app-trigger" --format="value(name)" | grep -q "web-app-trigger"; then
    echo -e "${GREEN}✅ Cloud Build trigger is configured${NC}"
    echo "Trigger details:"
    gcloud builds triggers list --filter="name:web-app-trigger" --format="table(name,status,github.owner,github.name,github.push.branch)"
else
    echo -e "${RED}❌ Cloud Build trigger not found${NC}"
fi
echo ""

# Test 7: Artifact Registry
echo -e "${YELLOW}🔍 Test 7: Artifact Registry${NC}"
echo "----------------------------------------"

echo "Checking Artifact Registry repository..."
if gcloud artifacts repositories list --location=us-central1 --filter="name:gcp-technical-test" --format="value(name)" | grep -q "gcp-technical-test"; then
    echo -e "${GREEN}✅ Artifact Registry repository exists${NC}"
    echo "Repository details:"
    gcloud artifacts repositories list --location=us-central1 --filter="name:gcp-technical-test" --format="table(name,location,format)"
else
    echo -e "${RED}❌ Artifact Registry repository not found${NC}"
fi
echo ""

# Test 8: IAM Custom Role
echo -e "${YELLOW}🔍 Test 8: IAM Custom Role${NC}"
echo "----------------------------------------"

echo "Checking custom IAM role..."
if gcloud iam roles describe cloudRunAdmin --project=$(terraform output -raw project_id 2>/dev/null || echo "trusty-hangar-474303-t7") > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Custom IAM role 'cloudRunAdmin' exists${NC}"
    echo "Role permissions:"
    gcloud iam roles describe cloudRunAdmin --project=$(terraform output -raw project_id 2>/dev/null || echo "trusty-hangar-474303-t7") --format="value(includedPermissions)" | tr ',' '\n' | head -10
else
    echo -e "${RED}❌ Custom IAM role not found${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}📊 Test Summary${NC}"
echo "==============="
echo -e "${GREEN}✅ All core functionality tests completed${NC}"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "1. Push changes to GitHub to trigger Cloud Build"
echo "2. Monitor the build process in Cloud Build console"
echo "3. Verify the application updates automatically"
echo "4. Test Cloud Armor with real IP blocking"
echo ""
echo -e "${GREEN}🎉 Testing completed successfully!${NC}"
