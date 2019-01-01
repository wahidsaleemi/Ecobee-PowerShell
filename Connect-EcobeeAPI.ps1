[CmdletBinding()]
Param(
    ##########################################
    # User Variables
    ##########################################
    # Go here to register as a developer and get your own API key:
    # https://www.ecobee.com/developers/
    # This script will take care of generating your PIN, and getting the access and refresh tokens!

    [Parameter(Mandatory=$true)]
    [string]$apiKey, ### FILL THIS IN!
    $TokenFile = "$Script:PSScriptRoot\Ecobee.xml" # File to save the tokens
)

#Load common functions
. "$Script:PSScriptRoot\ecobeeFunctions.ps1"

if (!(Test-path $TokenFile) -or !($Tokens = Import-Clixml -Path $TokenFile).refresh_token) { # Assume app is not registered, begin registration routine

    Write-Host "No token file was found at the path specified, or it contains no refresh token. The following proceedure will walk you through registering this script as an App with your Ecobee account.`n" -ForegroundColor Yellow
    Pause
    
    $PIN = Get-EcobeePIN -apikey $apiKey
    Write-Verbose ""
    Write-Host "Here is your PIN:" -NoNewline
    Write-Host "$($PIN.ecobeePin)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Goto ecobee.com, login to the web portal and click on the 'My Apps' tab." -ForegroundColor Cyan
    Write-Host "This will bring you to a page where you can add an application by authorizing your ecobeePin."  -ForegroundColor Cyan
    Write-Host "To do this, type/paste your ecobeePin and click 'Validate'. The next screen will display any permissions the app requires and will ask you to click 'Add Application.'" -ForegroundColor Cyan
    Write-Host "Once you've done this, " -NoNewline; Pause

    Write-Verbose "Fetching first tokens using authCode $($PIN.code)..."
    $Tokens = Get-EcobeeFirstToken -apikey $apikey -authCode $PIN.code
    Save-EcobeeTokens -Tokens $Tokens

    Write-Verbose "Fetching refresh tokens using $($Tokens.refresh_token)..."
    $Tokens = Get-EcoBeeNewToken -apiKey $apiKey -RefreshToken $Tokens.refresh_token
    Save-EcobeeTokens -Tokens $Tokens

}
else { $Tokens = Import-Clixml -Path $TokenFile }

#Check for expired tokens
if ($Tokens.expiree_at -lt (Get-Date)) 
    {
        $Tokens = Get-EcobeeNewToken -RefreshToken $Tokens.refresh_token -apiKey $apikey; Save-EcobeeTokens -Tokens $Tokens
    }

#Get-EcobeeDetails -AccessToken $Tokens.access_token | Select-Object -ExpandProperty thermostatList | Select-Object brand, name, identifier
Write-Host "You are now connected and have an access token." -ForegroundColor Cyan
return $Tokens.access_token
