<#
.SYNOPSIS

Gathers details from an ecobee thermostat and sends the data to Azure Monitor (Log Analytics).

.DESCRIPTION

The Send-EcobeeToAzureMonitor.ps1 gathers details from an ecobee thermostat and sends the data to Azure Monitor (Log Analytics).
It should be setup to run on a schedule. The ecobee documentation can be found on https://www.ecobee.com/home/developer/api/documentation

.PARAMETER apiKey
Specifies the ecobee application key. If you don't have an application key, create one from the ecobee portal.

.PARAMETER workspaceId
Specifies the Azure Log Analytics Workspace ID.

.PARAMETER workspaceKey
Specifies the Azure Log Analytics Workspace Key.

.PARAMETER tokenFile
Specifies the path to the token file (xml). If one doesn't exist, it will be created as long as the script has permissions to the script's folder.

.PARAMETER logType
Specifies the name of the Azure Log Analytics custom log table. This name with a "_CL" appended will be created after the first time logs are sent.
It can take up to an hour for the tables to be initially created.

.INPUTS

None. You cannot pipe objects to Send-EcobeeToAzureMonitor.ps1.

.OUTPUTS

None. Send-EcobeeToAzureMonitor.ps1 does not generate any output.

.EXAMPLE

C:\PS> .\Send-EcobeeToAzureMonitor.ps1 -apiKey Mmmkay -workspaceId eeeeeeee-1234-1234-1234-abcdef012345 -workspaceKey k1234567890Q==

.EXAMPLE

C:\PS> while ($true) {.\Send-EcobeeToAzureMonitor.ps1 -apiKey Mmmkay -workspaceId eeeeeeee-1234-1234-1234-abcdef012345 -workspaceKey k1234567890Q==; Start-Sleep -Seconds 900;}

.EXAMPLE

C:\PS> .\Send-EcobeeToAzureMonitor.ps1 -apiKey Mmmkay -workspaceId eeeeeeee-1234-1234-1234-abcdef012345 -workspaceKey k1234567890Q== -tokenFile C:\temp\ecobee.xml
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [String]$apiKey,
    [Parameter(Mandatory=$true)]
    [String]$workspaceId,
    [Parameter(Mandatory=$true)]
    [String]$workspaceKey,
    $TokenFile = "$Script:PSScriptRoot\Ecobee.xml", # File to save the tokens
    $logType = "ecobee"
)
#Requires -Modules OMSIngestionAPI

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#region Initialization
#Load functions
. $Script:PSScriptRoot\ecobeeFunctions.ps1
#Check for token file
if (!(Test-path $TokenFile) -or !(Import-Clixml -Path $TokenFile).refresh_token) 
    { 
        write-error "No token file found! Run Connect-EcobeeAPI.ps1 first to generate a token file."
    }
else { $Tokens = Import-Clixml -Path $TokenFile }

#Check for expired token
if ($Tokens.expires_at -lt (Get-Date)) 
    { 
        $Tokens = Get-EcobeeNewToken -RefreshToken $Tokens.refresh_token -apiKey $apikey
        Save-EcobeeTokens -Tokens $Tokens

    }
#endregion

## Adding a property here under the proper category will add it to the metrics
$Include = New-Object -TypeName PSObject -Property @{
    Settings = "lastServiceDate","remindMeDate","coldTempAlert","hotTempAlert"
    Runtime = "runtimeInterval","actualTemperature","actualHumidity","desiredHeat","desiredCool","desiredHumidity","desiredDehumidity"
    Weather = "weatherStation"
    ## Categories should contain the names of the above properties
    Categories = "Settings","Runtime","Weather"
}


#Collect data
$EcobeeDetails = Get-EcobeeDetails -AccessToken $Tokens.access_token

foreach ($Thermostat in $EcobeeDetails.thermostatList) {
    
    #Get identifying information
    $logData = New-Object PSObject -Property @{
    Name = $Thermostat.name
    Model = $Thermostat.modelNumber
    revision = $Thermostat.thermostatRev
    equipmentStatus = $Thermostat.equipmentStatus
    eventCount = $Thermostat.events.Count
    reminedMeCountdownMS = $([int64](([datetime]$thermostat.settings.remindMeDate) - (Get-Date)).totalMilliseconds)
    }

    #Get current properties
    foreach ($Category in $Include.Categories) {
    Write-Verbose "Category: $Category"
        foreach ($Property in $Include.$Category) {
            Write-Verbose "   Property: $Property"
            Write-Verbose "$Category - $Property - $($Thermostat.$Category.$Property)"
            $logData | Add-Member -MemberType NoteProperty -Name $Property -value $Thermostat.$Category.$Property
        } # End foreach $Property
    } # End foreach $Category


    #Gather sensor data
    foreach ($Sensor in $Thermostat.remoteSensors)
    {
        foreach ($Capability in $Sensor.capability) 
        {
            if ($Capability.value -eq $null) { $Capability.value = 0 }
            $sensorTag = "$($Capability.type)-$($Sensor.name)"
            $logData | Add-Member -MemberType NoteProperty -Name $sensorTag -Value $Capability.value
        }
    }

    #Gather Current Weather data
    $Weather = $Thermostat.weather.forecasts[0]
    $weatherSensor = $Thermostat.weather.weatherStation
    $wProperties = $Weather | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    foreach ($wProperty in $wProperties) { 
        Write-Verbose "$($wProperty): $($Weather.$wProperty)"
        $logData | Add-Member -MemberType NoteProperty -Name $wProperty -Value $Weather.$wProperty
    }

    #Gather Weather forecast
    ### Forecast seems to have duplicates. Skipping
    foreach ($Day in $Thermostat.weather.forecasts) {
        #Do nothing
    }

} # End foreach $Thermostat


#region Send data to Azure Monitor (Log Analytics)
Import-Module OMSIngestionAPI
$Timestamp = Get-Date
#$TimeStampField = $TimeStampField.GetDateTimeFormats(115)

#Convert to Json, Log Analytics only accepts Json
$body = ConvertTo-Json $logData
Send-OMSAPIIngestionFile -customerId $workspaceId -sharedKey $workspaceKey -body $body -logType $logType -TimeStampField $Timestamp
#endregion

