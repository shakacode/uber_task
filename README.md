# UberTask

Welcome to UberTask! A gem that will help you executing sequential tasks that
require progress reporting and retries.

## Table of Contents

* [Installation](#installation)
* [Use case](#use-case)
* [Usage](#usage)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'uber_task'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install uber_task

## Use case


This gem was born when we needed to deploy Heroku's apps, and it turns out that
there were multiple points of failure; since we were communicating with Github,
Cloudflare, and Heroku to build the app, at any point, the connection may fail 
which would leave the app half-built.

The solution was, in theory, simple, retry specific steps, but rescuing errors
and using loops for each action made the code harder to maintain and read.

In most cases, most of the code inside the methods was there to deal with the
retries or progress reporting when the main logic was relatively simple.

So, we extracted all the retry/reporting logic into this gem, simplifying the
deployment actions.

## Usage

TODO: Examples...b

## License

The gem is available as open source under the terms of the 
[MIT License](https://opensource.org/licenses/MIT).
