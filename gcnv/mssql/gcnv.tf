# GCNV Config
resource "google_netapp_storage_pool" "gcnv_pool" {
  name             = "sql-${terraform.workspace}-${var.gcnv_service_level}-pool"
  location         = var.gcp_region
  zone             = var.gcnv_service_level == "flex" ? var.gcp_zones[0] : null
  replica_zone     = var.gcnv_service_level == "flex" ? var.gcp_zones[1] : null
  service_level    = upper(var.gcnv_service_level)
  capacity_gib     = var.gcnv_pool_capacity
  network          = google_compute_network.sql_network.id
  active_directory = google_netapp_active_directory.sql_active_directory.id

  labels = {
      creator = var.ssh_username
  }

  depends_on = [
    google_service_networking_connection.netapp_connection
  ]
}

resource "google_netapp_active_directory" "sql_active_directory" {
    name            = "${terraform.workspace}-ad"
    location        = var.gcp_region
    domain          = "${terraform.workspace}.local"
    dns             = time_sleep.wait_for_ad_reboot.triggers["dns_ip"]
    net_bios_prefix = "${terraform.workspace}"

    username = "Administrator@${terraform.workspace}.local"
    password = random_string.sql_ad_admin_password.result
}
