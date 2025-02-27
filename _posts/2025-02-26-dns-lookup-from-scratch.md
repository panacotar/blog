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
The DNS request has two parts:
- header (12 bytes)
- question (variable length)

I wanted to see how this looks like in practice. So, with the help of netcat, I captured a DNS lookup from `dig`. I also used Wireshark to view the UDP packet as it does a good job at representing network packets.
```sh
# Start a listener on port 2020 (saving the output to a file)
nc -u -l 2020 > dns_lookup.txt

# Send a dig request to that port
dig +retry=0 -p 2020 @127.0.0.1 +noedns example.com
```

This is the whole request sent by `dig` (as hex bytes): `840f01200001000000000000076578616d706c6503636f6d0000010001`. But what does it all mean?

The first 12 bytes are the header: `840f01200001000000000000`. I spread the method handling this part so that it includes comments for each component. The header is described in the section [4.1.1](https://datatracker.ietf.org/doc/html/rfc1035#section-4.1.1). You can find further info on what each means.   


```rb
def query_header
  query_id = "\x84\x0f" # 2 random bytes. When we get the response, the same bytes should be included
  flags = "\x01\x00"    # the standard flag
  qd_count = "\x00\x01" # the # of entries in the question section
  an_count = "\x00\x00" # the # of resource records in the answer session
  ns_count = "\x00\x00" # the # of name server resource records (in authority records section)
  ar_count = "\x00\x00" # the # of resource records
  query_id + flags + qd_count + an_count + ns_count + ar_count
end
```
Now that the header is handled, so I could move to the next section.    
The **question section** is made of:
- question name - the actual domain name we're looking for
- query type - the type of record we're looking for (ex: "A" for IPv4 record)
- query class - the class of record we're looking for (ex: "IN" for the INternet)

The more complex part was building the question. DNS has a format for encoding the domain name. It follows a sequence of labels. Each label is made of a length octet + that number of octets. The domain name is terminated with a null label `\x00`.

A domain name as `www.example.com` becomes `3www7example3com0`. My code for this:

```rb
def encode_domain(domain)
  enc = domain.strip.split('.').map { |s| [s.length].pack("C") + s }.join
  enc + "\x00"
end
```

A screenshot of the request in Wireshark. If you want to reproduce this, set Wireshark to listen to the loopback interface and filter for the right `udp.port`.

![Wireshark-dig-capture]({{ site.baseurl }}/assets/images/posts/wireshark_dig_capture.png)

I put all the encoding logic the [DNSQuery](https://github.com/panacotar/rbdig/blob/afddbbd202d002ca83973a751651f7b703f5abbc/lib/message.rb#L1) class.


## 2. Creating a socket and sending the DNS request
I'll not get into details here. The idea is getting this request out and listening to a response from the DNS server.

I created a UDP socket for sending and receiving to the response. Then wrapped everything in the `connect` method.
```rb
def connect(message, server = '8.8.8.8', port = 53)
  socket = UDPSocket.new
  socket.send(message, 0, server, port)
  response, _ = socket.recvfrom(512) # RFC1035 specifies a 512 octets size limit for UDP messages

  socket.close
  response
end
```

## 3. **Receiving and parsing the DNS reply**
The DNS server will send back the response which might or not include the answer (the IPv4 address in our case). After receiving the response, I validated it has the same `query_id` as the request and I was starting to parse it. Basically reversing the steps I used when building the request, parsing the header & question sections. But, **in addition**, the DNS response might include 3 more sections, each including zero or more Resource Records (RRs) or DNS record:

- Answers - the answer we're looking for
- Authorities (NS records) - when a nameserver doesn't have the answer, it will redirect you to other servers
- Additionals - also when a nameserver doesn't have the answer, but it includes the IPv4 address of those servers which might contain the answer. This sections might contain other data, but that's out of scope of this article.

These Resource Records (RRs) all have same format.

### A word on `Reader`
The DNS response will be a string of bytes, I needed to go over it while parsing. To keep track of where I was in the string, I created the `Reader` class. This get initialized with a string. It can read a specific number of bytes from that string while keeping a pointer of the position I'm in the string.   
A brief example:
```rb
r = Reader.new("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A".b)
r.pos     # => 0
r.read(2) # => "\x00\x01"
r. pos    # => 2
r.read(4) # => \x02\x03\x04\x05
r.pos     # => 4
```

Ruby has the `StringIO` class which does this and more. But for this project, I wanted to implement it from scratch.

# The parsing class
I created the `DNSReponse` class responsible for handling the response. It accepts the raw response and initiates a instance of `Reader` with that byte string:
```rb
class DNSResponse
  attr_reader :header, :body, :answers, :authorities, :additional
  def initialize(dns_reply)
    @buffer = Reader.new(dns_reply)
    @header = {}
    @body = {}
    @answers = []
    @authorities = []
    @additional = []
  end

  def parse
    @header = parse_header
    @body = parse_body
    # The header specifies how many answers, authorities and additional RRs are there in this response
    @answers = parse_resource_records(@header[:an_count])
    @authorities = parse_resource_records(@header[:ns_count])
    @additional = parse_resource_records(@header[:ar_count])
    self
  end
  [...]
```
It uses the buffer on the next steps in the `parse` method. This is how it parses the header and body sections:
```rb
def parse_header
  query_id, flags, qd_count, an_count, ns_count, ar_count = @buffer.read(12).unpack('n6')
  { query_id:, flags:, qd_count:, an_count:, ns_count:, ar_count: }
end

def parse_body
  question = extract_domain_name(@buffer)
  q_type = @buffer.read(2).unpack('n').first
  q_class = @buffer.read(2).unpack('n').first
  { question:, q_type:, q_class: }
end
```
Extracting the domain name was maybe the most complex part. Up until now, it is straightforward, I could transform from `\x07example\x03com\x00` to `example.com` and that would suffice.    
But I encountered some exceptions as I was moving forward to parsing the RRs sections. 
```rb
def parse_resource_records(num_records)
  # It returns an array of records if any
  num_records.times.collect do
    rr_name = extract_domain_name(@buffer) # A domain name to which this RR belongs
    rr_type, rr_class = @buffer.read(4).unpack('n2') # the type & class of this record
    ttl = @buffer.read(4).unpack('N').first # time-to-live for this record (how long it should be cached)
    rr_data_length = @buffer.read(2).unpack('n').first # the length (bytes) of the rr_data field
    rr_data = extract_record_data(@buffer, rr_type, rr_data_length) # data describing the resource, variable length depending on the type of resource. Example for TYPE='A' and CLASS='IN', the field is a IPv4 address (4 bytes length)
    { rr_name:, rr_type:, rr_class:, ttl:, rr_data_length:, rr_data: }
  end
end
```

### Handling DNS compression and preventing loops

<!-- 

# No answer on the first try? (looping and querying NS servers)
# Improvements ()

-->