# How to setup

First things first, you'll need download the following apps for get everything working:

- [Acrylic DNS Proxy](https://mayakron.altervista.org/wikibase/show.php?id=AcrylicHome)
- [WinSW](https://github.com/kohsuke/winsw/releases)
- [Nginx Windows](http://nginx.org/en/docs/windows.html)
- [PHP](http://php.net/downloads.php)
- [Database Server](https://dev.mysql.com/downloads/)

See the download links above.

## Acrylic Proxy DNS

On Windows, DNS configuration is boring. But what we just want today is to redirect every *.localhost and *.docker domain names to 127.0.0.1, because let’s make it simple, it’s stupid enough to set up EVERY domain in the system’s host file at C:\Windows\System32\drivers\etc\hosts.

So, open the AcrylicConfiguration.ini file, change the PrimaryServerAddress config to not use Google’s DNS. Instead, prefer using OpenDNS ones. Not GAFA, you know (but still Cisco, though).

You’re also free to change all SecondaryServerAddress, TernaryServerAddress, etc., up to the amount of DNS servers you like.

Close this file, and open another one: AcrylicHosts.txt. There, it’s like a Windows hosts file, but on steroids.

Add one single rule:

After you download Acrylic Proxy DNS you need to configure than to redirect every call made to "ex: *.localhost *.docker to 127.0.0.1" for this open **Acrylic UI** > Files > Open Acrylic Hosts and put this line at the end of the config file:

```javascript
127.0.0.1 *.localhost *.docker
```
Save and close the file.

## Nginx Windows Install



## PHP Windows Install



## WinSW

Then you'll need WinSW to create services and start them with Windows, you'll use this to create services for nginx and php.

The first step is to download it from the above URL and save it in the same folder as Nginx as **nginxsvc.exe**.

Once configured, you will need to create a service file, please be sure to create a file named **nginxsvc.xml** and with the following content:

```xml
<service>
  <id>nginx</id>
  <name>nginx</name>
  <description>nginx</description>
  <executable>c:/nginx/nginx.exe</executable>
  <logpath>c:/nginx</logpath>
  <logmode>roll</logmode>
  <depend></depend>
  <startargument>-p</startargument>
  <startargument>c:\nginx\</startargument>
  <stopargument>-p</stopargument>
  <stopargument>c:\nginx\</stopargument>
  <stopargument>-s</stopargument>
  <stopargument>stop</stopargument>
</service>
```
You are now ready to install the Windows service, you can proceed to run the following command:

```
C:/nginx/nginxsvc.exe install
```
Let's do the same with PHP, in the folder where you extracted PHP find the file **php-cgi.exe**, copy WinSW and rename it to **phpsvc.exe**.

Once configured, you will need to create a service file, just like we did with nginx, make sure to create a file named phpsvc.xml and with the following content:

```xml
<service>
  <id>php</id>
  <name>php</name>
  <description>php</description>
  <workingdirectory>C:/Program Files (x86)/PHP/v7.2</workingdirectory>
  <executable>C:/Program Files (x86)/PHP/v7.2/php-cgi.exe</executable>
  <logpath>c:/nginx</logpath>
  <logmode>roll</logmode>
  <depend></depend>
  <startargument>-b</startargument>
  <startargument>127.0.0.1:9123</startargument>
  <stopexecutable>taskkill</stopexecutable>
  <stopargument>/IM</stopargument>
  <stopargument>php-cgi.exe</stopargument>
  <stopargument>/F</stopargument>
</service>
```
After that, you can continue running the following command:

```
cd C:\Program Files (x86)\PHP\v7.2

phpsvc.exe install
```

![alt text]()

## Database



