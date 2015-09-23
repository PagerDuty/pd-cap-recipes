# Pagerduty Capistrano Recipes Collection

[![Build Status](https://img.shields.io/travis/PagerDuty/pd-cap-recipes/master.svg)](https://travis-ci.org/PagerDuty/pd-cap-recipes)
[![MIT License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://tldrlegal.com/license/mit-license)
[![Dependency Status](https://img.shields.io/gemnasium/PagerDuty/pd-cap-recipes.svg)](https://gemnasium.com/PagerDuty/pd-cap-recipes)

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

You can skip git integration altogether when needed using

    $ bundle exec cap vagrant deploy -s skip_git=true

or you could use set to selectively disable, useful if you have a local/dev environment you do not want to check:

    set :skip_git, true

* _Note_ From version 0.5.0 onwards pd-cap-recipes no more automatically add hooks into deploy stages. Its up to the consumer code to declare their own after and before hooks. So, if you are migrating to 0.5.0 or above and still want the git:validate_branch_is_tag as part of deployment, add this in your deploy.rb
    ```ruby
    after 'deploy_previous_tag', 'deploy'
    after "deploy:create_symlink", "git:update_tag_for_stage"
    before "deploy", "git:validate_branch_is_tag"
    before "deploy:migrations", "git:validate_branch_is_tag"
    ```

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

Like with the git integration, you can selectively disable this integration when/where needed:

    $ bundle exec cap vagrant deploy -s skip_hipchat=true

or...

    set :skip_hipchat, true

### Non-Standard SSH Port

If you are using a port other than 22 for ssh on your machine you will want to
configure this by setting the port value in the deploy file. For example
```set :port, 10022```.

### Improved Logging

The entire output produced by capistrano is logged to `log/capistrano.log`.

### Benchmarking your deploys

There's also a performance report printed at the end of every deploy to help you find slow tasks in your deployments and keep things snappy.

### Colouring your console output

There are some standard functions to colour your output, for example

  ```ruby
  after "deploy" do
    Capistrano::CLI.ui.say green "Nice job!"
  end
  ```

### Deploy Slowly

There is a task 'deploy:slow' that will cause deployment to be segregated into blocks, based on a percentage of target hosts. The percentage defaults to 10% rounding down, but can be set with the config value :slow_block_size:

    $ bundle exec cap production deploy:slow -s slow_block_size=0.25

or in code...

    set :slow_block_size, 0.25

If you have 100 machines it will start by deploying to 10, then to another 10 and thereon until all machines have been deployed to.

    $ bundle exec cap production deploy:slow

#License and Copyright
Copyright (c) 2014, PagerDuty
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

* Neither the name of pd-cap-recipes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
