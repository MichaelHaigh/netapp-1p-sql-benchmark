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

resource "terraform_data" "setup_ad" {
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
  provisioner "remote-exec" {
    inline = [
      "echo Install-ADDSForest -DomainName ${terraform.workspace}.local -InstallDNS -SafeModeAdministratorPassword (ConvertTo-SecureString ${random_string.sql_ad_safemode_password.result} -AsPlainText -Force) -Force > setup-ad.ps1",
      "powershell.exe -File setup-ad.ps1",
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

resource "google_compute_instance" "sql_server" {
  name         = "sql-${terraform.workspace}-server"
  machine_type = var.sql_machine_type
  zone         = var.gcp_zones[0]

  boot_disk {
    initialize_params {
      image = var.sql_image_type
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
    # Set 'cmd' as default shell due to terraform bug (github.com/hashicorp/terraform/issues/31423)
    New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\cmd.exe" -PropertyType String -Force | Out-Null
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses ${time_sleep.wait_for_ad_reboot.triggers["dns_ip"]}, "8.8.8.8"
    EOF
  }
}

resource "terraform_data" "setup_sql" {
  triggers_replace = [
    google_compute_instance.sql_server.instance_id
  ]
  connection {
    target_platform = "windows"
    type            = "ssh"
    agent           = "false"
    host            = google_compute_instance.sql_server.network_interface[0].access_config[0].nat_ip
    user            = var.ssh_username
    private_key     = file(var.ssh_private_key)
    timeout         = "20m"
  }
  provisioner "remote-exec" {
    # Enable password SSH access, create domain credential, join domain, and restart machine
    inline = [
      "echo Subsystem        sftp        sftp-server.exe> C:\\ProgramData\\ssh\\sshd_config",
      "echo Match Group administrators>> C:\\ProgramData\\ssh\\sshd_config",
      "echo        AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys>> C:\\ProgramData\\ssh\\sshd_config",
      "echo PubkeyAuthentication yes>> C:\\ProgramData\\ssh\\sshd_config",
      "echo AllowUsers ${terraform.workspace}\\administrator>> C:\\ProgramData\\ssh\\sshd_config",
      "echo $username = \"Administrator@${terraform.workspace}.local\" > setup-sql.ps1",
      "echo $password = ConvertTo-SecureString ${random_string.sql_ad_admin_password.result} -AsPlainText -Force >> setup-sql.ps1",
      "echo $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password >> setup-sql.ps1",
      "echo Add-Computer -DomainName \"${terraform.workspace}.local\" -Credential $cred -Force >> setup-sql.ps1",
      "powershell.exe -File setup-sql.ps1",
      "del setup-sql.ps1",
      "shutdown /r /t 10"
    ]
  }
}
