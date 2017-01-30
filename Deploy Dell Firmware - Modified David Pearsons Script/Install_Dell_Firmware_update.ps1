<# 
 .NOTES
 ==========================================================================
  Created on:    3/25/2016 12:44 PM
  Created by:    David Pearson http://www.dptechjournal.net
 HAPPYSCCM.COM: Added Param so script can be used with any firmware file
 ===========================================================================
 .DESCRIPTION
  Installs BIOS Update's for Dell Computers.
  1. Determines the OS of the computer
  2. Suspends Bitlocker if needed
  3. Updates BIOS
  4. Writes Log to Application Log

Usage: powershell.exe -ExecutionPolicy Unrestricted -File Install_Dell_Firmware_update.ps1 -FirmwareFile O9020A17.exe
 Function Get-Laptop from https://blogs.technet.microsoft.com/heyscriptingguy/2010/05/15/hey-scripting-guy-weekend-scripter-how-can-i-use-wmi-to-detect-laptops/
#>

Param(
  [string]$FirmwareFile
)


Function Get-Laptop
{
 Param (
  [string]$computer = “localhost”
 )
 $isLaptop = $false
 if (Get-WmiObject -Class win32_systemenclosure -ComputerName $computer |
 Where-Object {
  $_.chassistypes -eq 9 -or $_.chassistypes -eq 10 `
  -or $_.chassistypes -eq 14
 })
 { $isLaptop = $true }
 if (Get-WmiObject -Class win32_battery -ComputerName $computer)
 { $isLaptop = $true }
 $isLaptop
} # end function Get-Laptop
$currentDirectory = split-path -parent $MyInvocation.MyCommand.Definition
 
# Setup Logging
$ErrorActionPreference = "SilentlyContinue"
if (!(Get-Eventlog -LogName "Application" -Source "ConfigMgr Team"))
{
 New-Eventlog -LogName "Application" -Source "ConfigMgr Team" | Out-Null
}
$ErrorActionPreference = "Continue"
 
 
Write-EventLog -LogName "Application" -Source "ConfigMgr Team" -EntryType "Information" -EventId 1 -Message "ConfigMgr detected No User Logged In, Starting BIOS Upgrade Script."
 
# Check if Laptop, exit if Battery life is less than 30
If (get-Laptop)
{
 Write-EventLog -LogName "Application" -Source "ConfigMgr Team" -EntryType "Information" -EventId 3 -Message "Laptop detected, checking battery life."
 if ((Get-WmiObject win32_battery).estimatedChargeRemaining -le 30)
 {
  Write-EventLog -LogName "Application" -Source "ConfigMgr Team" -EntryType "Information" -EventId 4 -Message "Battery below 30%, canceling BIOS Upgrade...this time."
  exit
 }
}
 
# Get Operating System version and performs the appropriate actions to bitlocker
[int]$computerOS = (Get-WmiObject -namespace Root\cimv2 -Query "SELECT BuildNumber FROM win32_operatingSystem").buildnumber
 
 
if ($computerOS -ge 8000)
{
 $drive = Get-BitLockerVolume | where { $_.ProtectionStatus -eq "On" -and $_.VolumeType -eq "OperatingSystem" }
    if ($drive)
 {
     Write-EventLog -LogName "Application" -Source "ConfigMgr Team" -EntryType "Information" -EventId 2 -Message "Attempting to Suspend Bitlocker on drive $drive."
     Suspend-BitLocker -Mountpoint $drive -RebootCount 1
     if (Get-BitLockerVolume -MountPoint $drive | where ProtectionStatus -eq "On")
     {
      #Bitlocker Suspend Failed, Exit Script
      Write-EventLog -LogName "Application" -Source "ConfigMgr Team" -EntryType "Information" -EventId 13 -Message "Failed to Suspend Bitlocker on drive $drive , Exiting."
      exit
     }
    }
}
else
{
 $drive = manage-bde.exe -status c:
 if ($drive -match 'Protection Status:    Protection On')
 {
  Write-EventLog -LogName "Application" -Source "ConfigMgr Team" -EntryType "Information" -EventId 2 -Message "Attempting to Suspend Bitlocker on drive C: ."
  manage-bde.exe -protectors -disable c:
  $verifydrive = manage-bde.exe -status c:
  if ($verifydrive -match "Protection Status:    Protection On")
  {
   #Bitlocker Suspend Failed, Exit Script
   Write-EventLog -LogName "Application" -Source "ConfigMgr Team" -EntryType "Information" -EventId 13 -Message "Failed to Suspend Bitlocker on drive C: , Exiting."
   exit
  }
  # Create a Scheduled Task to resume Bitlocker on startup, then remove
  cmd /c schtasks /create /f /tn "Bitlock" /XML $currentDirectory\sTask_Details.xml
 }
  
}
 
#Install BIOS Update
Write-EventLog -LogName "Application" -Source "ConfigMgr Team" -EntryType "Information" -EventId 7 -Message "Configmgr starting BIOS Update and rebooting. For more information, examine update.log in $currentDirectory"
 
$args = "/s /r /f /p=Password /l=$currentDirectory\Update.log"
$install = Start-Process $FirmwareFile -ArgumentList $args -WorkingDirectory $currentDirectory -Wait