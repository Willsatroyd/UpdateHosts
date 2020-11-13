<#
    .SYNOPSIS
    Generates a hosts file to block unwanted domains.

    .DESCRIPTION
    Updates the local hosts file to include the domains in both the local file $UserHostsFile and downloaded entries from the list $UriList and points all those domains to an IP specified by $IpToUse (127.0.0.1 by default).
    Requires the module Module-PSLogging.

    .PARAMETER UserHostsFile
    Describes the full path to a user-generated 'base' hosts file. This should have a standard hosts file layout and encoding (ascii).

    .PARAMETER IpToUse
    Defines the IP address to use in the final hosts file. 0.0.0.0 may be used for blocking in systems running a local web server and is the default.
    The IP addresses for entries in the $UserHostsFile input file are not changed.

    .NOTES
    Conan Wills - conan@conanw.pro
    Updated 13/11/2020
#>

#region SCRIPT PARAMETERS
#===============================================================================

#Requires -version 5.1

#Requires -Modules Module-PsLogging

[CmdletBinding()]

param (

    [ValidateScript({Test-Path $_})]
    [string]$UserHostsFile = '.\MyHosts.txt',

    [ValidateSet('127.0.0.1','0.0.0.0')]
    [string]$IpToUse = '0.0.0.0'
)

#endregion

#region SCRIPT VARIABLES
#===============================================================================

#Get the start time
$ScriptStartTime = Get-Date

#Version
$ScriptVersion = '8.0'

#Make all errors terminating, as we're intending to handle that
$ErrorActionPreference = 'stop'

#This script's event log ID range - information only
$EventLogIdRange = 100..199

#The event log to use
$ScriptEventLog = 'ConeScript'

#The URIs to get the hosts info from - be careful, too many will generate a hosts file that the OS can't cope with and kill all network operations (and thus the machine).
$UriList = @(

    'http://pgl.yoyo.org/adservers/serverlist.php?showintro=0;hostformat=hosts',
    'http://someonewhocares.org/hosts/',
	'http://www.malwaredomainlist.com/hostslist/hosts.txt',
	'https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Dead/hosts',
	'https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts'#,
    #'http://sysctl.org/cameleon/hosts.win',
    #'http://winhelp2002.mvps.org/hosts.txt',
    #'https://adaway.org/hosts.txt',
    #'https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts',
    #'https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts'
  )

$ScriptVerbosePreference = $VerbosePreference

#endregion

#region FUNCTIONS
#===============================================================================

function Complete-Script {

	<#
		.SYNOPSIS
		Stops logging and cleanly ends the script, producing an exit code.
	#>

	param (

		[string]$ScriptExitMsg = 'End-Script called without an exit message being passed.',

		#Exit code default is always '1' for Unknown.
		[int]$ScriptExitCode = 1
	)

	if ($ScriptLogger) {

		#Stop logging
		Stop-ScriptEventLogging -ScriptEventLogger $ScriptLogger -ScriptExitMsg $ScriptExitMsg -ScriptExitCode $ScriptExitCode
	}
	else {

		#Only go bang if the scriptlogger does not exist.
		#(Probably because we failed to import the logging module).
		Write-Error -Message $Error[0].Exception.Message
	}

	#Produce an exit code
	EXIT $ScriptExitCode
}

#endregion

#region MAIN PROCESS - Logging IDs 641xx
#===============================================================================

#Clear all errors
$Error.Clear()

#Start logging
$ScriptLoggerOptions = @{

    ScriptInvocation        = $MyInvocation
    ScriptEventLog          = $ScriptEventLog
    ScriptStartTime         = $ScriptStartTime
    ScriptVersion           = $ScriptVersion
    ScriptVerbosePreference = $ScriptVerbosePreference
}

$ScriptLogger = Start-ScriptEventLogging @ScriptLoggerOptions

#Test for Internet connectivity
$WriteScriptEventProperty = @{

    ScriptEventLogger   = $ScriptLogger
    EventType           = 'Information'
    EventDescription    = 'Testing Internet connectivity.'
    ScriptEventId       = 64100
}
Write-ScriptEvent @WriteScriptEventProperty

if (!(Test-NetConnection -Port 80).TcpTestSucceeded) {

    Complete-Script -ScriptExitMsg 'Could not access Internet.' -ScriptExitCode 3
}

try {

    #Get entries from the user file
    $WriteScriptEventProperty = @{

        ScriptEventLogger   = $ScriptLogger
        EventType           = 'Information'
        EventDescription    = 'Getting hosts from the user file.'
        ScriptEventId       = 64101
    }

    Write-ScriptEvent @WriteScriptEventProperty

    $BaseHostDets = Get-Content -Path $UserHostsFile

    #Get the hosts list from each URI
    foreach ($Uri in $UriList) {

        $WriteScriptEventProperty = @{

            ScriptEventLogger   = $ScriptLogger
            EventType           = 'Information'
            EventDescription    = 'Getting hosts from {0}.' -f $Uri
            ScriptEventId       = 64102
        }

        Write-ScriptEvent @WriteScriptEventProperty

        #Get the response and add it to the list
        $DownloadedDetails += (Invoke-WebRequest -Uri $Uri -UseBasicParsing).RawContent
    }

    #Process the Results
    $WriteScriptEventProperty = @{

        ScriptEventLogger   = $ScriptLogger
        EventType           = 'Information'
        EventDescription    = 'Processing all the host entries.'
        ScriptEventId       = 64103
    }

    Write-ScriptEvent @WriteScriptEventProperty

    <#
		Get only the lines with IP addresses,
		filter out any localhost entries (the latter should come from the user file),
		grab the domain and finally remove any in-line comments
	#>

    $Domains = $DownloadedDetails.Split("`r`n") | Where-Object {

			$_ -match '([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}' -and $_ -notmatch 'localhost'

    } | ForEach-Object {($_ -replace '\s+',' ').Split()[1].Split('#')[0]}

    #Sort and dedupe
    $SortedDomains = $Domains | Sort-Object -Unique

    #Add the user's chosen localhost IP address
    $ReIpedHostDets += $SortedDomains[0..$($SortedDomains.Count)] | ForEach-Object {$IpToUse + "`t" + $_}

    #Add what we've downloaded to the user data
    $AllHostDets = $BaseHostDets + $ReIpedHostDets

    #Prefix the file with a label
    $FinalHostDets = @("#Created by $($ScriptLogger.ScriptName) version $ScriptVersion on $((Get-Date).ToString())`r`n") + $AllHostDets

    #Write the new file
    $WriteScriptEventProperty = @{

        ScriptEventLogger   = $ScriptLogger
        EventType           = 'Information'
        EventDescription    = 'Writing the new hosts file.'
        ScriptEventId       = 64104
    }

    Write-ScriptEvent @WriteScriptEventProperty

    Out-File -FilePath "$env:windir\System32\drivers\etc\hosts" -Force -Encoding ascii -InputObject $FinalHostDets

    #Clear the DNS cache
    $WriteScriptEventProperty = @{

        ScriptEventLogger   = $ScriptLogger
        EventType           = 'Information'
        EventDescription    = 'Clearing DNS client cache.'
        ScriptEventId       = 64105
    }

    Write-ScriptEvent @WriteScriptEventProperty

    Clear-DnsClientCache
}
catch {

    Complete-Script -ScriptExitMsg $Error[0] -ScriptExitCode 4
}

#Finish
Complete-Script -ScriptExitMsg 'Script completed successfully.' -ScriptExitCode 0

#endregion