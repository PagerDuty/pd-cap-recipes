require 'hipchat/capistrano'

Capistrano::Configuration.instance(:must_exist).load do |config|
  # Set these in you deploy.rb file
  # set :hipchat_token, "??????????"
  # set :hipchat_room_name, "My Room"
  #
  # or
  #
  # set :hipchat_room_name do
  #   production? ? 'Main Room' : 'Log Room'
  # end
  
  set :hipchat_announce do 
    production?
  end

  set :hipchat_message do
    message = "#{human} is deploying #{deployment_name} to #{stage}"
    message << " (with migrations)" if hipchat_with_migrations
    message << ".<br/>"
    message << comment 
    message
  end

  set :hipchat_finished_message do
    message = "#{human} finished deploying #{deployment_name} to #{stage}."
  end

  def deployment_name
    if branch
      "#{application}/#{branch}"
    else
      application
    end
  end

  def deploy_user
    fetch(:hipchat_deploy_user, "Deploy")
  end

  def human
    ENV['HIPCHAT_USER'] ||
      fetch(:hipchat_human,
            if (u = %x{git config user.name}.strip) != ""
              u
            elsif (u = ENV['USER']).to_s != ""
              u
            else
              "Someone"
            end)
  end

  def env
    fetch(:hipchat_env, fetch(:rack_env, fetch(:rails_env, "production")))
  end
  
  def production?
    env == 'production'
  end
end
