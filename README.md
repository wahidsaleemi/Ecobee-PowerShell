# Ecobee

Modification of EcobeeToInflux repo to make it more modular and feed data to Azure Log Analytics (eventually)

## Usage

Use Connect-EcobeeAPI.ps1 to get a token. This script loads functions from ecobeeFunctions.ps1. Example usage:

````PowerShell
$token = .\Connect-EcobeeAPI.ps1 -apiKey "0123456789abcdef0123456789abcdef"
````

On first run, the script will pause after getting your PIN, this needs to be entered in your [ecobee portal](https://www.ecobee.com) to authorize the script to get tokens.

You can use $token in other commands such as:

````PowerShell
Get-EcobeeDetails -AccessToken $token | Select-Object -ExpandProperty thermostatList | Select-Object brand, name, identifier
````

Or:

````PowerShell
Get-EcobeeSummary -AccessToken $token
````

## Prerequisites

1. You need to enable the developer dashboard in your ecobee portal. If you did not initially register your ecobee when it was installed, register it first. Then enable the developer dashboard by signing up here: [https://www.ecobee.com/developers/](https://www.ecobee.com/developers/)

1. Next, you will need to create an app with any name you like (such as pwsh-pin). This will give you an API Key that you can use to run the script.

## Send-EcobeeToAzureMonitor.ps1

You can run this on an always on computer inside a PowerShell console, like so:

````PowerShell
while ($true) {C:\Code\EcobeeToInflux\Send-EcobeeToAzureMonitor.ps1 -workspaceId 12345678-xxxx-yyyy-zzzz-123456789012 -workspaceKey aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4Q== -TokenFile
C:\Code\EcobeeToInflux\Ecobee.xml; Start-Sleep -Seconds 900;}
````

Using task scheduler or some other means is probably better.

## EcobeeToInflux (forked)

Powershell code for communicating with the Ecobee API to retrieve metrics, and then feed it to InfluxDB

You'll need to [sign up with Ecobee as a developer](https://www.ecobee.com/home/developer/api/introduction/index.shtml), create an app wich any name you like, then copy your new API key and paste it into the $api variable in the script.
Run the script once manually to generate the PIN for you to add to your Ecobee "My Apps" list.

After it has generated the tokens, it ran run repeatedly. Ecobee states that you should not run an API call more frequent than 3 minutes apart, and that your Ecobee only updates stats every 15 minutes anyway.

I suggest having the script run like this:

````PowerShell
while ($True) { .\ecobee.ps1; Start-Sleep -Seconds 900; }
````

Where 900 seconds equals 15 minutes.

Or add it as a scheduled task. But be sure to run it manually the first time to get your tokens.
