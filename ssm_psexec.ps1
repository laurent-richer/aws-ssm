$domain='mydomain'
$user='laurent'

$password = Get-SSMParameter "/org/user/pass/$user" -WithDecryption $true | Select-Object -ExpandProperty Value
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $domain\$user, $securePassword

psexec \\$env:computername -accepteula -u $domain\$user -p $password -h -i notepad
