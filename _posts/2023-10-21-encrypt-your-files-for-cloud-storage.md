---
layout: post
---

A remedy for trust issues with cloud providers. 

I love you, cloud providers. You said you encrypt my data. But can fully trust you don't save a copy of the encryption key? Maybe you get curious to poke around my stuff.

"In-house" encryption is a good way to achieve data confidentiality and peace of mind. 

One aid for file encryption is the Gnu Privacy Guard (GnuPG). While this is a feature rich tool, its *symmetric key encryption* functionality should be enough here.

**Note**: The `gpg` cli tool might not be installed by default on macOS, you can install it with `brew install gnupg`. Check `gpg --version` afterwards.

> Although this provides effective data confidentiality, it may fall short in ensuring data integrity. Someone with the right authorization can still directly modify/delete the encrypted file's content.
>
> Because the files are encrypted, it would be highly unlikely for someone to know what are they modifying.

## Encrypting a file

If you want to encrypt a `confidential.txt` file. You can use the following command:

{% highlight shell %}
gpg -c --no-symkey-cache --cipher-algo AES256 confidential.txt
{% endhighlight %}

The flags meaning:
- `-c` - encrypt with a symmetric cipher using a passphrase
- `--no-symkey-cache` - prevent caching the passphrase
- `--cipher-algo` - specify the symmetric cipher used (default is AES-128)

After you choose a (hopefully strong) password, your encrypted file (`confidential.txt.gpg`) will be created, not affecting your original file. You can `cat` this new file, which will contain meaningless characters.

To decrypt this file, you only need to run the `gpg` command passing the encrypted file as argument. Here you'll be prompted for your password:

{% highlight shell %}
gpg confidential.txt.gpg

gpg: WARNING: no command supplied.  Trying to guess what you mean ...
gpg: AES256.CFB encrypted data
gpg: encrypted with 1 passphrase
{% endhighlight %}

## Encrypting a directory
If running the same command and passing a directory, you will get an error: `read error: Is a directory`. This happens because `gpg` expects a single file.   
One workaround is to archive the directory first, which will merge all the content into a single file. Then, you can proceed with the encryption.

Example, encrypting a `test` directory with multiple files:

{% highlight shell %}
# 1. Archive the directory:
tar -cf test.tar.gz test/

# 2. And now you can encrypt the `tar` file:
gpg -c --no-symkey-cache --cipher-algo AES256 test.tar.gz
{% endhighlight %}
This will create `test.tar.gz.gpg`.

In order to get the data back, we'll reverse the process:

{% highlight shell %}
# 1. Decrypt the file
gpg test.tar.gz.gpg

# 2. Extract the tar archive
tar -xf test.tar.gz
{% endhighlight %}


This will recreate the initial test directory
{% highlight shell %}
tree test
test   
├── dog.txt   
└── dogo.jpg   
{% endhighlight %}


## Resources
- youtube.com/@MentalOutlaw
- www.gnupg.org
