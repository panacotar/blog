---
layout: post
title: 5 simple steps to a lean Docker image
# published: false
---

Docker is a tool I used extensively, both for developing my personal projects and also during my [Cybersec studies]({{ site.baseurl }}{% post_url 2024-10-28-place-an-ssh-honeypot %}). I'm using a basic VPS where I test stuff. As it's limited, I ran out of storage because of the various images and containers running on it. So I looked for ways to lower the size of a Docker image.

I've put some basic first steps you can do to limit the image's size. I also tried to keep these steps language agnostic, but I'll use a Node app to exemplify the concepts.

The built command I used:
```
docker build --no-cache -t node-api:v0 .
```
After each step, I'm placing *the stats with the image size and times to build*. Notice that the time it takes to build may vary based on you system, network connection, time of day and how depressed your machine is.

### Initial built
I'm starting from this Dockerfile:
```dockerfile
FROM node:latest

WORKDIR /usr/src//node-api

COPY package*.json ./
RUN npm install --verbose

COPY . .

RUN npm run build

CMD ["npm", "start"]
```
```
Size:
node-api     v0        1.43GB
Time
Building 17.2s (12/12)
```

## Steps
### 1. Ignore files

With `.dockerignore`.
This speeds up the build and also prevents sensitive files from showing up in the final image.

```
Size:
node-api     v1        1.37GB
Time:
Building 15.3s (12/12)
```

### 2. Base Image

For each framework there are different image tags to use. Go for the leaner images.

For node, use `alpine` instead of the `latest`.
It is sought after for its minimal size and its smaller vulnerability count. This will suffice for smaller projects.   
Alpine is not officially supported by the Node team. You can find a list of unofficial-builds for Node [here](https://github.com/nodejs/unofficial-builds/). 
Alpine project uses [musl](https://www.musl-libc.org/) for the C standard library implementation, whereas Debian’s Node.js tags (for instance `bullseye` or `slim`) rely on the `glibc` implementation. 

I downloaded some common Node image tags to compare them:
```
REPOSITORY               TAG               SIZE
node                     latest            1.13GB
node                     bookworm          1.13GB
node                     bullseye          1.03GB
node                     slim              230MB
node                     alpine            165MB
```

Additionally, you can use a [distroless](https://github.com/GoogleContainerTools/distroless) base image. They will only contain you app with its runtime dependencies. The package managers, shells, and other are skipped. Using them dramatically decreases the image size and its attack surface.     
This approach is more advanced and out of scope of this article.

```
Size:
node-api     v2        408MB
Time:
Building 17.1s (12/12)
```

### 3. Multi-stage build

This allows you to separate the build and runtime envs. It allows you to only include the essential files to the final image.

A Dockerfile accepts multiple `FROM` statements. Each `FROM` instruction begins a new stage of the build (and can use a different base image). And each stage can be named with `AS` statement.

Here is my updated Dockerfile:

```dockerfile
# Build stage
FROM node:alpine AS build
WORKDIR /usr/src/node-api
COPY package*.json ./
RUN npm install --verbose
COPY . .
RUN npm run build

# Prod stage
FROM node:alpine
WORKDIR /usr/src/node-api
COPY --from=build /usr/src/node-api/build ./build
COPY package*.json ./
RUN npm install --verbose

CMD ["npm", "start"]
```

You can stop the build at a specific stage using the `--target` flag:
```sh
docker build --target build -t node-api:v3 .
```

```
Size:
node-api     v3        234MB
Time:
Building 8.6s (15/15)
```

### 4. Skip dev dependencies
Besides multi-stage, you can further skip dev dependencies during install. 
For Node, always use `ci` (clean install) instead of `i`. This command is faster and it installs the exact versions based on `package-lock.json`. It throws and error and exits for any version mismatch. It also accepts an `--omit` flag to skip some dependencies.
```
RUN npm ci --omit=dev
```

```
Size:
node-api     v4        172MB
Time:
Building 6.3s (16/16)
```

### 5. Merge layers and cleanup between them

We can clean the temporary files that are created after a `RUN` instruction. It is common for package managers to install additional components and keep a local cache. We can save space by:
- Instructing the package manager to install mininum dependencies
- Remove the cache after installation, or instruct the packet manager to disable the cache altogether

For example, after installing Node dependencies, it will create meta files which takes space in the image. We can use these commands to remove them:
```
RUN npm cache clean --force
RUN rm -rf /tmp/* /var/cache/apk/*
```

For **Debian/Ubuntu** use `--no-install-recomends`. It keeps the cache at `/var/lib/apt/lists`:
```
RUN apt-get install -y --no-install-recomends
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*
```
<br />
For **Python (pip)**, we can specify the same with `--no-cache-dir`.

#### Keep layers number to a minimum

Each Dockerfile instruction adds a new layer to the image. Docker uses an overlay-type file system. The layers are accumulative in nature, each layer adds on top of existing ones.    
In the above examples, even if we place the command to delete the files, **they are not deleted and the image size will not decrease**, so the disk space will not get returned.    
We can merge the `RUN` commands to avoid this.
If we do the cleanup before the `RUN` command is completed, the files we want deleted will not end up in the image:
```
RUN npm ci --omit=dev && \
    npm cache clean --force && \
    rm -rf /tmp/* /var/cache/apk/*
```

```
Size:
node-api     v5        170MB
Time:
Building 6.7s (16/16)
```

## Summary

![Final Docker images]({{ site.baseurl }}/assets/images/posts/docker-imgs-size.png)
And my final Dockerfile:

```dockerfile
# Build stage
FROM node:alpine AS build
WORKDIR /usr/src/node-api
COPY package*.json ./
RUN npm ci && \
    npm cache clean --force && \
    rm -rf /tmp/* /var/cache/apk/*i
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Prod stage
FROM node:alpine
WORKDIR /usr/src/node-api
COPY --from=build /usr/src/node-api/build ./build
COPY package*.json ./
RUN npm ci --omit=dev && \
    npm cache clean --force && \
    rm -rf /tmp/* /var/cache/apk/*


CMD ["npm", "start"]
```

## Measuring image sizes
```
docker images node-api
```
Another tool to use is [dive](https://github.com/wagoodman/dive):
```
dive node-api
```
It offers TUI where you can explore a docker image in an interactive way. You can see each layer in details, analyze wasted space and identify where you can further optimize.
It breaks down each layer with its files are added and how much space they consume.

Alternatively, I found out you can just create the image without running it. Then, you can export it's contents and inspect them manually:

```
docker create node-api:v5
docker container list -a
docker export <CONTAINER_NAME> > node-api.tar
```
Or:
```
docker export $(docker create node-api:v5) > node-api.tar
```


