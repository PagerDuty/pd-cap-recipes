require 'net/ssh/gateway'
require 'net/ssh'
require 'pd-cap-recipes/util'

# Get's the connection details from Capistrano configuration.
def get_connection_details
  servers = find_servers_for_task(current_task)
  user = fetch(:user)
  deploy_to = fetch(:deploy_to)
  gateway_host = nil
  begin
    gateway_config = fetch(:gateway)
    gateway_host = gateway_config.keys.first
  rescue
  end
  return servers, user, gateway_host
end

Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :report do

    desc <<-DESC
      Print out which versions are installed on machines
    DESC
    task :list_releases do
      servers, user, gateway_host = get_connection_details
      info = collect_version_info(servers, user, gateway_host)
      info.each do |machine, folder_info|
        puts "Releases on #{machine}:"
        folder_info.each do |folder|
          puts "  #{folder[:folder]} -> #{folder[:revision]}"
        end
      end
    end

    desc <<-DESC
      Print out the current version used on all servers, or if there is more
      than one 'current version' found report on them.
    DESC
    task :check_current_version do
        servers, user, gateway_host = get_connection_details
        rev_info = get_current_rev_info(servers, user, gateway_host)
        revs = Set.new
        rev_info.each do |host, rev|
          revs.add(rev)
        end

        if revs.length > 1
          puts "There are more than 1 current revisions! Please update machines so that all are running the same current revision"
          puts "Found #{revs.length} current revision values:"
          rev_info.each do |host, rev|
            puts "#{host} -> #{rev}"
          end
        end

        puts "The current revision installed on #{rev_info.keys.length} machines is '#{revs.first}'"
    end

    desc <<-DESC
      Print out a report showing the distinct set of versions installed on \
      machines
    DESC
    task :revision_sets do
      servers, user, gateway_host = get_connection_details
      info = collect_version_info(servers, user, gateway_host)

      current_round = info.keys.reverse
      sets_to_machine = Hash.new {|h, k| h[k] = []} # on new key return empty array

      info.each do |machine, revinfo|
        current_set = Set.new revinfo.collect {|item| item[:revision]}
        sets_to_machine[current_set].push machine
      end

      puts "Found #{sets_to_machine.keys.length} distinct set(s) of deployed revisions\n"
      sets_to_machine.keys.each do |revision_set|
        hosts_for_set = sets_to_machine[revision_set]
        puts "Revision set\n  #{revision_set.to_a.join("\n  ")}\nfound on hosts\n  #{hosts_for_set.to_a.join("\n  ")}\n"
      end
    end
  end
end
