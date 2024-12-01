---
layout: post
title: Place an SSH honeypot
published: false
---

After deploying my VPS and taking [steps to secure it]({{ site.baseurl }}{% post_url 2024-06-29-linux-vps-hardening-a-checklist %}), I had the original SSH port (22) inactive. But it kept me curious about the default SSH activity going on there. How much brute forcing is happening on a publicly exposed server? I started experimenting with honeypots to find out more.

But first, let's get the definition out of the way. A honeypot in Cybersecurity is a decoy resource which appears as a legitimate target. It is often deployed to distract attackers from the important resources on the network, and/or profiling potential threats.

## Choosing a honeypot
There are plenty of honeypots available, each for different purpose, deployment context, OS, network systems.   
For my needs, I wanted an SSH honeypot, low-interaction and not too resource intensive, relatively easy to set up and understand. 

After tinkering with some of them, I'm describing here the **Basic SSH Honeypot** created by [Simon Bell](https://github.com/sjbell/basic_ssh_honeypot).    
I forked and updated it to suit my needs, and you can find it [here](https://github.com/panacotar/basic_ssh_honeypot).

## Prerequisite
> **Important**: Using this honeypot setup is only meant to be tested on a vanilla installation of Ubuntu.

I highly recommend having a simple VPS dedicated to testing honeypots; unless you know what you're doing, don't play with this on your production server. Even if tiny, there's a chance honeypots have (undiscovered) vulnerabilities. Allowing attackers to "overpass" and get into the server.   
Never run a honeypot with sudo privilege or from a sudoers user, in the case an attacker manages to "overpass" the honeypot, it will have sudo access to the server.

- Ubuntu [VERSION]
- Docker installed
- git
- python3 [??] 
- 

## Setup Basic SSH honeypot
First, set a firewall rule to redirect SSH requests from port 22 to 2222 (a non-privileged port).
```
sudo iptables -t nat -A PREROUTING -p tcp --dport 22 -j REDIRECT --to-port 2222
```
From now, you should not use the sudo anymore [??]

Clone the repository from above: 
```
git clone https://github.com/panacotar/basic_ssh_honeypot.git & cd basic_ssh_honeypot
```

Create a server key:
```sh
ssh-keygen -t rsa -f server.key 
# When asking for a password, just skip it

mv server.key.pub server.pub
```

Build the Docker image:
```
docker build --no-cache -t basic_sshpot .
```
Then run it:
```
docker run -d -v ${PWD}:/usr/src/app -p 2222:2222 basic_sshpot
```
Some parameters here:
- `-d` (`--detach`) - runs the container in the background. It prints the new container's ID and you'll get the prompt back.
- `-v` (`--volume`) - creates a bind mount, creating the `ssh_honeypot.log` file in the current directory.

The honeypot now listens to incoming SSH connections and logs them to the log file (`ssh_honeypot.log`).   
Run `sudo netstat -tulpn` to check the open ports, you should see the honeypot running:
```
[...]
tcp6       0      0 :::2222                 :::*                    LISTEN      21120/docker-proxy  
```

## Stopping the dockerize honeypot
```
docker stop $(docker ps -a -q  --filter ancestor=basic_sshpot)
```

## Other honeypots
- [Cowrie](https://github.com/cowrie/cowrie) - a great alternative. Very simple to set up and use. They also provide some good documentation.
- [OpenCanary](https://github.com/thinkst/opencanary) - Modular and decentralised honeypot daemon that runs several canary versions of services that alerts when a service is (ab)used.
- [T-Pot](https://github.com/telekom-security/tpotce) - All in one honeypot appliance (can be resource intensive)
- [ssh_honeypot](https://github.com/droberson/ssh-honeypot) - a light alternative, it logs the IP address, username, and password