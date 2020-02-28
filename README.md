# Update-Hosts.ps1

Updates the local hosts file to include the domains in both the local file $UserHostsFile and downloaded entries from $UriList in the script and points all those domains to an IP specified by $IpToUse (127.0.0.1 by default).
0.0.0.0 is the other option, which can be used on machines where a local webserver would respond.

The user running the script must have write access to the hosts file. Typically this means a local administrator running elevated.

## Included sources

I've included several hosts file sources here, discovered just by searching. I do not make any claims as to the reliability or utility of any of these lists. I suggest you carry out your own verification.

Beware of adding too many entries to this list as that may result in too many host entries in the final file which slows down lookups, possibly terminally. Experiment by gradually increasing the number of sources, to ensure your machine can cope with the resulting hosts file. It is possible to render a machine unresponsive by including too many.

<http://pgl.yoyo.org/adservers/serverlist.php?showintro=0;hostformat=hosts>
<http://someonewhocares.org/hosts>
<http://www.malwaredomainlist.com/hostslist/hosts.txt>
<http://sysctl.org/cameleon/hosts.win>
<http://winhelp2002.mvps.org/hosts.txt>
<https://adaway.org/hosts.txt>
<https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts>
<https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Dead/hosts>
<https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts>
<https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts>
<https://sourceforge.net/projects/adzhosts/files/HOSTS.txt/download>
