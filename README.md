[![Dependency Status](https://img.shields.io/gemnasium/PagerDuty/pd-cap-recipes.svg)](https://gemnasium.com/PagerDuty/pd-cap-recipes)

# Pagerduty Capistrano Recipes Collection

These are various capistrano recipes used at [PagerDuty Inc.](http://www.pagerduty.com/). Feel free to fork and contribute to them.

## Running tests

    $ bundle install
    $ bundle exec rspec spec

## Install

Add the following to your `Gemfile`.

```ruby
group :capistrano do
  gem 'pd-cap-recipes', :git => 'git://github.com/PagerDuty/pd-cap-recipes.git'
end
```

Then run

    $ bundle install

## Usage

### Git

One of the main feature of these recipes is the deep integration with Git and added sanity check to prevent your from deploying the wrong branch.

The first thing to know is that we at PagerDuty always deploy of a tag, never from a branch. You can generate a new tag by running the follwing command:

    $ bundle exec cap production deploy:prepare

This should generate a tag in a format like `master-1328567775`. You can then deploy the tag with the following command:

    $ bundle exec cap production deploy -s tag=master-1328567775

The following sanity check will be performed automatically:

* Validate the `master-1328567775` as the latest deploy as an ancestor
* Validate that you have indeed checkout that branch before deploying

Another nice thing this recipe does is keep an up to date tag for each environment. So the production tag is what is currently deployed to production. So if you ever need to diff a branch and what is already deploy you can do something like:

    git diff production

### Deploy Comments

In order to enable custom deploy comments which are sent via HipChat; you will need to follow these steps:

1. If `hipchat` gem is not part of your project, add it. It's not part `pd-cap-recipes` since it's an optional feature. Last known good version is `1.4.0`. Basically, you need a version which supports the following functionality:

  ```ruby
  # hipchat.send
  # hipchat.send_options
  # https://github.com/hipchat/hipchat-rb/blob/master/lib/hipchat/capistrano2.rb
  hipchat.send('deploying things', hipchat.send_options)
  ```

  ```ruby
  gem 'hipchat', '~> 1.4.0'
  ```

2. Add a before hook in your deployment file.

  ```ruby
  before 'deploy', 'hipchat:custom_comment'
  ```

When you deploy, you will prompted for a comment. This will be used to notify your coworkers via HipChat.

### Improved Logging

The entire output produced by capistrano is logged to `log/capistrano.log`.

### Benchmarking your deploys

There's also a performance report printed at the end of every deploy to help you find slow tasks in your deployments and keep things snappy.

#License and Copyright
Copyright (c) 2014, PagerDuty
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

* Neither the name of [project] nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
