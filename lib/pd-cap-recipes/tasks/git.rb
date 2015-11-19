require 'grit'
require 'pd-cap-recipes/classes/git_repo'

# Bump up grit limits since git.fetch can take a lot
Grit::Git.git_timeout = 600 # seconds
Grit::Git.git_max_size = 104857600 # 100 megs

# Create a new tag using the name of current branch and a UTC timestamp, then
# push code & tag to remote.
def git_cut_tag(git=GitRepo.new)
  remote = 'origin'
  if git.head_detached?
    raise 'You are currently in a detached head state. Cannot cut tag.'
  end
  new_tag = "#{git.head.name}-#{Time.now.utc.to_i}"
  git.fetch
  git.remote_tag new_tag, remote
  return new_tag
end

Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :deploy do
    desc 'Cuts a tag for deployment and prints out further instructions to finalize deployment'
    task :prepare do
      skip_git = fetch(:skip_git, false)
      if skip_git
        Capistrano::CLI.ui.say yellow "Skipping prepare as 'skip_git' option is enabled"
        next
      end

      git = GitRepo.new
      new_tag = git_cut_tag(git)
      Capistrano::CLI.ui.say "Your new tag is #{green new_tag}"

      user_command = "bundle exec cap #{stage} deploy -s tag=#{new_tag}"
      Capistrano::CLI.ui.say "You can deploy the tag by running:\n  #{yellow user_command}"

      if config[:bot_deployer_command_formatter]
        command = config[:bot_deployer_command_formatter] % [new_tag, stage]
        Capistrano::CLI.ui.say "You can also deploy by sending this to your deployment bot:\n  #{purple command}"
      end
    end
  end

  # NOTE: not being used as far as we can tell
  desc 'Rollback to the previous git tag deployed by performing a regular deploy.'
  task :deploy_previous_tag do
    git = GitRepo.new
    env = config[:stage]
    tags_from_current_environment = git.tag(l: "DEPLOYED---#{env}---*").split
    total = tags_from_current_environment.size
    raise "Cannot rollback as there are only #{total} deployments to #{env}" if total < 2
    tag_to_rollback_to = tags_from_current_environment[-2]
    Capistrano::CLI.ui.say "Rolling back to #{tag_to_rollback_to}"
    config[:tag] = tag_to_rollback_to
  end

  namespace :git do

    # WANING: This is dangerous. TL;DR don't reuse this.
    #
    # When the deploy task runs, a hook defined above in this file runs
    # calling  validate_branch_is_tag which then tries to access :branch
    # triggering creating a tag if :tag is not defined, but also actually
    # ssh'ing out to a machine to get current_resivion value through a call
    # to git_sanity_check.
    #
    # If called after pushing a release and setting current link it will fail
    # when calling get_sanity_check which looks for the REVISON file at
    # <path to app>/current/REVISON on one of the servers.
    #
    # You may deploy and then have no REVISION file yet which means this fails.
    set :branch do
      unless config[:_git_branch]
        # if tag is provided (e.g. -s tag=master-1234567890), use it. otherwise, cut a new tag.
        tag = config[:tag] || git_cut_tag
        config[:_git_branch] = tag
        git_sanity_check(tag)
      end
      config[:_git_branch]
    end

    # NOTE: looking at projects in Github I'm not seeing these tags.
    task :update_tag_for_stage do
      skip_git = fetch(:skip_git, false)
      if skip_git
        Capistrano::CLI.ui.say yellow "Skipping update_tag_for_stage as 'skip_git' option is enabled"
        next
      end

      logger.important("Updating the tag for stage #{stage}")
      git = GitRepo.new
      env = config[:stage]
  
      git.delete_remote_tag env
      git.remote_tag env
      git.remote_tag "DEPLOYED---#{env}---#{Time.now.utc.to_i}"
    end

    task :validate_branch_is_tag do
      skip_git = fetch(:skip_git, false)
      if skip_git
        Capistrano::CLI.ui.say yellow "Skipping validate_branch_is_tag as 'skip_git' option is enabled"
        next
      end
      # Make sure an external recipe is not overriding the branch variable by
      # doing something like
      # set :branch, :master
      if config[:branch] != config[:_git_branch]
        raise Capistrano::Error.new("The current branch do not seems to match the cached version. Make sure you are not overriding it in your config by doing something like 'set :deploy, 'release''")
      end
    end
  end

  # Ensures that the code with given tag is a descendent of the deployed revision.
  # Relies on current_revison Cap call through safe_current_revision
  def git_sanity_check(tag)
    return if should_skip_sanity_check?

    git  = GitRepo.new
    opts = {raise: true, verify: true}
    deploy_sha = git.get_hash(tag, opts)

    # See this article for info on how this works:
    # http://stackoverflow.com/questions/3005392/git-how-can-i-tell-if-one-commit-is-a-descendant-of-another-commit
    current_version_sha = git.get_hash(safe_current_revision, opts)
    common_version_sha = git.merge_base({}, deploy_sha, safe_current_revision).chomp
    return if common_version_sha == current_version_sha

    raise "You are trying to deploy #{deploy_sha}, which does not contain #{safe_current_revision}," + \
      " the commit currently running.  Operation aborted for your safety." + \
      " Set REVERSE_DEPLOY_OK to override." unless continue_with_reverse_deploy(deploy_sha)
  end

  # Coniditons for skipping git sanity check
  def should_skip_sanity_check?
    skip_git = fetch(:skip_git, false)
    if skip_git
      Capistrano::CLI.ui.say yellow "Skipping git_sanity_check as 'skip_git' option is enabled"
      return true
    end

    unless is_already_deployed
      Capistrano::CLI.ui.say yellow "It appears you have never deployed this app yet, continuing without sanity checking revision to deploy"
      return true
    end

    if reverse_ok
      Capistrano::CLI.ui.say yellow 'reverse_deploy_ok - continuing without sanity checking revision to deploy'
      return true
    end

    return false
  end

  # If we are in a non-Production environment and we have enabled it allow reverse deploy
  def reverse_ok
    return (ENV['REVERSE_DEPLOY_OK'] || fetch(:reverse_deploy_ok, false)) && fetch(:stage) != 'production'
  end

  def confirm(msg)
    continue = Capistrano::CLI.ui.ask msg
    continue = continue.to_s.strip
    continue.downcase == 'yes'
  end

  def continue_with_reverse_deploy(deploy_sha)
    msg = "You are trying to deploy #{deploy_sha}, which does not contain #{safe_current_revision}, " \
      "the commit currently running. If you are deploying a previous version you will get this message. " \
      "If you are deploying from a branch that does not contain the code in the current release you will " \
      "get this message. Are you sure you want to continue? #{green "[No|yes]"}"
    confirm msg
  end

  # current_revision will throw an exception if this is the first deploy...
  # We want to use this value in decision making and therefore handle the
  # exception  and return nil if no current version found.
  #
  # WARNING: when this is called can determine what the value returned is, ie
  # if you call this before deploying you get one value, after deploying a
  # different one.
  def safe_current_revision
    begin
      current_revision
    rescue => e
      logger.info "*" * 80
      logger.info "An exception has occured while fetching the current revision. This is to be expected if this is your first deploy to this machine. Otherwise, something is broken :("
      logger.info e.inspect
      logger.info "*" * 80
      return nil
    end
  end

  # If a current revision exists we assume we've deployed before.
  def is_already_deployed
    return !safe_current_revision.nil?
  end
end
