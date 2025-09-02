output "ad_ip_address" {
  value = google_compute_instance.sql_ad.network_interface[0].access_config[0].nat_ip
}
output "domain_admin_username" {
  value = "Administrator@${terraform.workspace}.local"
}
output "domain_admin_password" {
  sensitive = true
  value     = random_string.sql_ad_admin_password.result
}
output "sql_ip_address" {
  value = google_compute_instance.sql_server.network_interface[0].access_config[0].nat_ip
}
output "sql_ssh_cmd" {
  value = "terraform output -raw domain_admin_password | pbcopy; ssh -l Administrator@default.local ${google_compute_instance.sql_server.network_interface[0].access_config[0].nat_ip}"
}
