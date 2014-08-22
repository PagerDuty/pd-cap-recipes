Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :deploy do

    # This deletes any releases that are newer than that pointed to be the current symlink.
    #
    # It can be useful to hook this in to run before update_code. Otherwise, running update_code
    # followed by a deploy can leave users in an unexpected state that can cause problems with
    # rollbacks.
    #
    # Case 1) If update_code was used previously across all boxes, followed by a full deploy,
    # then the penultimate release on each server will not be from the previous full deploy. This
    # means that a deploy:rollback will rollback onto code the user may not be expecting it to.
    #
    # Case 2) Another issue occurs when update_code is used on only a selection of servers followed
    # by a full deploy. In this case, cap will deduce the release to rollback to based on whatever
    # is the previous release on the first server it encounters. This won't match what the previous
    # release is on all servers, and so some will be incorrectly symlinked against non existent
    # releases.
    #
    # To hook this in to run before update_code:
    #   before 'deploy:update_code', 'deploy:cleanup_lingering_releases'
    desc <<-DESC
    Deletes any releases that are more recent than what is pointed to by the "current" symlink, \
    unless the environment variable PRESERVE_LINGERING_RELEASES is set to "true".
    DESC
    task :cleanup_lingering_releases do
      lingering_releases = servers_with_lingering_releases

      if lingering_releases.size > 0
        logger.info "Lingering releases exist on #{lingering_releases.keys}. Details are " +
          "#{lingering_releases}"
        if ENV['PRESERVE_LINGERING_RELEASES'] != 'true'
          logger.info "Deleting lingering releases found on #{lingering_releases.keys}"
          dynamic_latest_release = "\"#{releases_path}/`ls -1 #{releases_path} | tail -n 1`\""

          # Delete lingering releases, checking that they are not pointed to by the current symlink
          # Note: This has one danger, in that there is no guarantee that the code being deleted
          # is not being used despite not being pointed to be the current symlink.
          run "if [[ -e #{dynamic_latest_release} ]] " +
            "&& [[ `readlink  #{current_path}` != #{dynamic_latest_release} ]]; " +
            "then rm -rf #{dynamic_latest_release}; fi", options: {hosts: lingering_releases.keys}
        else
          logger.info
            'Skipping deletion of lingering releases as PRESERVE_LINGERING_RELEASES == true'
        end
      else
        logger.info 'No lingering releases to clean up.'
      end

    end
  end

  # Fetches a hash of all servers that contain a lingering release, of the form:
  # { host: { current: "/release-directory/1", lingering: "/release-directory/2" }}
  def servers_with_lingering_releases
    releases_by_host = run_command_get_std_stream("ls -1 #{releases_path}", true).map {
      |host, streams| {
          host => streams[:stdout].split("\n").map { |r| "#{releases_path}/#{r}" }.sort
      }
    }.reduce(&:merge)

    current_release_by_host = run_command_get_std_stream("readlink #{current_path}", true).map {
      |host, streams| { host => streams[:stdout].gsub("\n", '') }
    }.reduce(&:merge)

    if releases_by_host.present? && current_release_by_host.present?
      hosts_with_lingering_releases = releases_by_host.select { |host, releases|
        !releases.empty? && releases.last != current_release_by_host[host]
      }

      # We could lose this if, but I prefer to always return a hash ({}.reduce(&:merge) == nil)
      if hosts_with_lingering_releases.present?
        hosts_with_lingering_releases.map { |host, releases|
          { host => { current: current_release_by_host[host], lingering: releases.last } }
        }.reduce(&:merge)
      else
        {}
      end
    else
      {}
    end

  end

  def run_command_get_std_stream(command, exception_on_stderr)
    result = {}
    run command do |channel, stream, data|
      if stream == :err && data.present? && exception_on_stderr
        raise Exception("Error performing command `#{command}` on #{channel[:host]}, stderr " +
          "was: #{data} ")
      end
      result[channel[:host]] ||= { out: [], err: []}
      result[channel[:host]][stream] << data
    end

    if result.size > 0
      result.map { |host, streams| {
          host => { stdout: streams[:out].join(''), stderr: streams[:err].join('') }
        }
      }.reduce(&:merge)
    else
      {}
    end
  end
end
