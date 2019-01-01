#=========================================================================
# FUNCTIONS
# These should be loaded from another script (. .\echobeeFunctions.ps1)
#=========================================================================

# Obtain Pin and Auth code. The PIN is only needed to authenticate this app's API Key to a user's account.
function Get-EcobeePIN {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$apikey
    )

    if (!$apiKey) { Write-Error "No API Key found!"; exit; }
    $url = "https://api.ecobee.com/authorize?response_type=ecobeePin&client_id="+ $apiKey + "&scope=smartWrite"

    $Result = Invoke-RestMethod -Method GET -Uri $url
    
    # User takes the PIN from this and adds it to "My Apps"
    $Result
}

# Obtain Access Token. Use this function just after the user adds thie app
function Get-EcobeeFirstToken {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$authCode,
        [Parameter(Mandatory=$true)]
        [string]$apikey
    )

    $url = "https://api.ecobee.com/token"
    $data = "grant_type=ecobeePin&code=" + $authCode + "&client_id=" + $apiKey

    $Result = Invoke-RestMethod -Method POST -Uri $url -Body $data

    $Result
}

# Renew token
function Get-EcobeeNewToken {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$RefreshToken,
        [Parameter(Mandatory=$true)]
        [String]$apiKey
    )

    $url = "https://api.ecobee.com/token"
    $data = "grant_type=refresh_token&code=" + $RefreshToken + "&client_id=" + $apiKey
    
    $Result = Invoke-RestMethod -Method POST -Uri $url -Body $data
    
    $Result
}

# Save token
function Save-EcobeeTokens {
    Param(
        [psobject]$Tokens
    )

    # Validate $Tokens
    if (!($Tokens.refresh_token)) { write-error "No refresh token found! Not saving!"; exit; }

    # Add useful properties
    Add-Member -InputObject $Tokens -MemberType NoteProperty -Name expires_at -Value (Get-Date).AddSeconds($Tokens.expires_in) -Force
    Add-Member -InputObject $Tokens -MemberType NoteProperty -Name last_refresh -Value (Get-Date) -Force

    $Tokens | Export-Clixml -Path $TokenFile
}

# Get Temperature
function Get-EcobeeDetails {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$AccessToken
    )
    if (!$AccessToken) { Write-Error "No Access Token!"; exit; }

    $url = 'https://api.ecobee.com/1/thermostat?format=json&body={"selection":{"selectionType":"registered","selectionMatch":"","includeRuntime":true,"includeSensors":true,"includeSettings":true,"includeAlerts":true,"includeEvents":true,"includeEquipmentStatus":true,"includeWeather":true}}'
    $header = "Bearer $accessToken"

    $Result = Invoke-RestMethod -Method GET -Uri $url -Headers @{Authorization=$header} -ContentType "application/json"

    $Result
}

# Get a runtime report
<#
For exmple, the row:
"2014-12-31,19:55:00,30,0,30,17.6,69.4,"                            
                            
Represents the time slot at 7:55pm on December 31, 2014 thermostat time. The heating and fan was on for 30 seconds within this 5 minutes time slot. 
The outside temperature was 17.6℉ and the average indoor temperature was 69.4℉.
#>
function Get-EcobeeSummary {
    if (!$accessToken) { Write-Error "No Access Token!"; exit; }

    $url = 'https://api.ecobee.com/1/thermostatSummary?format=json&body={"selection":{"selectionType":"registered","selectionMatch":"","includeRuntime":true,"includeSensors":true,"includeSettings":true,"includeAlerts":true,"includeEvents":true,"includeEquipmentStatus":true,"includeWeather":true,"includeElectricity":true}}'
    $header = "Bearer $accessToken"

    $Result = Invoke-RestMethod -Method GET -Uri $url -Headers @{Authorization=$header} -ContentType "application/json"

    $Result
}