#==================================================================================
# Script: 	Get-RemoteAccessHealthInfo.ps1
# Date:		17/05/2019
# Author: 	Andi Patrick
# Purpose:	Gets Helth Info from Remote Access Server
# Notes :	Created from the Microsoft Script in Remote.Access.2012.R2 Management Pack
#			All work by Microsoft, I have merely updated it and sent the logging to the 
#			Operations Manager Event Log.
#==================================================================================
param($debug)

	#Constants used for event logging
	$SCRIPT_NAME			= 'Get-RemoteAccessHealthInfo.ps1'
	$EVENT_LEVEL_ERROR 		= 1
	$EVENT_LEVEL_WARNING 	= 2
	$EVENT_LEVEL_INFO 		= 4

	$SCRIPT_STARTED				= 4806
	$SCRIPT_DISCOVERY_CREATED	= 4807
	$SCRIPT_EVENT				= 4808
	$SCRIPT_ENDED				= 4809
	$SCRIPT_ERROR				= 4810

	# Create API
    $api = new-object -comObject 'MOM.ScriptAPI'

	# Log Start Message
	If ($debug -eq $true) {
		$message = "Health Info Script Started..."
		$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_STARTED,$EVENT_LEVEL_INFO,$message)	
	}

	Try {
		$health = Get-RemoteAccessHealth

		foreach ($component in $health){

			If ($debug -eq $true) {
				$message = "Component : " + $component.Component + " HealthState : " + $component.HealthState
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)						
			}

			if(($component.HealthState -eq "Warning") -or ($component.HealthState -eq "Error")){
				foreach ($heuristic in $component.Heuristics){
					If ($debug -eq $true) {
						$message = "Heuristic ID : " + $heuristic.Id
						$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)						
					}
					$Bag = $api.CreatePropertyBag()
					$Bag.AddValue("Component",$component.Component)
					$Bag.AddValue("State",$heuristic.Status)
					$Bag.AddValue("ID",$heuristic.Id)
					$Bag.AddValue("ErrorDesc", $heuristic.ErrorDescription)
					$Bag.AddValue("ErrorResolution", $heuristic.ErrorResolution)
					$Bag.AddValue("ErrorCause", $heuristic.ErrorCause)
					$Bag
				}
			}elseif($component.HealthState -eq "OK"){
				If ($debug -eq $true) {
					$message = "Healthy Component : " + $component.Component
					$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)						
				}
				$Bag = $api.CreatePropertyBag()
				$Bag.AddValue("Component",$component.Component)
				$Bag.AddValue("State",$component.HealthState)
				$Bag.AddValue("ID","-1")
				$Bag.AddValue("ErrorDesc", "")
				$Bag.AddValue("ErrorResoln", "")
				$Bag.AddValue("ErrorCause", "")
				$Bag
			}else{
				If ($debug -eq $true) {
					$message = "[Get-RemoteAccessHealth] Component " + $component.Component + " unavailable"
					$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_ERROR,$EVENT_LEVEL_ERROR,$message)				
				}
			}
		}
	} Catch {
		$message = "Error Occured : " + $_
		$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_ERROR,$EVENT_LEVEL_ERROR,$message)
	}

	If ($debug -eq $true) {
		$message = "Health Info Script Complete"
		$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_ENDED,$EVENT_LEVEL_INFO,$message)
	}