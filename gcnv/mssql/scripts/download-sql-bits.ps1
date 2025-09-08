param(
  [string]$SQLUrl,
  [string]$CppUrl,
  [string]$ODBCUrl,
  [string]$CMDUrl
)

(new-object System.Net.WebClient).DownloadFile("$SQLUrl","SQL2022-SSEI-Dev.exe")
Invoke-WebRequest -Uri "$CppUrl" -OutFile "VC_redist.x64.exe"
Invoke-WebRequest -Uri "$ODBCUrl" -OutFile "msodbcsql.msi"
Invoke-WebRequest -Uri "$CMDUrl" -OutFile "MsSqlCmdLnUtils.msi"

New-Item -ItemType Directory -Path C:\SQLMedia -Force
