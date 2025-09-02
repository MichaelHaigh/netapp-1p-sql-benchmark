terraform {
  required_version = ">= 0.12"
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 6.49.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.7.0"
    }
  }
}

# Google provider
provider "google" {
  credentials = file(var.sa_creds)
  project     = var.gcp_project
  region      = var.gcp_region
}
