set :application, "pagerduty"
set :scm, :git

require 'pd-cap-recipes'

namespace :deploy do
  desc 'Restart the app'
  task :restart do
  end
end
