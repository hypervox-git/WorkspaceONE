<#	
.NOTES
	===========================================================================
	 Created by:	bpeppin@vmware.com | www.brookspeppin.com 
	 Organization:	VMware, Inc.
     Filename:     	Install-update.ps1
     Date:          Aug 10, 2020
	===========================================================================
	.DESCRIPTION
		Installs a windows update that is in .cab format. 
        
#>
param (
    # Parameter help description
    [Parameter(Mandatory = $true)]
	[String]$KB,
	[parameter(Mandatory = $true)]
	[ValidateSet('Yes', 'No')]
	[string]$CustomRestart
)

$Filename = (Get-ChildItem -Filter "*.cab").name
$fullpath = "$PSScriptRoot\$Filename"

If (!(Test-Path $env:ProgramData\)) {
    mkdir c:\temp
}
Start-Transcript "$env:ProgramData\Airwatch\UnifiedAgent\Logs\Install-Update-$KB.log"
function CheckKB {
    param (
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [String]$KB
    )
    Write-Host "Checking if $KB is installed..."
    If ((get-hotfix).HotfixID -contains $KB) {
        #successfully installed
        Return $true
    }
    else {
        #failed to install
        Return $false
    }
    
}

#Pre-Checking installation of KB
if (CheckKB -KB $KB) {
    Write-Host "$KB already installed. Exiting."
    Exit 0
}
else {
    #Write-Host "Starting BitsTransfer download of $KB"
    #Start-BitsTransfer -Source $URL -Destination $fullpath | Out-Host
    Try {
        Write-Host "Installing $KB from $fullpath"
        #start-process wusa -ArgumentList "$fullpath /quiet /norestart /log:c:\temp\wusa.evt" -Wait
        DISM.exe /online /add-package /PackagePath:$Filename /NoRestart | Out-Host
    }
    catch {
        $message = "TRAPPED: {0}: '{1}'" -f ($_.Exception.GetType().FullName), ($_.Exception.Message)
        Write-host $message
        Exit 1
    }
}

if (CheckKB -KB $KB) {
    Write-Host "$KB successfully installed. Cleaning up file to free up space."
	Remove-Item $fullpath -Force
	If ($CustomRestart -eq "Yes")
	{
        Write-Host "Custom restart selected. Querying registry for the specified value."
        $guid = Split-Path (Split-Path $MyInvocation.MyCommand.Path) -Leaf
        $key = "AppDeferrals.Interval"

        $name = (Get-ItemProperty "HKLM:\SOFTWARE\AirWatchMDM\AppDeploymentAgent\AppManifests\$guid").Name
        Write-Host "Name of update: $name"

        [int]$interval = (Get-ItemProperty "HKLM:\SOFTWARE\AirWatchMDM\AppDeploymentAgent\Policy\$guid").$key
        $restart = $interval * 60 * 60
        Write-Host "Restart interval set to $interval hours"
        $reason = "P:2:17" #Operating System: Hot fix (Planned)
        Write-Host "Sending restart command to system. Restarting in $interval hours."
        shutdown.exe /g /t $restart /c "Windows Update Installed: $name. Restarting in $interval hours" /d $reason
	}
	else
	{
		Exit 0
	}
	
}
else
{
	Write-Host "$KB not installed. Exiting with error code 1."
	Exit 1
}

Stop-Transcript
