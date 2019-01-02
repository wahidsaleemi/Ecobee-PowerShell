[CmdletBinding()]
Param(
    $TokenFile = "$Script:PSScriptRoot\Ecobee.xml", # File to save the tokens
    $logType = "ecobee",
    $workspaceId = "",
    $workspaceKey = ""
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
if ($Tokens.expiree_at -lt (Get-Date)) 
    { 
        $apiKey = Read-Host -Prompt "Please enter the API Key from the ecobee portal"
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