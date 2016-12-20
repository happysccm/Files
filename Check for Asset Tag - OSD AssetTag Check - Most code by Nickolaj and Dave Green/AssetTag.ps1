Function Load-Form 
{
    $Form.Controls.Add($GBLabel)
    $Form.Controls.Add($ButtonOK)
    $Form.Add_Shown({$Form.Activate()})
    [void] $Form.ShowDialog()
}
  




$model = Get-WmiObject -Class Win32_ComputerSystem | ForEach-Object {$_.Model}
    If ($model -like "*vmware*")  {
    Write-Host "vm"
    exit 0
    }

    ElseIf ($model -like "*Parallels*")  {
    Write-Host "Parallels"
    exit 0
    } 

    ElseIf ($model -like "*Virtual Machine*")  {
    Write-Host "Virtual Machine"
    exit 0
    } 

    ElseIf ($model -like "*Mac*")  {
    Write-Host "Mac"
    exit 0
    } 


$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$machineName =  $tsenv.Value("_SMSTSMachineName")

If (!$machineName) {

$bios = Get-WmiObject -Class Win32_SystemEnclosure | ForEach-Object {$_.SMBIOSAssetTag}


If (!$bios) {

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

$Global:ErrorProvider = New-Object System.Windows.Forms.ErrorProvider

$Form = New-Object System.Windows.Forms.Form    
$Form.Size = New-Object System.Drawing.Size(285,140)  
$Form.MinimumSize = New-Object System.Drawing.Size(285,140)
$Form.MaximumSize = New-Object System.Drawing.Size(285,140)
$Form.StartPosition = "CenterScreen"
$Form.SizeGripStyle = "Hide"
$Form.Text = "Asset Tag not found"
$Form.ControlBox = $false
$Form.TopMost = $true

$GBLabel = New-Object System.Windows.Forms.Label
$GBLabel.Location = New-Object System.Drawing.Size(20,10)
$GBLabel.Size = New-Object System.Drawing.Size(225,50)
$GBLabel.Text = "Please configure the Asset Tag in the bios and try again"

$ButtonOK = New-Object System.Windows.Forms.Button
$ButtonOK.Location = New-Object System.Drawing.Size(195,70)
$ButtonOK.Size = New-Object System.Drawing.Size(50,20)
$ButtonOK.Text = "OK"
$ButtonOK.TabIndex = "2"
$ButtonOK.Add_Click({[System.Environment]::Exit(1)})

$Form.KeyPreview = $True
$Form.Add_KeyDown({if ($_.KeyCode -eq "Enter"){[System.Environment]::Exit(1)}})

Load-Form

}

$TSEnv.Value("OSDComputerName") = $bios


}
