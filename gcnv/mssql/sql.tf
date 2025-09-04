resource "google_compute_disk" "sql_data_disk" {
  name                   = "sql-data-disk"
  type                   = "hyperdisk-balanced"
  zone                   = var.gcp_zones[0]
  size                   = 100
  provisioned_iops       = 3600
  provisioned_throughput = 290
}

resource "google_compute_disk" "sql_logs_disk" {
  name                   = "sql-logs-disk"
  type                   = "hyperdisk-balanced"
  zone                   = var.gcp_zones[0]
  size                   = 100
  provisioned_iops       = 3600
  provisioned_throughput = 290
}

resource "google_compute_disk" "sql_tempdb_disk" {
  name                   = "sql-tempdb-disk"
  type                   = "hyperdisk-balanced"
  zone                   = var.gcp_zones[0]
  size                   = 100
  provisioned_iops       = 3600
  provisioned_throughput = 290
}

resource "google_compute_instance" "sql_server" {
  name         = "sql-${terraform.workspace}-server"
  machine_type = var.sql_machine_type
  zone         = var.gcp_zones[0]

  boot_disk {
    initialize_params {
      image = var.sql_image_type
      type  = "hyperdisk-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.sql_data_disk.self_link
    device_name = "sql-data-disk"
  }

  attached_disk {
    source      = google_compute_disk.sql_logs_disk.self_link
    device_name = "sql-logs-disk"
  }

  attached_disk {
    source      = google_compute_disk.sql_tempdb_disk.self_link
    device_name = "sql-tempdb-disk"
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

resource "terraform_data" "sql_domain_join" {
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
      "echo $username = \"Administrator@${terraform.workspace}.local\" > domain-join.ps1",
      "echo $password = ConvertTo-SecureString ${random_string.sql_ad_admin_password.result} -AsPlainText -Force >> domain-join.ps1",
      "echo $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password >> domain-join.ps1",
      "echo Add-Computer -DomainName \"${terraform.workspace}.local\" -Credential $cred -Force >> domain-join.ps1",
      "pwsh.exe -File domain-join.ps1",
      "del domain-join.ps1",
      "shutdown /r /t 10"
    ]
  }
}

resource "time_sleep" "wait_for_sql_reboot" {
  depends_on = [terraform_data.sql_domain_join]
  triggers = {
    dns_ip =  google_compute_instance.sql_server.network_interface[0].access_config[0].nat_ip
  }

  create_duration = "2m"
}

resource "terraform_data" "sql_setup_disks" {
  triggers_replace = [
    google_compute_instance.sql_server.instance_id
  ]
  connection {
    target_platform = "windows"
    type            = "ssh"
    agent           = "false"
    host            = time_sleep.wait_for_sql_reboot.triggers["dns_ip"]
    user            = "Administrator@${terraform.workspace}.local"
    password        = random_string.sql_ad_admin_password.result
    timeout         = "20m"
  }
  provisioner "remote-exec" {
    inline = [
      "echo $volumeLabel1 = Invoke-RestMethod -Headers @{\"Metadata-Flavor\" = \"Google\"} -Uri \"http://metadata.google.internal/computeMetadata/v1/instance/disks/1/device-name\"> setup-disks.ps1",
      "echo $volumeLabel2 = Invoke-RestMethod -Headers @{\"Metadata-Flavor\" = \"Google\"} -Uri \"http://metadata.google.internal/computeMetadata/v1/instance/disks/2/device-name\">> setup-disks.ps1",
      "echo $volumeLabel3 = Invoke-RestMethod -Headers @{\"Metadata-Flavor\" = \"Google\"} -Uri \"http://metadata.google.internal/computeMetadata/v1/instance/disks/3/device-name\">> setup-disks.ps1",
      "echo $driveLetter1 = \"D\">> setup-disks.ps1",
      "echo $driveLetter2 = \"E\">> setup-disks.ps1",
      "echo $driveLetter3 = \"F\">> setup-disks.ps1",
      "echo Initialize-Disk -Number 1 -PartitionStyle GPT>> setup-disks.ps1",
      "echo Initialize-Disk -Number 2 -PartitionStyle GPT>> setup-disks.ps1",
      "echo Initialize-Disk -Number 3 -PartitionStyle GPT>> setup-disks.ps1",
      "echo New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter $driveLetter1 ^| Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $volumeLabel1 -Confirm:$false>> setup-disks.ps1",
      "echo New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter $driveLetter2 ^| Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $volumeLabel2 -Confirm:$false>> setup-disks.ps1",
      "echo New-Partition -DiskNumber 3 -UseMaximumSize -DriveLetter $driveLetter3 ^| Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $volumeLabel3 -Confirm:$false>> setup-disks.ps1",
      "pwsh.exe -File setup-disks.ps1",
      "del setup-disks.ps1"
    ]
  }
}

resource "terraform_data" "sql_misc_settings" {
  triggers_replace = [
    google_compute_instance.sql_server.instance_id
  ]
  depends_on = [terraform_data.sql_setup_disks]
  connection {
    target_platform = "windows"
    type            = "ssh"
    agent           = "false"
    host            = time_sleep.wait_for_sql_reboot.triggers["dns_ip"]
    user            = "Administrator@${terraform.workspace}.local"
    password        = random_string.sql_ad_admin_password.result
    timeout         = "5m"
  }
  provisioner "remote-exec" {
    # Disable windows updates, adjust for best performance, disable server manager startup
    inline = [
      "echo $pause = (Get-Date).AddDays(35)> misc-settings.ps1",
      "echo $pause = $pause.ToUniversalTime().ToString( \"yyyy-MM-ddTHH:mm:ssZ\" )>> misc-settings.ps1",
      "echo Set-ItemProperty -Path \"HKLM:\\SOFTWARE\\Microsoft\\WindowsUpdate\\UX\\Settings\" -Name \"PauseUpdatesExpiryTime\" -Value $pause>> misc-settings.ps1",
      "echo New-Item -Path \"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects\">> misc-settings.ps1",
      "echo Set-ItemProperty -Path \"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects\" -Name VisualFXSetting -Value 2>> misc-settings.ps1",
      "echo Get-ScheduledTask -TaskName ServerManager ^| Disable-ScheduledTask>> misc-settings.ps1",
      "pwsh.exe -File misc-settings.ps1",
      "del misc-settings.ps1"
    ]
  }
}

resource "terraform_data" "sql_download_bits" {
  triggers_replace = [
    google_compute_instance.sql_server.instance_id
  ]
  depends_on = [terraform_data.sql_misc_settings]
  connection {
    target_platform = "windows"
    type            = "ssh"
    agent           = "false"
    host            = time_sleep.wait_for_sql_reboot.triggers["dns_ip"]
    user            = "Administrator@${terraform.workspace}.local"
    password        = random_string.sql_ad_admin_password.result
    timeout         = "5m"
  }
  provisioner "file" {
    source      = "scripts/download-sql-bits.ps1"
    destination = "download-sql-bits.ps1"
  }
  provisioner "remote-exec" {
    inline = [
      "pwsh.exe -File download-sql-bits.ps1 -Url ${var.sql_download_url}",
      "SQL2022-SSEI-Dev.exe /Q /Action=Download /MediaType=ISO /MediaPath=\"C:\\SQLMedia\\\"",
      "del download-sql-bits.ps1"
    ]
  }
}

resource "terraform_data" "sql_install" {
  triggers_replace = [
    google_compute_instance.sql_server.instance_id
  ]
  depends_on = [terraform_data.sql_download_bits]
  connection {
    target_platform = "windows"
    type            = "ssh"
    agent           = "false"
    host            = time_sleep.wait_for_sql_reboot.triggers["dns_ip"]
    user            = "Administrator@${terraform.workspace}.local"
    password        = random_string.sql_ad_admin_password.result
    timeout         = "5m"
  }
  provisioner "file" {
    source      = "scripts/install-sql.ps1"
    destination = "install-sql.ps1"
  }
  provisioner "remote-exec" {
    inline = [
      "pwsh.exe -File install-sql.ps1",
      "del install-sql.ps1"
    ]
  }
}
