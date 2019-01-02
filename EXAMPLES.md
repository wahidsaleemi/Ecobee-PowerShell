# EXAMPLES

## Init

This script blok shows the initial connection, loading the functions. This is necessary for everything that follows.

````PowerShell
$apikey = ""
$token = .\Connect-EcobeeAPI.ps1 -apiKey $apikey -Verbose

#Load functions
. .\ecobeeFunctions.ps1 -Verbose
````

## Summary

We can get a quick summary:

````PowerShell
#Summary
Get-EcobeeSummary -AccessToken $token
````

````json
thermostatCount revisionList                         statusList         status
--------------- ------------                         ----------         ------
              1 {411999999999:Upstairs:true:x:x:x:x} {411999999999:fan} @{code=0; message=}
````

## Details

First we assign a variable so we can store all the details. Then we can use this variable in the future without directly querying the thermostat. We can get some basic information as shown.

````PowerShell
#Details
$details = (Get-EcobeeDetails -AccessToken $token).thermostatList

#Get basic information
$details | select brand, name, isRegistered, modelNumber, features, equipmentStatus
````

````json
brand           : ecobee
name            : Upstairs
isRegistered    : True
modelNumber     : nikeSmart
features        : Home,HomeKit
equipmentStatus : fan
````

## Alerts

We can also get any active alerts

````PowerShell
#Get alerts (if any)
$details | select -ExpandProperty alerts
````

## Runtime

We can get some runtime settings like the actual temperature.

````PowerShell
#Get runtime settings
$details | select -expandProperty runtime | select connected, desiredHeat, actualTemperature, desiredHumidity, actualHumidity
````

````json
connected         : True
desiredHeat       : 710
actualTemperature : 707
desiredHumidity   : 36
actualHumidity    : 33
````

## Events

We can see events. In this example, my thermostat is set to hold temperatures between 71 and 76 degrees F by a schedule.
Note: ecobee reports temperature values multiplied by 10 so 710 is actually 71.0 F.

````PowerShell
#Get events
$details | select -expandProperty events | select name, type, running, coolHoldTemp, heatHoldTemp, fan
````

````json
name         : auto
type         : hold
running      : True
coolHoldTemp : 760
heatHoldTemp : 710
fan          : on
````

## Weather

What's the weather?

````PowerShell
#Get weather
$details | select -ExpandProperty weather | select -ExpandProperty forecasts | sort dateTime | select dateTime, condition, temperature
````

It's cold!

````json
dateTime            condition                         temperature
--------            ---------                         -----------
2019-01-02 10:02:40 Foggy                                     328
2019-01-02 12:00:00 Rain                                      337
2019-01-02 18:00:00 Light Rain                                370
2019-01-03 00:00:00 Rain until afternoon.                     351
2019-01-03 00:00:00 Overcast                                  356
2019-01-03 06:00:00 Light Rain                                353
2019-01-04 00:00:00 Partly cloudy throughout the day.         415
2019-01-05 00:00:00 Partly cloudy until evening.              425
2019-01-06 00:00:00 Mostly cloudy throughout the day.         533
````