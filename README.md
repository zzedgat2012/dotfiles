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

```
127.0.0.1 *.localhost *.docker
```
Save and close the file.

### Setup Acrylic as service

Acrylic DNS proxy comes with lots of .bat files that are just aliases to the AcrylicController.exe binary. It’s a nice entry point to Acrylic’s config, even though it’s not 100% documented, we have the basic ideas on how everything works.

Run the InstallAcrylicService.bat script, to install Acrylic as a Windows service.

Note: It may not show or output anything. In this case, start a cmd terminal, and execute the script directly in the command line. And if it still doesn’t work, run it as administrator.

The service should be running. To check this, we can run this command:
```
$ sc query AcrylicServiceController

SERVICE_NAME: AcrylicServiceController
        TYPE               : 10  WIN32_OWN_PROCESS
        STATE              : 4  RUNNING                    # <------- Means it's working! \o/
                                (STOPPABLE, NOT_PAUSABLE, ACCEPTS_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x0
```        
 **To Setup Windows to point to Acrylic before using other DNS resolution, see this article:**

 [Setup a dnsmasq equivalent on Windows (with Acrylic)](http://www.orbitale.io/2017/12/05/setup-a-dnsmasq-equivalent-on-windows-with-acrylic.html)


## Nginx Windows Install

Nginx comes pre-compiled for Windows which makes it extremely easy to get started. If it did not come pre-compiled, you would need to have a compiler installed on your computer with a full environment. Fortunately, this is not the case. At the time of this article, the latest Nginx version is 1.5.4 so we’ll download it from here:

Download Nginx Windows

Once you’ve downloaded Nginx for Windows, you can extract it to your folder of choice, we recommend that you install it somewhere easily accessible such as C:nginx.

### Verify Nginx Windows Installation

In order to make sure that the service is working with no problems, we recommend that you start a command prompt window and type the following, make sure that you update the path if you’ve installed it in another folder.
```
C:\nginx\nginx.exe
```
You should be able to go to http://localhost/ and you should see the “Welcome to Nginx” default page. If you see that page, then we can be sure that Nginx has been installed properly. We will now shut it down and install it as a service, to stop it, you can use this command.
```
C:\nginx\nginx.exe -s stop
```
Now, if you were using Nginx as a simple development server, you can use these simple commands to start and stop the server as you need. However, if you will be using it as a production server, you would want to install it as a Windows service, which is what we’re covering on this setup.


## PHP Windows Install

Installing PHP on your development PC allows you to safely create and test a web application without affecting the data or systems on your live website.

### Step 1: Download the files
Download the latest PHP 7 ZIP package from [www.php.net/downloads.php](www.php.net/downloads.php)

As always, virus scan the file and check its MD5 checksum using a tool such as fsum.

### Step 2: Extract the files
We will install the PHP files to C:\Program Files (x86)\PHP\v7.2, so create that folder and extract the contents of the ZIP file into it.

PHP can be installed anywhere on your system, but you will need to change the paths referenced in the following steps.

### Step 3: Configure php.ini
Duplicate C:\Program Files (x86)\PHP\v7.2\php.ini-development and rename it to php.ini. There are several lines you will need to change in a text editor (use search to find the current setting). Where applicable, you will need to remove the leading semicolon to uncomment these setting.

Define the extension directory:
```
extension_dir = "C:\Program Files (x86)\PHP\v7.2\ext"
```
Enable extensions. This will depend on the libraries you want to use, but the following extensions should be suitable for the majority of applications:
```
extension=curl
extension=gd2
extension=mbstring
extension=mysql
extension=pdo_mysql
extension=xmlrpc
```
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
cd C:\nginx

nginxsvc.exe install
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

## Database

The simplest and recommended method is to download MySQL Installer (for Windows) and let it install and configure all of the MySQL products on your system. Here is how:

**Note: In this setup we use MySQL Instalation as Server Machine**

1. Download MySQL Installer from http://dev.mysql.com/downloads/installer/ and execute it.
2. Choose the appropriate Setup Type for your system. Typically you will choose Developer Default to install MySQL server and other MySQL tools related to MySQL development, helpful tools like MySQL Workbench. Or, choose the Custom setup type to manually select your desired MySQL products.
3. Complete the installation process by following the instructions. This will install several MySQL products and start the MySQL server.

MySQL is now installed. If you configured MySQL as a service, then Windows will automatically start MySQL server every time you restart your system.

This process also installs the MySQL Installer application on your system, and later you can use MySQL Installer to upgrade or reconfigure your MySQL products.

For more info see: [Installing MySQL on Microsoft Windows](https://dev.mysql.com/doc/refman/8.0/en/windows-installation.html)

References:

[Setup a dnsmasq equivalent on Windows (with Acrylic)](http://www.orbitale.io/2017/12/05/setup-a-dnsmasq-equivalent-on-windows-with-acrylic.html)

[Nginx Windows: How to Install](https://vexxhost.com/resources/tutorials/nginx-windows-how-to-install/)

[How to Install PHP on Windows](https://www.sitepoint.com/how-to-install-php-on-windows/)

[Installing MySQL on Microsoft Windows](https://dev.mysql.com/doc/refman/8.0/en/windows-installation.html)

[A Lot of Vin instructions in the process](http://vin.8sistemas.com/)
