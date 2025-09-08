param(
  [string]$Domain,
  [string]$Password
)

$username = "Administrator@$Domain"
$pass_obj = ConvertTo-SecureString $Password -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $pass_obj
Add-Computer -DomainName "$Domain" -Credential $cred -Force
