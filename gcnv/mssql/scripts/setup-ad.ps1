param(
  [string]$Domain,
  [string]$Password
)

Install-ADDSForest -DomainName $Domain -InstallDNS -SafeModeAdministratorPassword (ConvertTo-SecureString $Password -AsPlainText -Force) -Force
