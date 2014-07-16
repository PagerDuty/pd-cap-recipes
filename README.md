# Pagerduty Capistrano Recipes Collection

These are various capistrano recipes used at [PagerDuty Inc.](http://www.pagerduty.com/). Feel free to fork and contribute to them.

## Running tests

    $ bundle install
    $ bundle exec rspec spec

## Install

Add the following to your Gemfile.

    group :capistrano do 
      # Shared capistrano recipes
      gem 'pd-cap-recipes', :git => 'git://github.com/PagerDuty/pd-cap-recipes.git'
    
      # extra dependencies for some tasks
      gem 'git', '1.2.5'
      gem 'hipchat', :git => 'git://github.com/smathieu/hipchat.git'
      gem 'cap_gun'
      gem 'grit'
    end

Then run 
    bundle install
    
## Usage

### Git 

One of the main feature of these recipes is the deep integration with Git and added sanity check to prevent your from deploying the wrong branch. 

The first thing to know is that we at PagerDuty always deploy of a tag, never from a branch. You can generate a new tag by running the follwing command:

    cap production deploy:prepare
    
This should generate a tag in a format like master-1328567775. You can then deploy the tag with the following command:

cap production deploy -s tag=master-1328567775

The following sanity check will be performed automatically:

* Validate the master-1328567775 as the latest deploy as an ancestor
* Validate that you have indeed checkout that branch before deploying

Another nice thing this recipe does is keep an up to date tag for each environment. So the production tag is what is currently deployed to production. So if you ever need to diff a branch and what is already deploy you can do something like:

    git diff production

### Deploy Comments

When you deploy, you will prompted for a comment. This will be used to notify your coworkers via email and HipChat. 

### Improved Logging

The entire output produced by capistrano is logged to log/capistrano.log.

### Benchmarking your deploys

There's also a performance report printed at the end of every deploy to help you find slow tasks in your deployments and keep things snappy.


