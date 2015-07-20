require 'grit'

# Bump up grit limits since git.fetch can take a lot
Grit::Git.git_timeout = 600 # seconds
Grit::Git.git_max_size = 104857600 # 100 megs

class GitRepo
  def initialize()
    @git = Grit::Git.new(File.join('.', '.git'))
    @repo = Grit::Repo.new('.')
  end

  def method_missing(*args, &block)
    @git.__send__(*args, &block)
  end

  def delete_remote_tag(tag)
    @git.tag d: tag
    @git.push({raise: true}, 'origin', "refs/tags/#{tag}")
  end

  def remote_tag(tag)
    @git.tag({raise: true}, tag)
    @git.push({raise: true}, 'origin', "refs/tags/#{tag}")
  end

  # Fetch latest from origin and check given hash exists in origin
  def check_tag_exists_in_origin(tag, origin_name='origin')
    hash = @git.rev_parse({raise: true}, tag)
    output = @git.ls_remote({raise: true}, origin_name, "refs/tags/#{tag}")
    if output =~ /#{hash}\s*refs\/tags\/#{tag}/
      return true
    end
    return false
  end

  # return Grit::Head object or nil if in detached state
  def head
    return @repo.head
  end

  # return the latest commit's hash
  def get_hash(commitish='HEAD')
    return @git.rev_parse({raise: true}, commitish)
  end

  # Get the first eight characters of commit hash for given tag, branch or hash
  def get_short_hash(commitish='HEAD')
    return get_hash(commitish)[0,8]
  end

  def current_branch
    return @git.run('', 'rev-parse', '', {}, ['--abbrev-ref', 'HEAD']).chomp
  end

  # Return array of "<remote>/<branch>" values containing given commit hash
  def remote_branches_containing(hash)
    return @git.run('', 'branch', '', {}, ['-r', '--contains', hash])
  end

  # get the hash for branch/tag in the remote origin
  def has_remote?(commitish, origin_name='origin')
    output = @git.ls_remote({raise: true}, origin_name)
    output.split.each do |line|
      if line=~ /[a-z0-9]{40}\s*refs\/(tags|heads)\/#{commitish}/
        return true
      end
    end
    return nil
  end

  def head_detached?
    if @repo.head == nil
      return true
    end
    return false
  end

  def has_local_modifications?
    if @git.status({raise: true}, '--porcelain') == ''
      return false
    end
    return true
  end
end

# Create a new tag using the name of current branch and a UTC timestamp, then
# push code & tag to remote.
def git_cut_tag(git=GitRepo.new)
  unless git.head_detached?
    raise 'You are currently in a detached head state. Cannot cut tag.'
  end
  new_tag = "#{git.head.name}-#{Time.now.utc.to_i}"
  git.fetch
  git.remote_tag new_tag
  return new_tag
end

Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :deploy do
    desc 'Cuts a tag for deployment and prints out further instructions to finalize deployment'
    task :prepare do
      skip_git = fetch(:skip_git, false)
      if skip_git
        Capistrano::CLI.ui.say yellow "Skipping prepare as 'skip_git' option is enabled"
        return
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

  after 'deploy_previous_tag', 'deploy'

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

  after "deploy:create_symlink", "git:update_tag_for_stage"
  before "deploy", "git:validate_branch_is_tag"
  before "deploy:migrations", "git:validate_branch_is_tag"

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
      return config[:_git_branch] if config[:_git_branch]

      # if tag is provided (e.g. -s tag=master-1234567890), use it. otherwise, cut a new tag.
      tag = config[:tag] || git_cut_tag
      config[:_git_branch] = tag
      git_sanity_check(tag)

      config[:_git_branch]
    end

    # NOTE: looking at projects in Github I'm not seeing these tags.
    task :update_tag_for_stage do
      skip_git = fetch(:skip_git, false)
      if skip_git
        Capistrano::CLI.ui.say yellow "Skipping update_tag_for_stage as 'skip_git' option is enabled"
        return
      end

      logger.important("Updating the tag for stage #{stage}")
      git = GitRepo.new(fetch(:skip_git, false))
      env = config[:stage]
  
      git.delete_remote_tag env
      git.remote_tag env
      git.remote_tag "DEPLOYED---#{env}---#{Time.now.utc.to_i}"
    end

    task :validate_branch_is_tag do
      skip_git = fetch(:skip_git, false)
      if skip_git
        Capistrano::CLI.ui.say yellow "Skipping validate_branch_is_tag as 'skip_git' option is enabled"
        return
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
    skip_git = fetch(:skip_git, false)
    if skip_git
      Capistrano::CLI.ui.say yellow "Skipping git_sanity_check as 'skip_git' option is enabled"
      return
    end

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
      logger.info "An exception as occured while fetching the current revision. This is to be expected if this is your first deploy to this machine. Othewise, something is broken :("
      logger.info e.inspect
      logger.info "*" * 80
      nil
    end
  end
end
