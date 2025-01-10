---
layout: post
title: Fix the N+1 queries in Rails
tags: ruby-rails
---

The N+1 query problem is a common performance issue encountered in Rails applications.

There are tools to detect this problem automatically. And Active Record provides ways to fix it.

## The problem
This is related to having associations and the way we load the respective records. Active Record simplifies database interaction, but it can lead to issues like N+1 query. By default, Active Record uses a lazy loading approach, meaning it only loads records when they are accessed. 

N+1 query issue occur when the application queries the database, loops over the results, and **executes a separate query for each associated record** in the list. 

An example association: `Users` having many `Dogs`. 

```
class User < ApplicationRecord
  has_many :dogs
end

class Dog < ApplicationRecord
  belongs_to :user
end
```

It is common in the Rails app to load all records and then loop over them, accessing their associated model (for instance, wanting to display the records in an index view).   
```sh
# rails c
User.all.each { |u| puts u.dogs };nil
```
Here, we list the user's dogs. While the code works correctly, it triggers too many database queries. Specifically, it prompts Active Record to execute one query to fetch the users and additional queries for each user in the database (a total of **1+N** queries):
```sh
User Load (0.1ms)  SELECT "users".* FROM "users"
Dog Load (0.1ms)  SELECT "dogs".* FROM "dogs" WHERE "dogs"."user_id" = ?  [["user_id", 1]]
Dog Load (0.1ms)  SELECT "dogs".* FROM "dogs" WHERE "dogs"."user_id" = ?  [["user_id", 2]]
[...]
Dog Load (0.0ms)  SELECT "dogs".* FROM "dogs" WHERE "dogs"."user_id" = ?  [["user_id", 300]]
```

This can slow down the app and result in a high database load, especially in apps with large datasets. 
For an app with 100.000 associated records, there will be 1 + 100.000 queries.

## The Active Record solution
One solution provided by Active Record is to **eager load** the associated records upfront. This is achieved with the [#includes](https://apidock.com/rails/ActiveRecord/QueryMethods/includes) query method, allowing the app to load users and all their dogs in two queries. It avoids the N+1 query problem.

```sh
# rails c
User.includes(:dogs).all.each { |u| puts u.dogs };nil
```

```sh
User Load (0.1ms)  SELECT "users".* FROM "users"
Dog Load (0.4ms)  SELECT "dogs".* FROM "dogs" WHERE "dogs"."user_id" IN (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)  [["user_id", 1], ["user_id", 2], ["user_id", 3], ["user_id", 4], ["user_id", 5], ["user_id", 6], ["user_id", 7], ["user_id", 8], ["user_id", 9], ["user_id", 10]]
```

### The case of nested associations
What happens if we need to access data from a nested association?   
Let's say each dog `has_many` toys, and we want to print the number of toys for each dog.   
If we simply add a call `dog.toys.size`, the records for dogs and users will be eager loaded, while the toys will still be lazy loaded.
```sh
# rails c
User.includes(:dogs).all.each { |u| u.dogs.each { |d| puts d.toys.size } };nil
```
```sh
User Load (0.1ms)  [...]
Dog Load (0.4ms)  [...]
Toy Count (0.1ms)  SELECT COUNT(*) FROM "toys" WHERE "toys"."dog_id" = ?  [["dog_id", 1]]
Toy Count (0.1ms)  [...] 
Toy Count (0.0ms)  [...]
[...]
Toy Count (0.0ms)  [...]
```
The syntax for including the association is `User.includes(dogs: :toys)` or `User.includes(dogs: [:toys])`:
```sh
# rails c
User.includes(dogs: :toys).all.each { |u| u.dogs.each { |d| puts d.toys.size } };nil
```

```shell
User Load (0.2ms)  [...]
Dog Load (0.4ms)   [...]
Toy Load (0.5ms)   [...]
```

## Useful tools

The [Bullet](https://github.com/flyerhzm/bullet) gem can be implemented in your app. It automatically checks your app and notifies you when it detects N+1 queries. Moreover, it also notifies when you're using eager loading that isn't necessary and when you should use counter cache. Make sure to add it under the development gems.   
Once Bullet detects an N+1 query issue, it will trigger a warning:
```sh
user: john
GET /
USE eager loading detected
  User => [:dogs]
  Add to your query: .includes([:dogs])
Call stack
[...]
```

<!-- # When N+1 is this not a problem? -->

## Resources
- ruby.mobidev.biz
- www.visuality.pl