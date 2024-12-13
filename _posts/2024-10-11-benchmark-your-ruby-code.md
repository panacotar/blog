---
layout: post
---

Ruby offers an easy way to benchmark the code. Here is some syntax for basic benchmarking.

This is done with the [Benchmark](https://github.com/ruby/benchmark) module included in the Ruby standard library. Even in irb, you can just `require "benchmark"`.   
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

The meaning of these stats (measured unit is seconds):
```
user CPU time   system CPU time   sum user + system CPU   times elapsed real time
0.021121        0.001285          0.022406                (  0.022459)
```
We can also label the reports `x.report("sort")`.   
Using `Benchmark.bmbm` will run the tests twice for a (supposedly) better reading.   
Also, we can feed custom methods to the reports in order to compare them.

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
Returning
```
Rehearsal -------------------------------------------------
first_method    0.004724   0.000000   0.004724 (  0.004793)
second_method   0.004317   0.000000   0.004317 (  0.004381)
---------------------------------------- total: 0.009041sec

                    user     system      total        real
first_method    0.005145   0.000000   0.005145 (  0.005263)
second_method   0.004220   0.000000   0.004220 (  0.004278)
```
