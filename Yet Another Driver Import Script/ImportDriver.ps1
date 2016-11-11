
# HappySCCM.com  - Yet Another Driver Import Script


# Thanks to extra code from
# https://itinlegal.wordpress.com/2016/03/02/sccm-bloated-driver-import/
# http://model-technology.com/importing-drivers-creating-driver-packages-using-powershell/



Param(
  [string]$DriverPackageName,
  [string]$DriverSource,
  [string]$DriverPkgSource

)


Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory=$True)]
    [string]
    $Message,

    [Parameter(Mandatory=$False)]
    [string]
    $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}





CD C: # get-childitem will fail otherwise if you re-run
$sitecode = “PS1:”
$SCCMServer = "localhost"
#==============================================================
# Begin
#==============================================================
Write-Host “DriverPackageName = ” $DriverPackageName
Write-Host “DriverSource = ” $DriverSource
Write-Host “DriverPkgSource = ” $DriverPkgSource


# Verify Driver Source exists.
If (Get-Item “$DriverSource” -ErrorAction SilentlyContinue)
{
# Get driver files
#Write-host “Importing the following drivers..” $Drivers
$Drivers = Get-childitem -path $DriverSource -file -Recurse -Filter “*.inf”
write-host "Found [$($Drivers.Count)] INF files"
 
}
else
{
Write-Warning “Driver Source not found. Cannot continue”
Break
}


# Create Driver package source if not exists
If (Get-Item $DriverPkgSource -ErrorAction SilentlyContinue)
{
Write-Host “$DriverPkgSource already exists… ”
}
else {
Write-Host “Creating Driver package source directory $DriverPkgSource”
New-Item -ItemType directory $DriverPkgSource
}
# Import SCCM module
#Import-Module “G:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1”
CD $sitecode

If (Get-CMDriverPackage -Name $DriverPackageName -ErrorAction SilentlyContinue)
{
Write-Host “Driver Package: $DriverPackageName Already exists.”
}
else
{
Write-Host “Creating new Driver Package: ” $DriverPackageName
#New-CMDriverPackage -Name “$DriverPackageName” -Path “$DriverPkgSource” -PackageSourceType StorageDirect
New-CMDriverPackage -Name “$DriverPackageName” -Path “$DriverPkgSource”

$DriverPackage = Get-CMDriverPackage -Name $DriverPackageName

}
If (Get-CMCategory -Name $DriverPackageName -ErrorAction SilentlyContinue)
{

Write-Host “Driver Category: $DriverPackageName Already exists.”
}
else
{
Write-Host “Creating new Driver Category: ” $DriverPackageName
New-CMCategory -CategoryType DriverCategories -Name $DriverPackageName -ErrorAction SilentlyContinue
}

$DriverCategory = Get-CMCategory -Name $DriverPackageName

$DriverPackage = Get-CMDriverPackage -Name $DriverPackageName

Write-Log -Level INFO -Message "Importing $DriverPackageName" -logfile "C:\Logs\DriverImport.log"

                $totalInfCount = $Drivers.count
                $driverCounter = 0
                $driversIds = @()
                $driverSourcePaths = @()

Measure-Command {foreach($item in $Drivers)
{

Write-Host $item.FullName
                        $Activity = "Importing Drivers for [$DriverPackageName]"
                        $CurrentOperation = "Importing: $($item.Name)"
                        $Status = "($($driverCounter + 1) of $totalInfCount)"
                        $PercentComplete = ($driverCounter++ / $totalInfCount * 100)
                        Write-Progress -Id 1 -Activity $Activity -CurrentOperation $CurrentOperation -Status $Status -PercentComplete $PercentComplete
 
                        if($PercentComplete -gt 0) { $PercentComplete = $PercentComplete.ToString().Substring(0,$PercentComplete.ToString().IndexOf(".")) }
                       write-host "$Status :: $Activity :: $CurrentOperation $PercentComplete%"
   try
               {

                       $job={  
                      import-module -Name ConfigurationManager
                      cd $Using:sitecode
                       $DriverCategory = Get-CMCategory -Name $Using:DriverPackageName
                       $DriverPackage = Get-CMDriverPackage -Name $Using:DriverPackageName
                       $importedDriver = Import-CMDriver -UncFileLocation $Using:item.FullName -ImportDuplicateDriverOption AppendCategory -EnableAndAllowInstall $True -AdministrativeCategory $DriverCategory -DriverPackage $DriverPackage -UpdateDistributionPointsforDriverPackage $False | Select-Object * 
                     
                       }
                       Start-Job -ScriptBlock $job | Wait-Job -Timeout 120| receive-job


                                 if($importedDriver)                                     
                                 {                                         
                                 Write-Progress -Id 1 -Activity $Activity -CurrentOperation "Adding to [$packageName] driver package [$($driverFile.Name)]:" -Status "($driverCounter of $totalInfCount)" -PercentComplete ($driverCounter / $totalInfCount * 100)                                         
                               #  Add-CMDriverToDriverPackage -DriverId $importedDriverID -DriverPackageName $packageName                                         
                                 write-host "importedDriver.CI_ID [$($importedDriver.CI_ID)]"                                                  
                                 write-host "driverContent.ContentID [$($driverContent.ContentID)]"                                         
                                 $driversIds += $driverContent.ContentID                                         
                                 write-host "ContentSourcePath [$($importedDriver.ContentSourcePath)]"                                         
                                 $driverSourcePaths += $importedDriver.ContentSourcePath                                     
                                 }                               
                                Clear-Variable importedDriver -ErrorAction SilentlyContinue
                }
                        catch
                            {
                                Write-Host "ERROR: Failed to Import Driver for [$DriverPackageName]: [$($item.FullName)]" -ForegroundColor Red
                                Write-Host "`$_ is: $_" -ForegroundColor Red
                                Write-Host "`$_.exception is: $($_.exception)" -ForegroundColor Red
                                Write-Host "Exception type: $($_.exception.GetType().FullName)" -ForegroundColor Red
                                Write-Host "TargetObject: $($error[0].TargetObject)" -ForegroundColor Red
                                Write-Host "CategoryInfo: $($error[0].CategoryInfo)" -ForegroundColor Red
                                Write-Host "InvocationInfo: $($error[0].InvocationInfo)" -ForegroundColor Red
                                write-host
                            }

}

}



Write-Progress -Id 1 -Activity $Activity -Completed
Update-CMDistributionPoint -DriverPackageName $DriverPackageName
Write-Log -Level INFO -Message "Import complete $DriverPackageName" -logfile "C:\Logs\DriverImport.log"
CD C: