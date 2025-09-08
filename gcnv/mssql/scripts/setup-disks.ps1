# Get the disk names from Google Metadata and set the drive letters
$volumeLabel1 = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri "http://metadata.google.internal/computeMetadata/v1/instance/disks/1/device-name"
$volumeLabel2 = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri "http://metadata.google.internal/computeMetadata/v1/instance/disks/2/device-name"
$volumeLabel3 = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri "http://metadata.google.internal/computeMetadata/v1/instance/disks/3/device-name"
$driveLetter1 = "D"
$driveLetter2 = "E"
$driveLetter3 = "F"

# Initialize the disks
Initialize-Disk -Number 1 -PartitionStyle GPT
Initialize-Disk -Number 2 -PartitionStyle GPT
Initialize-Disk -Number 3 -PartitionStyle GPT

# Partition and format the disks
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter $driveLetter1 | Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $volumeLabel1 -Confirm:$false
New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter $driveLetter2 | Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $volumeLabel2 -Confirm:$false
New-Partition -DiskNumber 3 -UseMaximumSize -DriveLetter $driveLetter3 | Format-Volume -FileSystem NTFS -AllocationUnitSize 65536 -NewFileSystemLabel $volumeLabel3 -Confirm:$false
