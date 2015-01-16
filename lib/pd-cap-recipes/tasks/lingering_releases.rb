require 'active_support/core_ext'

Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :deploy do

    # Checks if there are any releases that are more recent than the "current" symlink on each host.
    # If there are it deletes the most recent one.
    #
    # Below are listed some use cases which will be "fixed" by hooking in this task to run before
    # update_code. Otherwise, these use cases can cause problems with rollbacks.
    #
    # Case 1) If update_code is performed, followed by a full deploy, then the penultimate release
    # on each server will not be from the previous full deploy. This means that a deploy:rollback
    # will rollback onto code the user may not be expecting it to.
    #
    # Case 2) If update_code is performed with a host filter on some set of hosts H, followed
    # by a full deploy, then the penultimate deploy will differ on H and ~H. Cap will deduce the
    # release to rollback to based on whatever is the penultimate release on the first server it
    # encounters. This won't match what the penultimate release is on all servers, and so some will
    # be incorrectly symlinked against non existent releases.
    #
    # TODO Case 3) If a deploy is performed with host filter on some set of hosts H, followed by a
    # full deploy, then the penultimate release on H will differ from those on ~H.
    # This case will not be correctly cleaned up by this task, and will result in a bad rollback as
    # in Case 2.
    #
    # To hook this in to run before update_code:
    #   before 'deploy:update_code', 'deploy:cleanup_lingering_releases'
    desc <<-DESC
    Checks if there are any releases that are more recent than the "current" symlink on each host. \
    If there are it deletes the most recent one.
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
            "then rm -rf #{dynamic_latest_release}; fi", hosts: lingering_releases.keys
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
