---
layout: post
title: DNS lookup from scratch
# date: 2025-02-26 12:44 -0300
---

My findings after implementing the DNS query. This system is tucked away in the network's ... but nevertheless, used by everyone on the internet multiple times a day.

Also called the "phone book of the internet", the Domain Name System is used to translate from human-readable hostnames (example.com) to computer-friendly IP addresses (23.192.228.80). 

While learning, I put together a toy project, [rbdig](https://github.com/panacotar/rbdig/), written in Ruby, as I'm more comfortable with this language.

The steps I'll describe:
1. **Building the DNS request**
2. **Creating a socket and sending the DNS request**
3. **Receiving and parsing the DNS reply**
4. **Looping over and subsequent queries (for NS - Name Servers or additional resources)**

I guided myself using this document [RFC1035](https://datatracker.ietf.org/doc/html/rfc1035) to construct the DNS request and parse the response. It is the official doc describing the DNS implementation.   

## 1. Building the DNS request
The DNS request has three parts:
- header (12 bytes)
- question (variable length)

I wanted to see how this looks like in practice. So, with the help of `nc`, I captured a DNS lookup from `dig`. I also used Wireshark to view the UDP packet as it does a good job representing it.
```sh
# Start a listener on port 2020 (saving the output to a file)
nc -u -l 2020 > dns_lookup.txt

# Send a dig request to that port
dig +retry=0 -p 2020 @127.0.0.1 +noedns example.com
```

This is the whole request (as hex bytes): `840f01200001000000000000076578616d706c6503636f6d0000010001`.   
The first 12 bytes are the header: `840f01200001000000000000`, but what do they represent exactly?
The header is described in the section [4.1.1](https://datatracker.ietf.org/doc/html/rfc1035#section-4.1.1). You can find further info on what each means.   

```
840f       0120    0001       0000       0000       0000
query_id + flags + qd_count + an_count + ns_count + ar_count
```

Here is the request in Wireshark. If you want to reproduce this, set Wireshark to listen to the loopback interface and filter for the right `udp.port`.

![Wireshark-dig-capture]({{ site.baseurl }}/assets/images/posts/wireshark_dig_capture.png)

```rb
def query_header
  flags = "\x01\x00"    # the standard flag
  qd_count = "\x00\x01" # the # of entries in the question section
  an_count = "\x00\x00" # the # of resource records in the answer session
  ns_count = "\x00\x00" # the # of name server resource records (in authority records section)
  ar_count = "\x00\x00" # the # of resource records
  @query_id + flags + qd_count + an_count + ns_count + ar_count
end
```
Now that the header is handled with, I could move to the next section. 

The **question section** is made of:
- question name - the actual domain name we're looking for
- query type - the type of record we're looking for (ex: "A" for IPv4 record)
- query class - the class of record we're looking for (ex: "IN" for the INternet)

The more complex part was building the question. DNS has a format for encoding the domain name. It follows a sequence of labels. Each label is made of a length octet + the number of octets. The domain name is terminated wit a null label `\x00`.

A domain name as `www.example.com` becomes `3www7example3com0`. My code for this:

```rb
def encode_domain(domain)
  enc = domain.strip.split('.').map { |s| [s.length].pack("C") + s }.join
  enc + "\x00"
end
```

I created a class dedicated to encoding the message: [DNSQuery](https://github.com/panacotar/rbdig/blob/afddbbd202d002ca83973a751651f7b703f5abbc/lib/message.rb#L1).


## 2. Creating a socket and sending the DNS request

<!-- 

## Sending the request (brief)

## Receiving and parsing the DNS reply
  ### A word on Reader
  ### Preventing loops when handling DNS compression

# No answer on the first try? (looping and querying NS servers)
# Improvements ()

-->