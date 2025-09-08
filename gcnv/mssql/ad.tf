resource "google_compute_instance" "sql_ad" {
  name         = "sql-${terraform.workspace}-ad"
  machine_type = var.ad_machine_type
  zone         = var.gcp_zones[0]

  boot_disk {
    initialize_params {
      image = var.ad_image_type
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.sql_subnetwork.name
    access_config {}
  }

  metadata = {
    enable-windows-ssh = "TRUE"
    ssh-keys = "${var.ssh_username}:${file(var.ssh_public_key)}"
    sysprep-specialize-script-ps1 = <<-EOF
    # Enable gcloud ssh
    googet -noconfirm=true install google-compute-engine-ssh
    # Set the Administrator password (which becomes the domain Administrator password)
    net user Administrator "${random_string.sql_ad_admin_password.result}"
    # Set 'cmd' as default shell due to terraform bug (github.com/hashicorp/terraform/issues/31423)
    New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\cmd.exe" -PropertyType String -Force | Out-Null
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
    Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
    EOF
  }
}

resource "terraform_data" "ad_misc_settings" {
  triggers_replace = [
    google_compute_instance.sql_ad.instance_id
  ]
  connection {
    target_platform = "windows"
    type            = "ssh"
    agent           = "false"
    host            = google_compute_instance.sql_ad.network_interface[0].access_config[0].nat_ip
    user            = var.ssh_username
    private_key     = file(var.ssh_private_key)
    timeout         = "20m"
  }
  provisioner "file" {
    source      = "scripts/misc-settings.ps1"
    destination = "misc-settings.ps1"
  }
  provisioner "remote-exec" {
    inline = [
      "pwsh.exe -File misc-settings.ps1",
      "del misc-settings.ps1"
    ]
  }
}

resource "terraform_data" "setup_ad" {
  triggers_replace = [
    google_compute_instance.sql_ad.instance_id
  ]
  depends_on = [terraform_data.ad_misc_settings]
  connection {
    target_platform = "windows"
    type            = "ssh"
    agent           = "false"
    host            = google_compute_instance.sql_ad.network_interface[0].access_config[0].nat_ip
    user            = var.ssh_username
    private_key     = file(var.ssh_private_key)
    timeout         = "5m"
  }
  provisioner "file" {
    source      = "scripts/setup-ad.ps1"
    destination = "setup-ad.ps1"
  }
  provisioner "remote-exec" {
    inline = [
      "pwsh.exe -File setup-ad.ps1 -Domain ${terraform.workspace}.local -Password \"${random_string.sql_ad_safemode_password.result}\"",
      "del setup-ad.ps1"
    ]
  }
}

resource "time_sleep" "wait_for_ad_reboot" {
  depends_on = [terraform_data.setup_ad]
  triggers = {
    dns_ip = google_compute_instance.sql_ad.network_interface[0].network_ip
  }

  create_duration = "10m"
}

resource "random_string" "sql_ad_admin_password" {
  length           = 12
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  numeric          = true
  special          = true
  override_special = "!"
}

resource "random_string" "sql_ad_safemode_password" {
  length           = 12
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  numeric          = true
  special          = true
  override_special = "!"
}
