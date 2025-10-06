# GCP Technical Test - Escenario 3: CI/CD with Cloud Build and Cloud Run
# Infrastructure as Code with Terraform

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

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com"
  ])
  
  service = each.value
  disable_on_destroy = false
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "web_app_repo" {
  location      = var.region
  repository_id = "gcp-technical-test"
  description   = "Docker repository for GCP Technical Test web application"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Create custom IAM role for Cloud Run management
resource "google_project_iam_custom_role" "cloud_run_admin" {
  role_id     = "cloudRunAdmin"
  title       = "Cloud Run Admin"
  description = "Custom role for managing Cloud Run services only"
  
  permissions = [
    "run.services.create",
    "run.services.get",
    "run.services.list",
    "run.services.update",
    "run.services.delete",
    "run.services.getIamPolicy",
    "run.services.setIamPolicy",
    "run.operations.get",
    "run.operations.list",
    "run.locations.list",
    "run.revisions.get",
    "run.revisions.list",
    "run.configurations.get",
    "run.configurations.list",
    "run.routes.get",
    "run.routes.list"
  ]

  depends_on = [google_project_service.required_apis]
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
    "roles/compute.securityAdmin"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Create Cloud Run service
resource "google_cloud_run_v2_service" "web_app" {
  name     = "web-app"
  location = var.region

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.web_app_repo.repository_id}/web-app:latest"
      
      ports {
        container_port = 8080
      }
      
      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }
      
      env {
        name  = "ENVIRONMENT"
        value = "production"
      }
      
      env {
        name  = "VERSION"
        value = "1.0.0"
      }
    }
    
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
    
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    session_affinity      = true
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_project_service.required_apis,
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

# Create Cloud Armor security policy
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

  # Rule to block common attack patterns
  rule {
    action   = "deny(403)"
    priority = "1001"
    match {
      expr {
        expression = "request.path.matches('/\\.\\./') || request.path.matches('/\\.\\.%2f') || request.path.matches('/%2e%2e/')"
      }
    }
    description = "Block path traversal attempts"
  }

  # Rule to block suspicious user agents
  rule {
    action   = "deny(403)"
    priority = "1002"
    match {
      expr {
        expression = "request.headers['user-agent'].contains('bot') || request.headers['user-agent'].contains('crawler') || request.headers['user-agent'].contains('scanner')"
      }
    }
    description = "Block suspicious user agents"
  }

  depends_on = [google_project_service.required_apis]
}

# Create Cloud Build trigger
resource "google_cloudbuild_trigger" "web_app_trigger" {
  name        = "web-app-trigger"
  description = "Trigger for web application CI/CD pipeline"
  filename    = "cloudbuild.yaml"

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^main$"
    }
  }

  substitutions = {
    _REGION                = var.region
    _REPO_NAME            = google_artifact_registry_repository.web_app_repo.repository_id
    _SERVICE_NAME         = google_cloud_run_v2_service.web_app.name
    _SECURITY_POLICY_NAME = google_compute_security_policy.web_app_security.name
    _BLOCKED_IP           = var.blocked_ip
  }

  service_account = google_service_account.cloud_build_sa.id

  depends_on = [
    google_project_service.required_apis,
    google_service_account.cloud_build_sa,
    google_artifact_registry_repository.web_app_repo
  ]
}

# Create a load balancer to use Cloud Armor
resource "google_compute_global_forwarding_rule" "web_app_forwarding_rule" {
  name       = "web-app-forwarding-rule"
  target     = google_compute_target_https_proxy.web_app_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.web_app_ip.address

  depends_on = [google_project_service.required_apis]
}

# Create global IP address
resource "google_compute_global_address" "web_app_ip" {
  name = "web-app-ip"
}

# Create HTTPS proxy
resource "google_compute_target_https_proxy" "web_app_https_proxy" {
  name             = "web-app-https-proxy"
  url_map          = google_compute_url_map.web_app_url_map.id
  certificate_map  = google_certificate_manager_certificate_map.web_app_cert_map.id
}

# Create URL map
resource "google_compute_url_map" "web_app_url_map" {
  name            = "web-app-url-map"
  default_service = google_compute_backend_service.web_app_backend.id

  # Apply Cloud Armor security policy
  security_policy = google_compute_security_policy.web_app_security.id
}

# Create backend service
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

# Create managed SSL certificate
resource "google_certificate_manager_certificate" "web_app_cert" {
  name = "web-app-cert"
  managed {
    domains = ["${google_compute_global_address.web_app_ip.address}.nip.io"]
  }
}

# Create certificate map
resource "google_certificate_manager_certificate_map" "web_app_cert_map" {
  name = "web-app-cert-map"
}

# Create certificate map entry
resource "google_certificate_manager_certificate_map_entry" "web_app_cert_entry" {
  name     = "web-app-cert-entry"
  map      = google_certificate_manager_certificate_map.web_app_cert_map.name
  hostname = "${google_compute_global_address.web_app_ip.address}.nip.io"
  certificates = [google_certificate_manager_certificate.web_app_cert.id]
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
  value = "https://${google_compute_global_address.web_app_ip.address}.nip.io"
  description = "HTTPS URL of the load balancer with Cloud Armor"
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
