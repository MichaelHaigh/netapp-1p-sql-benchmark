param(
  [string]$Url
)

(new-object System.Net.WebClient).DownloadFile("$Url","SQL2022-SSEI-Dev.exe")
New-Item -ItemType Directory -Path C:\SQLMedia -Force
