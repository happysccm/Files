
# HappySCCM.com - Set Driver packages to High Priority   

cd PS1:
$dPackages = Get-CMDriverPackage 
foreach ($driver in $dPackages)
{
write-host Setting $driver.name Priority
$driver.priority = "1"
Set-CmdriverPackage -InputObject $driver -ErrorAction SilentlyContinue
}