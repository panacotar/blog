---
layout: post
tags: ruby-rails
---

Ruby offers an easy way to benchmark the code. Here is some syntax for basic benchmarking.

This is done with the [Benchmark](https://github.com/ruby/benchmark) module included in the Ruby standard library. You can run it even in IRB, simply `require "benchmark"`.   
In its simplest form, `Benchmark.measure` accepts a code block and outputs the time it takes to execute it.
```rb
require "benchmark"

puts Benchmark.measure { sleep(1) }
```
Returning:
```
  0.000061   0.000031   0.000092 (  1.001175)
```
The meaning of these stats (measured unit is second):
```
user CPU time   system CPU time   sum user + system CPU   times elapsed real time
  0.000061        0.000031          0.000092                (  1.001175)
```

A more advanced form is using `Benchmark.bm`, this allows us to compare the execution of different code blocks:
```rb
require "benchmark"

arr = (1..100_000).map { rand }
Benchmark.bm do |x|
  # Each x.report is a different test item to compare against
  x.report { arr.dup.sort }
  x.report { arr.dup.sort! }
end
```
```
   user     system      total        real
0.021121   0.001285   0.022406 (  0.022459)
0.018150   0.003547   0.021697 (  0.021704)
```

We can also label the reports `x.report("sort")`.   
Also, we can provide predefined methods in order to compare them.   
Using `Benchmark.bmbm` will run the tests twice for a (supposedly) better reading.   

```rb
require "benchmark"

arr = (1..100_000_000).map { rand }
def first_method(arr)
  arr.last
end

def second_method(arr)
  arr[-1]
end

Benchmark.bmbm do |x|
  x.report("first_method") { 100_000.times do; first_method(arr); end }
  x.report("second_method") { 100_000.times do; second_method(arr); end }
end
```
```
Rehearsal -------------------------------------------------
first_method    0.004724   0.000000   0.004724 (  0.004793)
second_method   0.004317   0.000000   0.004317 (  0.004381)
---------------------------------------- total: 0.009041sec

                    user     system      total        real
first_method    0.005145   0.000000   0.005145 (  0.005263)
second_method   0.004220   0.000000   0.004220 (  0.004278)
```

## Benchmark-ips
Another performance gem built on the Benchmark from above. [Benchmark-ips](https://github.com/evanphx/benchmark-ips) measure how many times a code block will run in a second (iterations per second - IPS) rather than measuring the time it takes for a code block to run.

You have to install the gem: `gem install benchmark-ips`. The syntax is:
```rb
require "benchmark/ips"

arr = (1..100_000_000).map { rand }
def first_method(arr)
  arr.last
end

def second_method(arr)
  arr[-1]
end

Benchmark.ips do |x|
  x.report("first method") { first_method(arr) }
  x.report("second method") { second_method(arr) }

  x.compare!
end
```
```
ruby 3.1.2p20 (2022-04-12 revision 4491bb740a) [x86_64-linux]
Warming up --------------------------------------
        first method     1.685M i/100ms
       second method     1.921M i/100ms
Calculating -------------------------------------
        first method     16.390M (± 3.2%) i/s   (61.01 ns/i) -     82.542M in   5.042099s
       second method     18.257M (± 1.1%) i/s   (54.77 ns/i) -     92.216M in   5.051680s

Comparison:
       second method: 18256810.3 i/s
        first method: 16389785.2 i/s - 1.11x  slower
```

Recommended read: [https://shopify.engineering/how-fix-slow-code-ruby](https://shopify.engineering/how-fix-slow-code-ruby).