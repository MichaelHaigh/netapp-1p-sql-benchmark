# GCP Settings
variable "sa_creds" {
  type        = string
  description = "The Service Account json file path on local machine"
}
variable "gcp_sa" {
  type        = string
  description = "The name of the GCP Service Account"
}
variable "gcp_project" {
  type        = string
  description = "The GCP Project name"
}
variable "gcp_project_number" {
  type        = string
  description = "The GCP Project number"
}
variable "gcp_region" {
  type        = string
  description = "The GCP Region"
}
variable "gcp_zones" {
  type        = list(string)
  description = "A list of the GCP Zone(s)"
}
variable "ssh_private_key" {
  type        = string
  description = "The private SSH key file path on local machine access to the compute instances"
}
variable "ssh_public_key" {
  type        = string
  description = "The public SSH key file path on local machine access to the compute instances"
}
variable "ssh_username" {
  type        = string
  description = "The username for SSH access to the compute instances"
}

# VPC Settings
variable "compute_cidr" {
  type        = string
  description = "The subnetwork CIDR for the compute infrastructure"
}
variable "ad_cidr" {
  type        = string
  description = "The network CIDR reserved for Managed AD"
}

# Compute Settings
variable "ad_machine_type" {
  type        = string
  description = "The machine type for the Active Directory instance"
}
variable "sql_machine_type" {
  type        = string
  description = "The machine type for the MS SQL instance"
}
variable "ad_image_type" {
  type        = string
  description = "The image type of the Active Directory instance"
}
variable "sql_image_type" {
  type        = string
  description = "The image type of the MS SQL instance"
}
variable "sql_download_url" {
  type        = string
  description = "The URL to download the MS SQL exe file"
}

# GCNV Settings
variable "gcnv_service_level" {
  type        = string
  description = "The GCNV Service Level (should be one of flex, standard, premium, extreme)"

  validation {
    condition     = contains(["flex", "standard", "premium", "extreme"], var.gcnv_service_level)
    error_message = "Valid values for gcnv_service_level: (flex, standard, premium, extreme)"
  }
}
variable "gcnv_pool_capacity" {
  type        = string
  description = "The GCNV storage pool capacity in GiB"
}

# Authorized Networks
variable "authorized_networks" {
  type        = list(object({ cidr_block = string, display_name = string }))
  description = "List of master authorized networks. If none are provided, disallow external access."
  default     = []
}
