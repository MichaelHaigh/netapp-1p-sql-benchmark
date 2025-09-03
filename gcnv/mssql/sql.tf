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
    user            = var.ssh_username
    private_key     = file(var.ssh_private_key)
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
