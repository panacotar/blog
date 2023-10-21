---
layout: post
published: false
---

<!--
  TODO:
  complete the article
  explain what the gpg flags are for
  # -c
  # --no-symkey-cache
  # --cipher algo AES256
-->
You can encrypt files and folders before uploading them in the cloud.

I found out and about the GnuPG command-line tool[^1] which allowed me to encrypt my files. This is a feature rich tool, but here, I'll just use the symmetric key encryption.

## Encrypting a file

To encrypt files, you can start by creating a dummy file, `confidential.txt`. After writing the content, you can encrypt it with the following command:

{% highlight shell %}
gpg -c --no-symkey-cache --cipher-algo AES256 confidential.txt
{% endhighlight %}


After, you'll be asked for a password.
This will create a new file `confidential.txt.gpg` which is the encrypted file. You can `cat` this file and you'll get random text.

To decrypt this file, you run only the `gpg` command with the encrypted file and when prompted, write your password:

{% highlight shell %}
gpg confidential.txt.gpg

gpg: WARNING: no command supplied.  Trying to guess what you mean ...
gpg: AES256.CFB encrypted data
gpg: encrypted with 1 passphrase
{% endhighlight %}

## Encrypting a directory
If running the same command and passing a directory, you will get an error: `read error: Is a directory`. This happens because `gpg` expects a single file.
One solution is to archive the directory first, which will merge all the content into a single file. Only after, you can encrypt that file.

Example, having a `test` directory with multiple file.

Archive the directory:
{% highlight shell %}
tar -cf test.tar.gz test/
{% endhighlight %}

And now you can encrypt the `tar` file:
{% highlight shell %}
gpg -c --no-symkey-cache --cipher-algo AES256 test.tar.gz
{% endhighlight %}
This will create `test.tar.gz.gpg`.
In order to get the data back, we'll reverse the process:

{% highlight shell %}
gpg test.tar.gz.gpg
# Write the password

tar -xf test.tar.gz

# Which will recreate the initial test directory
tree test
test
├── dog.txt
└── dogo.jpg
{% endhighlight %}


> Encrypting the files in this symmetrical way works well for data privacy. But even though the file is encrypted, someone with access to the file is able to modify its content. Which will have negative effects on data integrity. It would be highly unlikely for someone to know what are they modifying.


## Resources
- youtube.com/@MentalOutlaw

[^1]: The `gpg` cli tool might not be installed by default on macOS, you can install it with `brew install gnupg` and after, check if successfully installed `gpg --version`