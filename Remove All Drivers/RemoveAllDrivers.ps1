# HappySCCM.com - Removes all drivers
CD PS1:
Get-CMDriver | Remove-CMDriver -force