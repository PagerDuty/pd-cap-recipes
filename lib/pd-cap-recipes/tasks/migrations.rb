Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :db do 
    desc "Prompts you to continue if you have pending migrations and did not deploy with deploy:migrations"
    task 'check_for_pending_migrations', :on_error => :continue do
      if ENV['PENDING_MIGRATIONS_OK'].nil?
        mig = pending_migrations
        unless mig.empty? 
          unless confirm("Pending Migrations: #{mig.join("\n")}\n\nYou currently have pending migrations but are deploying without deploy:migrations. Are you sure this is what you want to do? #{green "[yes, no]"}")
            raise Capistrano::Error.new("Aborting due to pending migrations")
          end
        end
      else
        logger.info 'WARNING: Skipping pending migration check because PENDING_MIGRATIONS_OK is set.'
      end
    end
  end

  def pending_migrations
    local_migrations - server_migrations
  end

  set :migrations_check_command, 'pd_db_migrations'

  def server_migrations
    # || true to ignore errors as the pd_db_migrations script might not be there
    # for the first deploy
    out = capture("cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec #{migrations_check_command} || true")
    out.split("\n").map(&:strip)
  end

  set :local_migration_files, Dir['db/migrate/*.rb']

  def local_migrations
    local_migration_files.map do |f|
      f.match(/migrate\/(\d+)_/).to_a[1]
    end 
  end

  # Optimally, I would like a way for this to happen after deploy and
  # bundle:install, but not on deploy:migrations. Capistrano does not seem to
  # offer a way of doing that, so we might be missing a script on the server
  # the first time this gets run.
  before 'deploy', 'db:check_for_pending_migrations'
end

