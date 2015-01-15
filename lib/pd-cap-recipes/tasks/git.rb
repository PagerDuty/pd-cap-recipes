require 'grit'

# Bump up grit limits since git.fetch can take a lot
Grit::Git.git_timeout = 600 # seconds
Grit::Git.git_max_size = 104857600 # 100 megs

class GitRepo
  def initialize
    @git = Grit::Git.new(File.join('.', '.git'))
  end

  def method_missing(*args, &block)
    @git.__send__(*args, &block)
  end

  def delete_remote_tag(tag)
    @git.tag d: tag
    @git.push({}, 'origin', "refs/tags/#{tag}")
  end

  def remote_tag(tag)
    @git.tag({}, tag)
    @git.push({}, 'origin', "refs/tags/#{tag}")
  end
end

Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :deploy do
    desc 'Cut a tag for deployment'
    task :prepare do
      new_tag = git_cut_tag
      Capistrano::CLI.ui.say "Your new tag is #{green new_tag}"
      Capistrano::CLI.ui.say "You can deploy the tag by running:\n  bundle exec cap #{stage} deploy -s tag=#{new_tag}"

      if config[:bot_deployer_command_formatter]
        command = config[:bot_deployer_command_formatter] % [new_tag, stage]
        Capistrano::CLI.ui.say "You can also deploy by sending this to your deployment bot:\n  #{purple command}"
      end
    end
  end

  after "rollback", "deploy"
  desc "Rolls back to not but last deploy"
  task :rollback do
    git = GitRepo.new
    env = config[:stage]
    tags_from_current_environment = git.tag(l: "DEPLOYED---#{env}---*").split
    total = tags_from_current_environment.size
    raise "Cannot rollback as there are only #{total} deployments to #{env}" if total < 2
    tag_to_rollback_to = tags_from_current_environment[-2]
    Capistrano::CLI.ui.say "Rolling back to #{tag_to_rollback_to}"
    config[:tag] = tag_to_rollback_to
  end

  after "deploy:create_symlink", "git:update_tag_for_stage"
  before "deploy", "git:validate_branch_is_tag"
  before "deploy:migrations", "git:validate_branch_is_tag"

  namespace :git do
    set :branch do
      return config[:_git_branch] if config[:_git_branch]

      tag = config[:tag]
      if !config[:tag]
        tag = Capistrano::CLI.ui.ask green("Tag to deploy: ")
        tag = tag.to_s.strip
      end

      config[:_git_branch] = tag
      git_sanity_check(tag)

      config[:_git_branch]
    end

    task :update_tag_for_stage do
      git = GitRepo.new
      env = config[:stage]

      git.delete_remote_tag env
      git.remote_tag env
      git.remote_tag "DEPLOYED---#{env}---#{Time.now.utc.to_i}"
    end

    task :validate_branch_is_tag do
      # Make sure an external recipe is not overriding the branch variable by
      # doing something like
      # set :branch, :master
      if config[:branch] != config[:_git_branch]
        raise Capistrano::Error.new("The current branch do not seems to match the cached version. Make sure you are not overriding it in your config by doing something like 'set :deploy, 'release''")
      end
    end
  end

  def git_cut_tag
    repo = Grit::Repo.new('.')
    raise 'You are currently in a detached head state. Cannot cut tag.' unless repo.head

    new_tag = "#{repo.head.name}-#{Time.now.utc.to_i}"

    git = GitRepo.new
    git.fetch
    git.remote_tag new_tag

    new_tag
  end

  def git_sanity_check(tag)
    git  = GitRepo.new
    deploy_sha = git.show_ref({raise: true}, '-s', tag).chomp

    # See this article for info on how this works:
    # http://stackoverflow.com/questions/3005392/git-how-can-i-tell-if-one-commit-is-a-descendant-of-another-commit
    if ENV['REVERSE_DEPLOY_OK'].nil?
      if safe_current_revision && git.merge_base({}, deploy_sha, safe_current_revision).chomp != git.rev_parse({ :verify => true }, safe_current_revision).chomp
        unless continue_with_reverse_deploy(deploy_sha)
          raise "You are trying to deploy #{deploy_sha}, which does not contain #{safe_current_revision}," + \
            " the commit currently running.  Operation aborted for your safety." + \
            " Set REVERSE_DEPLOY_OK to override."
        end
      end
    else
      logger.info 'WARNING: Skipping reverse deploy check because REVERSE_DEPLOY_OK is set.'
    end
  end

  def confirm(msg)
    continue = Capistrano::CLI.ui.ask msg
    continue = continue.to_s.strip
    continue.downcase == 'yes'
  end

  def continue_with_reverse_deploy(deploy_sha)
    msg = "You are trying to deploy #{deploy_sha}, which does not contain #{safe_current_revision}, the commit currently running. Are you sure you want to continue? #{green "[No|yes]"}"
    confirm msg
  end

  def green(s)
    "\e[1m\e[32m#{s}\e[0m"
  end

  def purple(s)
    "\e[1m\e[35m#{s}\e[0m"
  end

  # current_revision will throw an exception if this is the first deploy...
  def safe_current_revision
    begin
      current_revision
    rescue => e
      logger.info "*" * 80
      logger.info "An exception as occured while fetching the current revision. This is to be expected if this is your first deploy to this machine. Othewise, something is broken :("
      logger.info e.inspect
      logger.info "*" * 80
      nil
    end
  end
end
