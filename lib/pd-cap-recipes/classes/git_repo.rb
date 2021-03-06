require 'grit'

# Convenience wrapper around Grit::Git
class GitRepo
  attr_writer :preferred_remote

  def initialize
    @git = Grit::Git.new(File.join('.', '.git'))
    @repo = Grit::Repo.new('.')
  end

  def method_missing(*args, &block)
    @git.__send__(*args, &block)
  end

  def delete_remote_tag(tag)
    remote = preferred_remote
    @git.tag d: tag
    @git.push({raise: true}, remote, ":refs/tags/#{tag}")
  end

  def remote_tag(tag)
    remote = preferred_remote
    @git.tag({raise: true}, tag)
    @git.push({raise: true}, remote, "refs/tags/#{tag}")
  end

  # Fetch latest from origin and check given hash exists in origin
  def check_tag_exists_in_origin(tag)
    origin_name = preferred_remote
    fail "invalid tag: #{string.inspect}" unless string.is_a?(String)
    hash = @git.rev_parse({raise: true}, tag)
    output = @git.ls_remote({raise: true}, origin_name, "refs/tags/#{tag}")
    output =~ %r{#{hash}\s*refs/tags/#{tag}}
  end

  # return Grit::Head object or nil if in detached state
  def head
    @repo.head
  end

  # return the latest commit's hash
  def get_hash(commitish='HEAD', opts={raise: true})
    commitish = commitish.to_s
    @git.rev_parse(opts, commitish).chomp
  end

  # Get the first eight characters of commit hash for given tag, branch or hash
  def get_short_hash(commitish='HEAD')
    commitish = commitish.to_s
    get_hash(commitish)[0, 8]
  end

  def current_branch
    @git.run('', 'rev-parse', '', {}, ['--abbrev-ref', 'HEAD']).chomp
  end

  # Return array of "<remote>/<branch>" values containing given commit hash
  def remote_branches_containing(hash)
    @git.run('', 'branch', '', {}, ['-r', '--contains', hash])
  end

  # get the hash for branch/tag in the remote origin
  def remote?(commitish)
    origin_name = preferred_remote
    commitish = commitish.to_s
    output = @git.ls_remote({raise: true}, origin_name)
    output.split.each do |line|
      return true if line =~ %r{[a-z0-9]{40}\s*refs/(tags|heads)/#{commitish}}
    end
    nil
  end

  def head_detached?
    @repo.head.nil?
  end

  # rubocop:disable Style/PredicateName
  def has_local_modifications?
    @git.status({raise: true}, '--porcelain') != ''
  end
  # rubocop:enable Style/PredicateName

  def preferred_remote
    @preferred_remote ||= determine_preferred_remote
  end

  private

  def determine_preferred_remote
    remotes = remote_names
    if remotes.size == 1
      remotes.first
    else
      'origin'
    end
  end

  def remote_names
    @repo.config.keys
      .select { |k| k.start_with? 'remote.' }
      .map { |r| r.split('.')[1] }
      .sort.uniq
  end
end
