---
layout: post
tags: sec linux
---

A remedy for trust issues with cloud providers. 

You can never fully trust what cloud providers will do with your files, at the end of the day, your data sits on their "computers". They promise to encrypt your data, but can you be sure they don't save a copy of the encryption key?

"In-house" encryption will bring more peace of mind and ensure data confidentiality.

One aid for file encryption is the Gnu Privacy Guard (GnuPG). While this is a feature-rich tool, its *symmetric key encryption* functionality should be enough here.

**Note**: The `gpg` CLI tool might not be installed by default on macOS, you can install it with `brew install gnupg`. Check `gpg --version` afterwards.

> Although this provides effective data confidentiality, it may fall short of ensuring data integrity. Someone with the right authorization can still directly modify/delete the encrypted file's content.
>
> As the files are encrypted, it would be highly unlikely for someone to know what they are modifying.

## Encrypting a file

If you want to encrypt a `confidential.txt` file. You can use the following command:

```shell
gpg -c --no-symkey-cache --cipher-algo AES256 confidential.txt
```

The flags meaning:
- `-c` - encrypt with a symmetric cipher, using a passphrase
- `--no-symkey-cache` - prevent caching the passphrase
- `--cipher-algo` - specify the symmetric cipher used (default is AES-128)

After you choose a (hopefully strong) password, your encrypted file (`confidential.txt.gpg`) will be created, not affecting your original file. You can `cat` this new file, which will just contain the random sequence of bytes shown as characters.

To decrypt this file, you only need to run the `gpg` command passing the encrypted file as argument. Here, you'll be prompted for your password:

```shell
gpg confidential.txt.gpg

gpg: WARNING: no command supplied.  Trying to guess what you mean ...
gpg: AES256.CFB encrypted data
gpg: encrypted with 1 passphrase
```

## Encrypting a directory
If trying to encrypt a directory with the same steps, you will get an error: `read error: Is a directory`. This happens because `gpg` expects a single file.   
One workaround is to archive the directory first, which will merge all the content into a single file. Then, you can proceed with the encryption.

Example, encrypting a `test` directory with multiple files:

```shell
# 1. Archive the directory:
tar -cf test.tar.gz test/

# 2. And now you can encrypt the `tar` file:
gpg -c --no-symkey-cache --cipher-algo AES256 test.tar.gz
```
This will create `test.tar.gz.gpg`.

In order to get the data back, we'll reverse the process:

```shell
# 1. Decrypt the file
gpg test.tar.gz.gpg

# 2. Extract the tar archive
tar -xf test.tar.gz
```


This will recreate the initial test directory
```shell
tree test
test   
├── dog.txt   
└── dogo.jpg   
```


## Resources
- youtube.com/@MentalOutlaw
- www.gnupg.org
