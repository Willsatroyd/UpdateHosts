<#
    .SYNOPSIS
    Generates a new Windows hosts file to 'blackhole' bad domains to localhost.

    .DESCRIPTION
    Updates the local hosts file to include the domains in both the local file $UserHostsFile and downloaded entries from $UriList in the script and points all those domains to an IP specified by $IpToUse (127.0.0.1 by default). (0.0.0.0 is the other option, which can be used on machines where a local webserver would respond.)

    The user running the script must have write access to the hosts file. Typically this means a local administrator running elevated.

    .PARAMETER UserHostsFile
    Describes the full path to a user-generated 'base' hosts file. This should have a standard hosts file layout and encoding (ascii).
    This file should include the default localhost entries and may also contain any custom entries your environment requires.

    .PARAMETER IpToUse
    Defines the IP address to use in the final hosts file. 0.0.0.0 may be used for blocking in systems running a local web server.
    127.0.0.1 is the default. The values for entries in the $UserHostsFile file are not changed, whichever value is chosen.

    .NOTES
    I've included several hosts file sources here, discovered just by searching.
    I do not make any claims as to the reliability or utility of any of these lists and I suggest you carry out your own verification.

    Beware of adding too many entries to the list processed by the script as that may result in too many host entries in the final file which slows down lookups, possibly terminally.
    Experiment by gradually increasing the number of sources, to ensure your machine can cope with the resulting hosts file.
    It is possible to render a machine unresponsive by including too many.

    .LINK
    http://pgl.yoyo.org/adservers/serverlist.php?showintro=0;hostformat=hosts
    http://someonewhocares.org/hosts
    http://www.malwaredomainlist.com/hostslist/hosts.txt
    http://sysctl.org/cameleon/hosts.win
    http://winhelp2002.mvps.org/hosts.txt
    https://adaway.org/hosts.txt
    https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts
    https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Dead/hosts
    https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts
    https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts
    https://sourceforge.net/projects/adzhosts/files/HOSTS.txt/download

    Conan Wills - conan@conanw.pro
    Updated 28/02/2020
#>

#region SCRIPT PARAMETERS
#===============================================================================

#Requires -Version 5.1

[CmdletBinding()]

param (

    [ValidateScript({Test-Path $_})]
    [string]
    $UserHostsFile = '.\MyHosts.txt',

    [ValidateSet('127.0.0.1','0.0.0.0')]
    [ipaddress]
    $IpToUse = '127.0.0.1'
)

#endregion

#region SCRIPT VARIABLES
#===============================================================================

#Version
$ScriptName = $MyInvocation.MyCommand.Name
$ScriptVersion = '1.1'

#Make all errors terminating, as we're intending to handle that
$ErrorActionPreference = 'stop'

#Potential sources
$UriList = @(

    'http://pgl.yoyo.org/adservers/serverlist.php?showintro=0;hostformat=hosts',
    'http://someonewhocares.org/hosts/'#,
    'http://www.malwaredomainlist.com/hostslist/hosts.txt'
    'http://sysctl.org/cameleon/hosts.win'
    #'http://winhelp2002.mvps.org/hosts.txt',
    #'https://adaway.org/hosts.txt',
    #'https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts',
    #'https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Dead/hosts',
    #'https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts',
    #'https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts'
)

$HostsFilePath = '{0}\System32\drivers\etc\hosts' -f $env:windir

#endregion

#region FUNCTIONS
#===============================================================================

function End-Script {

    <#
        .SYNOPSIS
        Cleanly ends the script, producing an exit code.
    #>

    param (

        [string]
        $ScriptExitMsg = 'End-Script was called without an exit message being passed.',

        #Exit code default is '1' for 'Unknown' (in my world).
        [int]
        $ScriptExitCode = 1
    )

    if ($ScriptExitCode -eq 0) {

        Write-Verbose -Message "Exiting script with message: $ScriptExitMsg Exit code is $ScriptExitCode."
    }
    else {

        Write-Warning -Message "Exiting script with message: $ScriptExitMsg Exit code is $ScriptExitCode."
    }

    #Produce an exit code
    EXIT $ScriptExitCode
}

#endregion

#region MAIN PROCESS
#===============================================================================

#Clear all errors
$Error.Clear()

#Test for Internet connectivity
Write-Verbose -Message 'Testing Internet connectivity'

if (!(Test-NetConnection).pingsucceeded) {

    End-Script -ScriptExitMsg 'Could not access the Internet.' -ScriptExitCode 2
}

try {

    #Get entries from the user file
    Write-Verbose -Message  'Getting hosts from the user file.'

    $BaseHostDets = Get-Content -Path $UserHostsFile

    #Get the hosts list from each URI
    foreach ($Uri in $UriList) {

        Write-Verbose -Message  ('Getting hosts from {0}.' -f $Uri)

        #Get the response and add it to the list
        $DownloadedDetails += (Invoke-WebRequest -Uri $Uri).RawContent
    }

    #Process the Results
    Write-Verbose -Message 'Processing all the host entries.'

    <#
        Get only the lines with IP addresses, filter out any localhost entries
        (the latter should come from MyHosts.txt), grab the domain and finally
        remove any in-line comments
    #>

    $Domains = $DownloadedDetails.Split("`r`n") | Where-Object {

            ($_ -match '^\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b*') -and ($_ -notmatch 'localhost')

        } | ForEach-Object {($_ -replace '\s+',' ').Split()[1].Split('#')[0]}

    #Sort and dedupe
    $SortedDomains = $Domains | Sort-Object -Unique

    #Add the user's chosen localhost IP address
    $ReIpedHostDets += $SortedDomains[0..$($SortedDomains.Count)] | ForEach-Object {

        "{0}`t{1}" -f $IpToUse, $_
    }

    #Add what we've downloaded to the user data
    $AllHostDets = $BaseHostDets + $ReIpedHostDets

    #Prefix the file contents with a title
    $FinalHostDets = @(

        "#Created by {0} version {1} on {2}`r`n" -f $ScriptName, $ScriptVersion, (Get-Date).ToString()

    ) + $AllHostDets

    #Write the new file
    Write-Verbose -Message 'Writing the new hosts file.'

    Out-File -FilePath $HostsFilePath -Force -Encoding ascii -InputObject $FinalHostDets

    #Clear the DNS cache
    Write-Verbose -Message 'Clearing DNS client cache.'

    Clear-DnsClientCache
}
catch {

    End-Script -ScriptExitMsg $Error[0].exception.message -ScriptExitCode 3
}

#Finish
End-Script -ScriptExitMsg 'Script completed successfully.' -ScriptExitCode 0

#endregion