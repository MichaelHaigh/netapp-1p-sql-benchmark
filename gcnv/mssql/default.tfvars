# GCP Settings
sa_creds           = "~/.gcp/astracontroltoolkitdev-terraform-sa-f8e9.json"
gcp_sa             = "terraform-sa@astracontroltoolkitdev.iam.gserviceaccount.com"
gcp_project        = "astracontroltoolkitdev"
gcp_project_number = "239048101169"
gcp_region         = "us-east4"
gcp_zones          = ["us-east4-a", "us-east4-b"]
ssh_private_key    = "~/.ssh/id_ed25519"
ssh_public_key     = "~/.ssh/id_ed25519.pub"
ssh_username       = "mhaigh"

# VPC Settings
compute_cidr = "10.100.0.0/22"
ad_cidr      = "10.101.0.0/24"

# Compute Settings
ad_machine_type  = "e2-standard-8"
sql_machine_type = "c3-standard-8"
ad_image_type    = "windows-server-2022-dc-v20250813"
sql_image_type   = "windows-server-2022-dc-v20250813"
sql_download_url = "https://go.microsoft.com/fwlink/p/?linkid=2215158"
sql_cpp_url      = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
sql_odbc_url     = "https://go.microsoft.com/fwlink/?linkid=2266337"
sql_cmd_url      = "https://go.microsoft.com/fwlink/?linkid=2230791"

# GCNV Settings
gcnv_service_level = "standard"
gcnv_pool_capacity = "4096"

# Authorized Networks
authorized_networks = [
  {
    cidr_block   = "198.51.100.0/24"
    display_name = "company_range"
  },
  {
    cidr_block   = "203.0.113.30/32"
    display_name = "home_address"
  },
]
