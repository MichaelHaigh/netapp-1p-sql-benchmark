# VPC Config
resource "google_compute_network" "sql_network" {
  name                    = "sql-${terraform.workspace}-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "sql_subnetwork" {
  name          = "sql-${terraform.workspace}-subnetwork"
  ip_cidr_range = var.compute_cidr
  network       = google_compute_network.sql_network.name
}


resource "google_compute_firewall" "sql_firewall" {
  name          = "sql-${terraform.workspace}-firewall"
  network       = google_compute_network.sql_network.name
  source_ranges = var.authorized_networks[*].cidr_block
  source_tags   = ["sql-${terraform.workspace}-cluster"]
  allow {
    protocol = "all"
  }
}
resource "google_compute_firewall" "sql_internal" {
  name          = "sql-${terraform.workspace}-internal"
  network       = google_compute_network.sql_network.name
  source_ranges = ["10.0.0.0/8", "172.16.0.0/12"]
  allow {
    protocol = "all"
  }
}

resource "google_compute_router" "sql_router" {
  name    = "sql-${terraform.workspace}-router"
  region  = var.gcp_region
  network = google_compute_network.sql_network.id
}

resource "google_compute_router_nat" "sql_nat" {
  name                               = "sql-${terraform.workspace}-router-nat"
  router                             = google_compute_router.sql_router.name
  region                             = google_compute_router.sql_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_global_address" "netapp_ip_range" {
  name          = "netapp-addresses-sql-${terraform.workspace}-network"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.sql_network.id
  depends_on = [
    google_compute_firewall.sql_firewall
  ]
}

resource "google_service_networking_connection" "netapp_connection" {
  network                 = google_compute_network.sql_network.id
  service                 = "netapp.servicenetworking.goog"
  reserved_peering_ranges = [google_compute_global_address.netapp_ip_range.name]
  depends_on = [
    google_compute_global_address.netapp_ip_range
  ]
  deletion_policy = "ABANDON"
}
