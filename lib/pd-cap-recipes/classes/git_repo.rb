require 'grit'

class GitRepo
  def initialize()
    @git = Grit::Git.new(File.join('.', '.git'))
    @repo = Grit::Repo.new('.')
  end

  def method_missing(*args, &block)
    @git.__send__(*args, &block)
  end

  def delete_remote_tag(tag, remote='origin')
    @git.tag d: tag
    @git.push({raise: true}, remote, ":refs/tags/#{tag}")
  end

  def remote_tag(tag, remote='origin')
    @git.tag({raise: true}, tag)
    @git.push({raise: true}, remote, "refs/tags/#{tag}")
  end

  # Fetch latest from origin and check given hash exists in origin
  def check_tag_exists_in_origin(tag, origin_name='origin')
    raise "invalid tag: #{string.inspect}" unless string.is_a?(String)
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
  def get_hash(commitish='HEAD', opts={raise: true})
    commitish = commitish.to_s
    return @git.rev_parse(opts, commitish).chomp
  end

  # Get the first eight characters of commit hash for given tag, branch or hash
  def get_short_hash(commitish='HEAD')
    commitish = commitish.to_s
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
    commitish = commitish.to_s
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

  def preferred_remote
    remotes = @repo.config.keys
      .select { |k| k.start_with? 'remote.' }
      .map { |r| r.split('.')[1] }
      .sort.uniq
    if remotes.size == 1
      remotes.first
    else
      'origin'
    end
  end
end
