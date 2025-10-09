# GCP Technical Test - Escenario 3: CI/CD with Cloud Build and Cloud Run
# Simplified version to fix Cloud Armor and Docker image issues

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
  credentials = file("service-account.json")
}

# Variables
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "blocked_ip" {
  description = "IP address to block with Cloud Armor"
  type        = string
  default     = "1.2.3.4"
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "web_app_repo" {
  location      = var.region
  repository_id = "gcp-technical-test"
  description   = "Docker repository for GCP Technical Test web application"
  format        = "DOCKER"
}

# Create service account for Cloud Build
resource "google_service_account" "cloud_build_sa" {
  account_id   = "cloud-build-sa"
  display_name = "Cloud Build Service Account"
  description  = "Service account for Cloud Build CI/CD pipeline"
}

# Grant necessary permissions to Cloud Build service account
resource "google_project_iam_member" "cloud_build_permissions" {
  for_each = toset([
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
    "roles/compute.securityAdmin",
    "roles/logging.logWriter"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Create Cloud Run service with Artifact Registry image
resource "google_cloud_run_v2_service" "web_app" {
  name     = "web-app"
  location = var.region

  template {
    containers {
      # Use Artifact Registry image
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.web_app_repo.repository_id}/web-app:latest"
      #image = "gcr.io/cloudrun/hello"
      ports {
        container_port = 8080
      }
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_artifact_registry_repository.web_app_repo
  ]
}

# Allow unauthenticated access to Cloud Run service
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.web_app.location
  service  = google_cloud_run_v2_service.web_app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Create simplified Cloud Armor security policy
resource "google_compute_security_policy" "web_app_security" {
  name = "web-app-security-policy"
  description = "Security policy for GCP Technical Test web application"

  # Default rule - allow all traffic
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule"
  }

  # Rule to block specific IP
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [var.blocked_ip]
      }
    }
    description = "Block IP address ${var.blocked_ip}"
  }
}

# Create global IP address
resource "google_compute_global_address" "web_app_ip" {
  name = "web-app-ip"
}

# Create HTTP proxy
resource "google_compute_target_http_proxy" "web_app_http_proxy" {
  name    = "web-app-http-proxy"
  url_map = google_compute_url_map.web_app_url_map.id
}

# Create URL map
resource "google_compute_url_map" "web_app_url_map" {
  name            = "web-app-url-map"
  default_service = google_compute_backend_service.web_app_backend.id
}

# Create backend service with Cloud Armor
resource "google_compute_backend_service" "web_app_backend" {
  name        = "web-app-backend"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.web_app_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  # Apply Cloud Armor security policy
  security_policy = google_compute_security_policy.web_app_security.id
}

# Create network endpoint group
resource "google_compute_region_network_endpoint_group" "web_app_neg" {
  name                  = "web-app-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.web_app.name
  }
}

# Create a simple HTTP load balancer with Cloud Armor
resource "google_compute_global_forwarding_rule" "web_app_forwarding_rule" {
  name       = "web-app-forwarding-rule"
  target     = google_compute_target_http_proxy.web_app_http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.web_app_ip.address
}

# Create Cloud Build trigger
resource "google_cloudbuild_trigger" "web_app_trigger" {
  name        = "github-terraform"
  description = "Trigger for web application CI/CD pipeline created with Terraform"
  filename    = "cloudbuild.yaml"
  location    = var.region

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^main$"
    }
  }

  substitutions = {
    _REGION     = var.region
    _REPO_NAME  = google_artifact_registry_repository.web_app_repo.repository_id
    _SERVICE_NAME = google_cloud_run_v2_service.web_app.name
  }

  service_account = google_service_account.cloud_build_sa.id

  depends_on = [
    google_service_account.cloud_build_sa,
    google_artifact_registry_repository.web_app_repo
  ]
}

# Outputs
output "cloud_run_url" {
  value = google_cloud_run_v2_service.web_app.uri
  description = "URL of the Cloud Run service"
}

output "load_balancer_ip" {
  value = google_compute_global_address.web_app_ip.address
  description = "IP address of the load balancer"
}

output "load_balancer_url" {
  value = "http://${google_compute_global_address.web_app_ip.address}"
  description = "HTTP URL of the load balancer with Cloud Armor"
}

output "artifact_registry_url" {
  value = google_artifact_registry_repository.web_app_repo.name
  description = "URL of the Artifact Registry repository"
}

output "cloud_build_trigger_id" {
  value = google_cloudbuild_trigger.web_app_trigger.id
  description = "ID of the Cloud Build trigger"
}

output "security_policy_name" {
  value = google_compute_security_policy.web_app_security.name
  description = "Name of the Cloud Armor security policy"
}

output "blocked_ip" {
  value = var.blocked_ip
  description = "IP address that is blocked by Cloud Armor"
}
