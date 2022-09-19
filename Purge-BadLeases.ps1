<#
.SYNOPSIS
  Name: Purge-BadLeases.ps1
  The purpose of this script is to remove all bad DHCP leases from a Microsoft DHCP server
  
.DESCRIPTION
  In order to prevent bad leases from filling up the DHCP pool, this script will find all the bad leases on the local server and then remove them.

.NOTES
    Release Date: 2022-09-19T12:03
    Last Updated: 2022-09-19T12:03
   
    Author: Luke Nichols
#>

### Begin variable definitions ###

$LogFilePath = "$PSScriptRoot\logs\BadLeases_$($currentYear)-$($currentMonth)-$($currentDay)T$($currentHour)$($currentMinute)$($currentSecond)$($loggingTimeZone).txt"
$LogRotateDays = "365"

#Get the current date and write it to a variable
#[DateTime]$currentDate=Get-Date #Local timezone
[DateTime]$currentDate = (Get-Date).ToUniversalTime() #UTC

#Grab the individual portions of the date and put them in vars
$currentYear = $($currentDate.Year)
$currentMonth = $($currentDate.Month).ToString("00")
$currentDay = $($currentDate.Day).ToString("00")

$currentHour = $($currentDate.Hour).ToString("00")
$currentMinute = $($currentDate.Minute).ToString("00")
$currentSecond = $($currentDate.Second).ToString("00")

### End variable definitions ###

### Begin function definitions ###

#Define the function that we use for writing to the log file
function Write-Log {
    Param ([string]$LogString, [string]$LogFilePath, [int32]$LogRotateDays)

    #Check to see if the log file path exists. If not, create it.
    if (Test-Path (Split-Path $LogFilePath -Parent)) {
        #Do nothing, folder already exists
    } else {
        $LogFileFolderFullPath = (Split-Path $LogFilePath -Parent)
        $AboveLogFileFolder = (Split-Path $LogFileFolderFullPath -Parent)
        $LogFileFolderOnly = (Split-Path $LogFileFolderFullPath -Leaf)

        New-Item -Path $AboveLogFileFolder -Name $LogFileFolderOnly -ItemType "directory"
    }

    if ($LoggingMode -ne $false) {
        #Generate fresh date info for logging dates/times into log
        $mostCurrentYear = (Get-Date).Year
        $mostCurrentMonth = ((Get-Date).Month).ToString("00")
        $mostCurrentDay = ((Get-Date).Day).ToString("00")
        $mostCurrentHour = ((Get-Date).Hour).ToString("00")
        $mostCurrentMinute = ((Get-Date).Minute).ToString("00")
        $mostCurrentSecond = ((Get-Date).Second).ToString("00")
  
        #Log the content
        $LogContent = "$mostCurrentYear-$mostCurrentMonth-$($mostCurrentDay)T$($mostCurrentHour):$($mostCurrentMinute):$($mostCurrentSecond),$logString"
        Add-Content $LogFilePath -value $LogContent
    }

    if ((!($LogRotateDays)) -or ($LogRotateDays -eq 0)) {
        #Do nothing, log rotation is disabled
    } else {
        #Fetch the current date minus $NumberOfDays
        [DateTime]$limit = (Get-Date).AddDays(-$LogRotateDays)

        #Delete files older than $limit.
        Get-ChildItem -Path $LogFileFolderFullPath | Where-Object { (($_.CreationTime -le $limit) -and (($_.Name -like "*.log*") -or ($_.Name -like "*.txt*"))) } | Remove-Item -Force
    }
}

### End function definitions ###

### Begin main script body ###

Clear-Host

#Change the working directory to $PSScriptRoot
Set-Location $PSScriptRoot

#Get all the bad leases and put them into a variable
$BadLeases =  Get-DhcpServerv4Lease -BadLeases

#Create log file
$LogString = "Purging bad DHCP leases..."
Write-Log -LogString $LogString -LogFilePath $LogFilePath

#Create log file header line
$LogString = "IPAddress,ScopeID,ClientId,HostName,AddressState,LeaseExpiryTime"
Write-Log -LogString $LogString -LogFilePath $LogFilePath

#Loop through all the bad leases on the server
foreach ($Lease in $BadLeases) {
    #Log each lease as we delete it
    $LogString = "$($Lease.IPAddress),$($Lease.ScopeId),$($Lease.ClientId),$($Lease.HostName),$($Lease.AddressState),$($Lease.LeaseExpiryTime)"
    Write-Log -LogString $LogString -LogFilePath $LogFilePath

    #Remove this lease
    $Lease | Remove-DhcpServerv4Lease
}

#Close log file and rotate old logs
$LogString = "End of script."
Write-Log -LogString $LogString -LogFilePath $LogFilePath -LogRotateDays $LogRotateDays

break
exit

### End main script body ###