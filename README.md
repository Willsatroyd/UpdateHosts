# UpdateHosts
Generates a new hosts file to 'blackhole' bad domains to localhost (IPv4 only).

Updates the local hosts file to include the domains in both the local file 'MyHosts.txt' and downloaded entries from a Uri list contained in the script and points all those domains to either 127.0.0.1 (by default) or 0.0.0.0, which can be used on machines where a local webserver would respond.
    
The user running the script must have write access to the hosts file. Typically this means a local administrator running elevated.
