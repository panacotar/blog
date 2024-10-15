---
layout: post
published: false
title: Linux VPS hardening (a checklist) 
---

There are two main threat actors for your VPS: bots and real people (manually testing access).   

The IP address of your VPS is public knowledge, there are thousands of web crawlers looking for new domains and testing access to your server. After I created my first VPS, within the first 30 minutes, it was already pen-tested by bots (the `/var/log/auth.log` file showed plenty of failed login attempts).

There are lots of options for securing a VPS, here are some suggestions to start with.

### 1. Update the packages - apt update && apt upgrade
```shell
apt update -y && apt full-upgrade -y && apt autoremove -y && apt autoclean -y
```

### 2. Create a new user on the system
Avoid using the `root` user and create a regular user. When naming the user, avoid common names (like admin/administrator) and maybe avoid using your first name. 
```
[root@VPS ~]# adduser dogo
# Add the regular user to the sudo group
[root@VPS ~]# usermod -aG sudo dogo
[root@VPS ~]# su - dogo

[dogo@VPS ~]$
```
Notice the prompt changing from `#` (root) to `$` (regular user).   
The regular user `dogo` still has admin privileges via the `sudo` command.

### 3. Use key-based SSH authentication
The VPS most likely includes an SSH account. This will probably have a password, but using a key-based authentication is considered more secure.    
Again, the cloud provider might already include this type of authentication for your SSH account. But if not, you need to generate the SSH keys (`ssh-keygen`) and transfer the **public key** (ending in *.pub*) to the VPS.    

- login with password is active - use `ssh-copy-id`
- login with password is disabled - manually copy the public key

If login with password is active, you can run the command on **local machine**:
```shell
ssh-copy-id -i PATH/TO/PUBLIC_KEY USERNAME@REMOTE_HOST
```

If login with password is disabled, you can manually copy the public key. On your **local machine**.
```shell
# The name path and key name might differ
cat ~/.ssh/vps_id_rsa.pub
# Copy the public key string
```
On the remote VPS session, if you're logged in as the regular user 
```shell
# Create the .ssh directory for the dogo user
mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys

# Important to wrap the string in quotes
echo 'PUBLIC_KEY_STRING_YOU_COPIED' >> ~/.ssh/authorized_keys
cat ~/.ssh/authorized_keys
ssh-ed25519 [...HASH] [...KEY_NAME]
```
On another terminal session, test connecting with SSH from your **local machine**:   
`ssh -i ~/.ssh/vps_id_rsa.pub USERNAME@REMOTE_HOST`

### 4. SSH security configs
- Disable SSH password authentication 
- Disable root login 
- Change the default SSH listening port

Config the SSH to disable access with password and disable root login.   
Also here, change the default SSH listening port (22) to some other port of your choosing (ex: 12345). 
This is more a *security through obscurity* step, and it's intended for bots. Real attackers are still able to find your new SSH port rather quickly via port scanning. 

**Note:** I recommend choosing a port number between 1024 and 65535, as the others are usually reserved for various system services.

Edit the `/etc/ssh/sshd_config` file and change the following rules 
```shell
# /etc/ssh/sshd_config
Port 12345
[...]
PermitRootLogin no
[...]
PasswordAuthentication no
```
Make sure the lines are not commented (remove the leading `#` if needed).   

Restart the SSH service: `sudo systemctl restart sshd.service`   
**Note:** on some systems, this is done with the `sudo service ssh restart`   
After changing the port number, you might need to run these commands as well for the changes to work `sudo systemctl daemon-reload && sudo systemctl restart ssh.socket`.

Test the connection to the new port `ssh -i ~/.ssh/vps_id_rsa.pub USERNAME@REMOTE_HOST -p 12345`.

> Important: make sure your connection works before proceeding with firewall setup.

### 5. Set up a firewall
Using the `ufw` util which is built on top of `iptables`, and comes installed on most Linux distros. 

Before enabling the firewall, allow incoming SSH connections to the port you specified above (ex: 12345).
```shell
sudo ufw allow 12345/tcp
```
If the server should accept the HTTP/HTTPS connections, you can repeat this command for the ports 80 and 443.   
Enable the firewall `sudo ufw enable` and check its status:
```shell
sudo ufw status
Status: active

To                         Action      From
--                         ------      ----
12345/tcp                  ALLOW       Anywhere                  
12345/tcp (v6)             ALLOW       Anywhere (v6)
```
<!-- Restart ufw `sudo ufw disable && sudo ufw enable`. -->

### 6. Disable open ports you don't use
List all the currently open ports with `netstat` or `ss`.
By default, after enabling `ufw`, it will block all incoming traffic. Check the `ufw status` if there are any rules you ought to block.

## Additional recommendations
### Set up 2FA authentication
As you already enabled key-based authentication, brute-force attacks are now less likely to be successful. But as the SSH key might still get leaked, setting up a second auth factor is recommended.

2FA can be enabled with the Google's PAM:
```
sudo apt-get install libpam-google-authenticator
```
We use this to generate TOTP key for the current user (the key is not system-wide).

Run the app and reply `y` when prompted:
```shell
google-authenticator
Do you want authentication tokens to be time-based (y/n) y
```
This generates a QR code, which you can read on your auth app.

**Note:** make sure to save the secret key, verification and recovery codes. 

Go with `y` on the next question and answering the following questions is based on your needs.
```shell
Do you want me to update your "~/.google_authenticator" file (y/n) y
```

Now, configure the SSH to use 2FA. First, backup the file: `sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.bak`. Then, edit the file, adding the configuration at the end of the file:
```shell
# /etc/pam.d/sshd
[...]
# Standard Un*x password updating.
@include common-password
auth required pam_google_authenticator.so nullok
auth required pam_permit.so
```
After, config the SSH to support this auth type. Backup the file `sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak`
```shell
# /etc/ssh/sshd_config
[...]
ChallengeResponseAuthentication yes
[...]
KBDInteractiveAuthentication yes
[...]
AuthenticationMethods publickey,password publickey,keyboard-interactive
```
Restart the SSH service: `sudo systemctl restart sshd.service`

### Block SSH bots from brute-forcing
With the `fail2ban` tool. It scans files like `/var/log/auth.log` and bans IP addresses with too many failed login attempts.

```shell
sudo apt install fail2ban
```
Check if the fail2ban service is running: `sudo systemctl status fail2ban.service`.   
The files are under `/etc/fail2ban/*`, duplicate the config file as we should not edit it directly.
```shell
sudo cp jail.conf jail.local
```
Add the rules under `[sshd]` in the `jail.local` file. Some suggested rules:
```shell
# /etc/fail2ban/jail.local
enabled = true
# (in seconds or time abbreviation format)
bantime = 1d
```
Other configs you can change are `maxretry`, `findtime` (the windows of time for `maxretry`).

