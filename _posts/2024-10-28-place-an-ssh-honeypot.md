---
layout: post
title: Place an SSH honeypot
tags: sec vps honeypot
---

After deploying my VPS and taking [steps to secure it]({{ site.baseurl }}{% post_url 2024-06-29-linux-vps-hardening-a-checklist %}), I had the original SSH port (22) inactive. But it kept me curious about the default SSH activity going on there. How much brute forcing is happening on a publicly exposed server? I started experimenting with honeypots to find out more.

But first, let's get the definition out of the way. In Cybersecurity, a honeypot is a decoy resource designed to look as a legitimate target. It is often deployed to distract attackers from the important resources on the network, and/or profiling potential threats.

## Choosing a honeypot
There are plenty of honeypots available, each a for different purpose, deployment context, OS, and network systems.   
For my needs, I wanted a low-interaction SSH honeypot, not too resource-intensive, compatible with Linux, and relatively easy to set up and understand. 

After tinkering with some of them, I'm describing here the **Basic SSH Honeypot** created by [Simon Bell](https://github.com/sjbell).    
I've forked and updated it to suit my needs, and you can find it [here](https://github.com/panacotar/basic_ssh_honeypot).

## Prerequisites
> **Important**: Using this honeypot setup is only meant to be tested on a vanilla installation of Ubuntu.

I highly recommend having a simple VPS exclusive for testing honeypots; unless you know what you're doing, don't play with this on your production server. Although tiny, there's a chance honeypots have (undiscovered) vulnerabilities. Allowing attackers to escape the honeypot, so to say, and get into the server.   
Also, a good idea is to create a dedicated, non-root user for running the honeypot.   
Never run a honeypot with sudo privilege, in the case an attacker manages to break out of the honeypot, it will have sudo access to the server.

- Ubuntu 24.04.1 or similar
- Docker installed (can be installed following these [instructions](https://docs.docker.com/engine/install/ubuntu/))
- A non-root user handling the docker container. Follow the steps [here](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user)
- git
- ufw
- Optional, but recommended, running the docker in [rootless mode](https://docs.docker.com/engine/security/rootless/)

## Set up the SSH honeypot
First, set a firewall rule to redirect SSH requests from port 22 to 2222 (a non-privileged port).
```shell
sudo iptables -t nat -A PREROUTING -p tcp --dport 22 -j REDIRECT --to-port 2222

# And, if your firewall is enabled, allow connections the port 2222
sudo ufw allow 2222/tcp
```
From now, you should not use the `sudo` command anymore.   
Clone the repository from above: 
```
git clone https://github.com/panacotar/basic_ssh_honeypot.git && cd basic_ssh_honeypot
```

Create the RSA key pair:
```sh
ssh-keygen -t rsa -f server.key 
# When asking for a password, just skip it (press enter)

# Rename the public key
mv server.key.pub server.pub
```

Build the Docker image (provided you added your user to the `docker` group as described in the prerequisites):
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
Run `ss -tulpn` to check the open ports, you should see the honeypot running:
```
Netid         State          Recv-Q          Send-Q                   Local Address:Port                    Peer Address:Port         Process
[...]
tcp           LISTEN         0               4096                              [::]:2222                            [::]:*  
```

After running the honeypot for a while, you will find its logs in the current directory, `ssh_honeypot.log`. You can also view them live with the command:
```
tail -f ssh_honeypot.log
```

### Stopping the dockerized honeypot
```
docker stop $(docker ps -a -q  --filter ancestor=basic_sshpot)
```

## Other honeypots
- [Cowrie](https://github.com/cowrie/cowrie) - a great alternative that is very simple to set up and use. They also provide helpful documentation.
- [OpenCanary](https://github.com/thinkst/opencanary) - modular and decentralized honeypot daemon that runs several canary versions of services that alert when a service is (ab)used.
- [T-Pot](https://github.com/telekom-security/tpotce) - all-in-one honeypot appliance (can be resource intensive)
- [ssh_honeypot](https://github.com/droberson/ssh-honeypot) - a light alternative, it logs the IP address, username, and password