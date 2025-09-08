# Get disk letters
$dataDiskLetter = Get-Volume -FileSystemLabel 'sql-data-disk' | Select-Object -ExpandProperty DriveLetter
$logsDiskLetter = Get-Volume -FileSystemLabel 'sql-logs-disk' | Select-Object -ExpandProperty DriveLetter
$tempdbDiskLetter = Get-Volume -FileSystemLabel 'sql-tempdb-disk' | Select-Object -ExpandProperty DriveLetter

# Create the directories
New-Item -ItemType Directory -Path ${dataDiskLetter}:\SQL\Data -Force
New-Item -ItemType Directory -Path ${logsDiskLetter}:\SQL\Logs -Force
New-Item -ItemType Directory -Path ${logsDiskLetter}:\SQL\Backup -Force
New-Item -ItemType Directory -Path ${tempdbDiskLetter}:\SQL\TempDB -Force

# Mount the ISO
$iso = "C:\SQLMedia\SQLServer2022-x64-ENU-Dev.iso"
$img = Mount-DiskImage -ImagePath $iso -PassThru
$vol = Get-Volume -DiskImage $img
$drive = "$($vol.DriveLetter):"

# Install MS SQL
Start-Process -FilePath "$drive\setup.exe" -ArgumentList @(
  "/QS",
  "/IACCEPTSQLSERVERLICENSETERMS",
  "/ACTION=Install",
  "/FEATURES=SQLENGINE",
  "/INSTANCENAME=MSSQLSERVER",
  "/TCPENABLED=1",
  "/NPENABLED=0",
  "/SQLSYSADMINACCOUNTS=`"$env:USERDOMAIN\$env:USERNAME`"",
  "/INSTALLSQLDATADIR=`"${dataDiskLetter}:\SQL`"",
  "/SQLUSERDBDIR=`"${dataDiskLetter}:\SQL\Data`"",
  "/SQLUSERDBLOGDIR=`"${logsDiskLetter}:\SQL\Logs`"",
  "/SQLBACKUPDIR=`"${logsDiskLetter}:\SQL\Backup`"",
  "/SQLTEMPDBDIR=`"${tempdbDiskLetter}:\SQL\TempDB`"",
  "/SQLTEMPDBLOGDIR=`"${tempdbDiskLetter}:\SQL\TempDB`""
) -Wait

# Unmount the disk
Dismount-DiskImage -ImagePath $iso

# Install Visual C++ 2017 Redistributable
Start-Process -FilePath "VC_redist.x64.exe" -ArgumentList @(
  "/quiet",
  "/norestart"
) -Wait

# Install ODBC Driver
msiexec /i msodbcsql.msi /qn IACCEPTMSODBCSQLLICENSETERMS=YES
sleep 5

# Install SQL CMD exe
msiexec /i MsSqlCmdLnUtils.msi /qn IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES
sleep 5
