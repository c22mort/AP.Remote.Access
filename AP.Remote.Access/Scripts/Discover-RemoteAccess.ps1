#==================================================================================
# Script: 	Discover-RemoteAccess.ps1
# Date:		17/05/2019
# Author: 	Andi Patrick
# Purpose:	Discovers Remote Access Objects From Seed Object
# Notes :	Created from the Microsoft Script in Remote.Access.2012.R2 Management Pack
#			All work by Microsoft, I have merely updated it and sent the logging to the 
#			Operations Manager Event Log.
#==================================================================================
param(
	$sourceId,
	$managedEntityId,
	$computerName,
	$createSingleSite
)

	#Constants used for event logging
	$SCRIPT_NAME			= 'Discover-RemoteAccess.ps1'
	$EVENT_LEVEL_ERROR 		= 1
	$EVENT_LEVEL_WARNING 	= 2
	$EVENT_LEVEL_INFO 		= 4

	$SCRIPT_STARTED				= 4801
	$SCRIPT_DISCOVERY_CREATED	= 4802
	$SCRIPT_EVENT				= 4803
	$SCRIPT_ENDED				= 4804
	$SCRIPT_ERROR				= 4805

	# Create API
    $api = new-object -comObject 'MOM.ScriptAPI'

	# Log Start Message
	$message = "Starting Discovery at (" + $computerName + ")"
	$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_STARTED,$EVENT_LEVEL_INFO,$message)

	# Create Discovery Data Object
    $discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

	# Set Enterprise Name
    $enterpriseName = "Microsoft RemoteAccess"
	
	# Get Current User
    $ab = [Security.Principal.WindowsIdentity]::GetCurrent()

	# Log  Message
	$message = "Discovery identity is " + $ab.Name
	$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)

    # if( $myRRAS -ne $null ){
    try{
		$daMultisite = $null

		# Get Remote Acceess Info
		$myRRAS = get-remoteaccess

		# Create Remote Access Server
		$message = "Creating raServer Object ( " + $computerName + ")"
		$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
		$raServer = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.RemoteAccessServer']$")
		$raServer.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
		$raServer.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "RemoteAccessServer (" + $computerName + ")")
		$discoveryData.AddInstance($raServer)

		try{

			$daMultisite = Get-DAMultisite
			$enterpriseName = $daMultisite.EnterpriseName

			# Create Remote Access Object
			$message ="Creating an Enterprize Object, Enterprise Name (" + $enterpriseName + ")"
			$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
			$raApp = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.MicrosoftRemoteAccess']$")
			$raApp.AddProperty("$MPElement[Name='AP.Remote.Access.Class.MicrosoftRemoteAccess']/ApplicationName$", $enterpriseName)
			$raApp.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $enterpriseName)
			$discoveryData.AddInstance($raApp)

			# Crete Remote Access Site Object
			$message = "Creating site " + 
			$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
			$site = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.RemoteAccessSite']$")
			$site.AddProperty("$MPElement[Name='AP.Remote.Access.Class.RemoteAccessSite']/ApplicationName$", $enterpriseName)
			$site.AddProperty("$MPElement[Name='AP.Remote.Access.Class.RemoteAccessSite']/ContainerName$", $myRRAS.EntryPointName)
			$site.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $myRRAS.EntryPointName)
			$discoveryData.AddInstance($site)

			# Create Relationship
			$rel_site_server = $discoveryData.CreateRelationshipInstance("$MPElement[Name='RemoteAccessSite.Contains.RemoteAccessServer']$")
			$rel_site_server.Source = $site
			$rel_site_server.Target = $raServer
			$discoveryData.AddInstance($rel_site_server)

			# Create Relationship
			$rel_MSRRAS_Site = $discoveryData.CreateRelationshipInstance("$MPElement[Name='MicrosoftRemoteAccess.Contains.RemoteAccessSite']$")
			$rel_MSRRAS_Site.Source = $raApp
			$rel_MSRRAS_Site.Target = $site
			$discoveryData.AddInstance($rel_MSRRAS_Site)
		}
		catch
		{
			# Show Errors
			$message = "Multisite is not enabled at (" + $computerName + ")"
			$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_WARNING,$message)
			$message = "Multisite Error: " + $_
			$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_WARNING,$message)

			If ($createSingleSite -eq $true) {
				$message = "Creating single site at (" + $computerName + ")"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)

				# Create Remote Access Object
				$message ="Creating an Enterprize Object, Enterprise Name (" + $enterpriseName + ")"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$raApp = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.MicrosoftRemoteAccess']$")
				$raApp.AddProperty("$MPElement[Name='AP.Remote.Access.Class.MicrosoftRemoteAccess']/ApplicationName$", $enterpriseName)
				$raApp.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $enterpriseName)
				$discoveryData.AddInstance($raApp)

				# Crete Remote Access Site Object
				$message = "Creating site " + $myRRAS.ConnectToAddress
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$site = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.RemoteAccessSite']$")
				$site.AddProperty("$MPElement[Name='AP.Remote.Access.Class.RemoteAccessSite']/ApplicationName$", $enterpriseName)
				$site.AddProperty("$MPElement[Name='AP.Remote.Access.Class.RemoteAccessSite']/ContainerName$", $myRRAS.ConnectToAddress)
				$site.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $myRRAS.ConnectToAddress)
				$discoveryData.AddInstance($site)

				# Create Relationship
				$rel_site_server = $discoveryData.CreateRelationshipInstance("$MPElement[Name='RemoteAccessSite.Contains.RemoteAccessServer']$")
				$rel_site_server.Source = $site
				$rel_site_server.Target = $raServer
				$discoveryData.AddInstance($rel_site_server)

				# Create Relationship
				$rel_MSRRAS_Site = $discoveryData.CreateRelationshipInstance("$MPElement[Name='MicrosoftRemoteAccess.Contains.RemoteAccessSite']$")
				$rel_MSRRAS_Site.Source = $raApp
				$rel_MSRRAS_Site.Target = $site
				$discoveryData.AddInstance($rel_MSRRAS_Site)    
			}
		}

		if ( $myRRAS.VpnStatus -eq "Installed" )
		{
			# Create VPN Server (if needed)
			$message = "VPN Server Discovered"
			$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
			$vpn = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.VPNServer']$")
			$vpn.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "VPNServer (" + $computerName + ")")
			$vpn.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
			$discoveryData.AddInstance($vpn)

			# Create Relationship
			$message = "Creating relationship (RemoteAccessServer.Hosts.VPNServer)"
			$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
			$rel_RasServer_VPN = $discoveryData.CreateRelationshipInstance("$MPElement[Name='RemoteAccessServer.Hosts.VPNServer']$")
			$rel_RasServer_VPN.Source = $raServer
			$rel_RasServer_VPN.Target = $vpn
			$discoveryData.AddInstance($rel_RasServer_VPN)
		}

		if ( $myRRAS.DAStatus -eq "Installed" )
		{
			# Create Direct Acceess Serve (if needed)
			$message = "DirectAccess Server Discovered"
			$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
			$daserver = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.DirectAccessServer']$")
			$daserver.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "Direct Access Server (" + $computerName + ")")
			$daserver.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
			$discoveryData.AddInstance($daserver)

			# Create Relationship
			$message = "Creating relationship (RemoteAccessServer.Hosts.DirectAccessServer)"
			$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
			$rel_RasServer_DAServer = $discoveryData.CreateRelationshipInstance("$MPElement[Name='RemoteAccessServer.Hosts.DirectAccessServer']$")
			$rel_RasServer_DAServer.Source = $raServer
			$rel_RasServer_DAServer.Target = $daserver
			$discoveryData.AddInstance($rel_RasServer_DAServer)

			$RemoteAccessHealth = get-RemoteAccessHealth

			$TeredoHealth = $RemoteAccessHealth | where Component -eq "Teredo"
    
			if ( $TeredoHealth.HealthState -ne "Disabled" )
			{
				# Create Teredo Object
				$message = "Teredo discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$teredo = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.Teredo']$")
				$teredo.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$teredo.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "Teredo (" + $computerName + ")")
				$discoveryData.AddInstance($teredo)

				$daHostsTeredo = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.Teredo']$")
				$daHostsTeredo.Source = $daserver
				$daHostsTeredo.Target = $teredo
				$discoveryData.AddInstance($daHostsTeredo)
				}

			$IPHTTPSHealth = $RemoteAccessHealth | where Component -eq "IP-Https"
    
			if ( $IPHTTPSHealth.HealthState -ne "Disabled" )
			{
				$message = "IPHTTPS discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$iphttps = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.IPHTTPS']$")
				$iphttps.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$iphttps.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "IP-Https (" + $computerName + ")")
				$discoveryData.AddInstance($iphttps)

				$daHostsIPHttps = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.IPHTTPS']$")
				$daHostsIPHttps.Source = $daserver
				$daHostsIPHttps.Target = $iphttps
				$discoveryData.AddInstance($daHostsIPHttps)
			}

			$6to4Health = $RemoteAccessHealth | where Component -eq "6to4"

			if ( $6to4Health.HealthState -ne "Disabled" )
			{
				$message = "6to4 discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$6to4 = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.6to4']$")
				$6to4.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$6to4.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "6to4 (" + $computerName + ")")
				$discoveryData.AddInstance($6to4)

				$daHosts6to4 = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.6to4']$")
				$daHosts6to4.Source = $daserver
				$daHosts6to4.Target = $6to4
				$discoveryData.AddInstance($daHosts6to4)
			}

			$DNSHealth = $RemoteAccessHealth | where Component -eq "Dns"
    
			if ( $DNSHealth.HealthState -ne "Disabled" )
			{
				$message = "DNS discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$dnssvr = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.DNS']$")
				$dnssvr.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$dnssvr.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "DNS (" + $computerName + ")")
				$discoveryData.AddInstance($dnssvr)

				$daHostsdns = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.DNS']$")
				$daHostsdns.Source = $daserver
				$daHostsdns.Target = $dnssvr
				$discoveryData.AddInstance($daHostsdns)
			}

			$DNS64Health = $RemoteAccessHealth | where Component -eq "Dns64"
    
			if ( $DNS64Health.HealthState -ne "Disabled" )
			{
				$message = "DNS64 discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$dns64svr = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.DNS64']$")
				$dns64svr.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$dns64svr.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "DNS64 (" + $computerName + ")")
				$discoveryData.AddInstance($dns64svr)

				$daHostsdns64 = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.DNS64']$")
				$daHostsdns64.Source = $daserver
				$daHostsdns64.Target = $dns64svr
				$discoveryData.AddInstance($daHostsdns64)
			}

			$DCHealth = $RemoteAccessHealth | where Component -eq "Domain Controller"
    
			if ( $DCHealth.HealthState -ne "Disabled" )
			{
				$message = "DC discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$dcsvr = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.DomainController']$")
				$dcsvr.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$dcsvr.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "DC (" + $computerName + ")")
				$discoveryData.AddInstance($dcsvr)

				$daHostsdc = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.DomainController']$")
				$daHostsdc.Source = $daserver
				$daHostsdc.Target = $dcsvr
				$discoveryData.AddInstance($daHostsdc)
			}

			$IPSecHealth = $RemoteAccessHealth | where Component -eq "IPsec"
    
			if ( $IPSecHealth.HealthState -ne "Disabled" )
			{
				$message = "IPSec discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$IPSec = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.IPSec']$")
				$IPSec.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$IPSec.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "IPSec (" + $computerName + ")")
				$discoveryData.AddInstance($IPSec)

				$daHostsIPSec = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.IPSec']$")
				$daHostsIPSec.Source = $daserver
				$daHostsIPSec.Target = $IPSec
				$discoveryData.AddInstance($daHostsIPSec)
			}

			$MgmtSvrHealth = $RemoteAccessHealth | where Component -eq "Management Servers"

			if ( $MgmtSvrHealth.HealthState -ne "Disabled" )
			{
				$message = "ManagementServers discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$MgmtSvr = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.ManagementServers']$")
				$MgmtSvr.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$MgmtSvr.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "ManagementServers (" + $computerName + ")")
				$discoveryData.AddInstance($MgmtSvr)

				$daHostsMgmtSvr = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.ManagementServers']$")
				$daHostsMgmtSvr.Source = $daserver
				$daHostsMgmtSvr.Target = $MgmtSvr
				$discoveryData.AddInstance($daHostsMgmtSvr)
			}

			$NAT64Health = $RemoteAccessHealth | where Component -eq "Nat64"

			if ( $NAT64Health.HealthState -ne "Disabled" )
			{
				$message = "Nat64 discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$Nat64 = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.NAT64']$")
				$Nat64.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$Nat64.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "NAT64 (" + $computerName + ")")
				$discoveryData.AddInstance($Nat64)

				$daHostsNat64 = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.NAT64']$")
				$daHostsNat64.Source = $daserver
				$daHostsNat64.Target = $Nat64
				$discoveryData.AddInstance($daHostsNat64)
			}

			$NetworkHealth = $RemoteAccessHealth | where Component -eq "Network Adapters"

			if ( $NetworkHealth.HealthState -ne "Disabled" )
			{
				$message = "Network Adapters discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$NetworkAdapters = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.NetworkAdapters']$")
				$NetworkAdapters.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$NetworkAdapters.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "NetworkAdapters (" + $computerName + ")")
				$discoveryData.AddInstance($NetworkAdapters)

				$daHostsNetwork = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.NetworkAdapters']$")
				$daHostsNetwork.Source = $daserver
				$daHostsNetwork.Target = $NetworkAdapters
				$discoveryData.AddInstance($daHostsNetwork)
			}

			$NLSHealth = $RemoteAccessHealth | where Component -eq "Network Location Server"

			if ( $NLSHealth.HealthState -ne "Disabled" )
			{
				$message = "NLS discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$NLS = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.NetworkLocationServer']$")
				$NLS.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$NLS.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "NetworkLocationServer (" + $computerName + ")")
				$discoveryData.AddInstance($NLS)

				$daHostsNLS = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.NetworkLocationServer']$")
				$daHostsNLS.Source = $daserver
				$daHostsNLS.Target = $NLS
				$discoveryData.AddInstance($daHostsNLS)
			}

			$NetSecHealth = $RemoteAccessHealth | where Component -eq "Network Security"

			if ( $NetSecHealth.HealthState -ne "Disabled" )
			{
				$message = "NetSec discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$NetSec = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.NetworkSecurity']$")
				$NetSec.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$NetSec.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "NetworkSecurity (" + $computerName + ")")
				$discoveryData.AddInstance($NetSec)

				$daHostsNetSec = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.NetworkSecurity']$")
				$daHostsNetSec.Source = $daserver
				$daHostsNetSec.Target = $NetSec
				$discoveryData.AddInstance($daHostsNetSec)
			}

			$ServicesHealth = $RemoteAccessHealth | where Component -eq "Services"

			if ( $ServicesHealth.HealthState -ne "Disabled" )
			{
				$message = "Services discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$Services = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.Services']$")
				$Services.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$Services.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "Services (" + $computerName + ")")
				$discoveryData.AddInstance($Services)

				$daHostsServices = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.Services']$")
				$daHostsServices.Source = $daserver
				$daHostsServices.Target = $Services
				$discoveryData.AddInstance($daHostsServices)
			}

			$ISATAPHealth = $RemoteAccessHealth | where Component -eq "Isatap"

			if ( $ISATAPHealth.HealthState -ne "Disabled" )
			{
				$message = "Isatap discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$Isatap = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.ISATAP']$")
				$Isatap.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$Isatap.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "Isatap (" + $computerName + ")")
				$discoveryData.AddInstance($Isatap)

				$daHostsIsatap = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.ISATAP']$")
				$daHostsIsatap.Source = $daserver
				$daHostsIsatap.Target = $Isatap
				$discoveryData.AddInstance($daHostsIsatap)
			}

			$KerberosHealth = $RemoteAccessHealth | where Component -eq "Kerberos"

			if ( $KerberosHealth.HealthState -ne "Disabled" )
			{
				$message = "Kerberos discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$Kerberos = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.Kerberos']$")
				$Kerberos.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$Kerberos.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "Kerberos (" + $computerName + ")")
				$discoveryData.AddInstance($Kerberos)

				$daHostsKerberos = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.Kerberos']$")
				$daHostsKerberos.Source = $daserver
				$daHostsKerberos.Target = $Kerberos
				$discoveryData.AddInstance($daHostsKerberos)
			}

			$OtpHealth = $RemoteAccessHealth | where Component -eq "Otp"

			if ( $OtpHealth.HealthState -ne "Disabled" )
			{
				$message = "Otp discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$Otp = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.Otp']$")
				$Otp.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$Otp.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "Otp (" + $computerName + ")")
				$discoveryData.AddInstance($Otp)

				$daHostsOtp = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.Otp']$")
				$daHostsOtp.Source = $daserver
				$daHostsOtp.Target = $Otp
				$discoveryData.AddInstance($daHostsOtp)
			}

			$HAHealth = $RemoteAccessHealth | where Component -eq "High Availability"

			if ( $HAHealth.HealthState -ne "Disabled" )
			{
				$message = "High Availability discovered"
				$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_EVENT,$EVENT_LEVEL_INFO,$message)
				$HA = $discoveryData.CreateClassInstance("$MPElement[Name='AP.Remote.Access.Class.HighAvailability']$")
				$HA.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
				$HA.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "HighAvailability (" + $computerName + ")")
				$discoveryData.AddInstance($HA)

				$daHostsHA = $discoveryData.CreateRelationshipInstance("$MPElement[Name='DirectAccessServer.Hosts.HighAvailability']$")
				$daHostsHA.Source = $daserver
				$daHostsHA.Target = $HA
				$discoveryData.AddInstance($daHostsHA)
			}
		}
	}
	catch
	{
		# Show Errors
		$message = "Error occured while running Discovery at (" + $computerName + ")"
		$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_ERROR,$EVENT_LEVEL_ERROR,$message)
		$message ="Error Data: " + $_
    	$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_ERROR,$EVENT_LEVEL_ERROR,$message)
	}

	$message = "Discovery Complete"
	$api.LogScriptEvent($SCRIPT_NAME,$SCRIPT_ENDED,$EVENT_LEVEL_INFO,$message)
    
	$discoveryData