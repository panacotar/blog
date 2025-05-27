---
layout: post
title: Safeguard against DoS in Rails helper
tags: ruby-rails
---

One recent contribution to the Rails codebase caught my attention. It concerns the `distance_of_time_in_words` method. The fix is meant to prevent a possible Denial of Service while using this method.

The contribution was brought by [Stazer](https://github.com/Stazer).
I found out about the [PR](https://github.com/rails/rails/pull/54923) in the newsletter [This week in Rails](https://world.hey.com/this.week.in.rails/improved-leap-year-counting-performance-and-more-4c28a8ac).

## The problem
The `distance_of_time_in_words` method returns the approximate distance in time between two timeframes (can be `Time`, `Date`, or `DateTime` objects or integers) and displays it in a nice, humanized format.
To be correct, the leap years between those two timeframes should be considered. It uses `count` and a range to get the number of leap years.

```rb
[...]
leap_years = (from_year > to_year) ? 0 : (from_year..to_year).count { |x| Date.leap?(x) }
[...]
```

This is a blocking process. The calculation can take a long time if the distance between `from_year` and `to_year` is big enough.    
Users might be able to trigger this DoS if they can set a timestamp which is then being passed to `distance_of_time_in_words`.

I found it interesting how subtle this vulnerability is. The contributor encountered this problem in one of their personal projects and decided to open a PR to Rails.

## The fix
This contribution safeguards against DoS. It calculates the leap years in **constant time**.
```rb
fyear = from_year - 1
(to_year / 4 - to_year / 100 + to_year / 400) - (fyear / 4 - fyear / 100 + fyear / 400)
```

I will present how you can test this fix locally.

## Testing this fix
For this, I created a new, minimal Rails app:
```
rails new my_awesome_app --minimal 
```
Then I wanted to override the `distance_of_time_in_words` method. So I created this new file:
```rb
# config/initializer/actionview.rb

require 'action_view'

module ActionView::Helpers::DateHelper
  alias __distance_of_time_in_words distance_of_time_in_words
  private :__distance_of_time_in_words

  def distance_of_time_in_words(_from_time, _to_time = 0, _options = {})
    [...]
    leap_years = if from_year > to_year
      0
    else
      fyear = from_year - 1
      (to_year / 4 - to_year / 100 + to_year / 400) - (fyear / 4 - fyear / 100 + fyear / 400)
    end
    [...]
  end

  def old_distance_of_time_in_words(_from_time, _to_time = 0, _options = {})
    [...]
    leap_years = (from_year > to_year) ? 0 : (from_year..to_year).count { |x| Date.leap?(x) }
    [...]
  end
end
```
I replaced the [rest of the code in the method](https://github.com/Stazer/rails/blob/f08836bea882c4daa0cf498f8374416c6d2c74d2/actionview/lib/action_view/helpers/date_helper.rb#L96) from the rails repo.

I'm now able to test the fix straight in the Rails console:
```rb
require "benchmark"

num_years = 100_000_000.years
Benchmark.bm do |x|
  x.report("old") { 
    ApplicationController.helpers.old_distance_of_time_in_words(Time.now, Time.now + num_years)
  }
  x.report("new") {
    ApplicationController.helpers.distance_of_time_in_words(Time.now, Time.now + num_years)
  }
end
```

```sh
         user     system      total        real
old  6.095959   0.000000   6.095959 (  6.096444)
new  0.000117   0.000000   0.000117 (  0.000117)
[...]
```
Here we can see the big difference. The old code counted the leap years in a way that slowed things down, here, taking around 6 seconds to perform the count.   
As the number of years between the two dates increases, the computing time grows much faster. When I tested it with a range of `1,000,000,000` years, it took 61 seconds. This has the potential to bring the application to a halt.    
The updated code performs the calculation in constant time, regardless of the numbers of years.
