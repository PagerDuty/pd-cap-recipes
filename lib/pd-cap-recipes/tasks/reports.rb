require 'net/ssh/gateway'
require 'net/ssh'

Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :report do

    desc <<-DESC
      Print out which versions are installed on machines
    DESC
    task :list_releases do
      info = collect_version_info_for_cluster
      info.each do |machine, folder_info| puts "Releases on #{machine}:"
        folder_info.each do |folder|
          puts "  #{folder[:folder]} -> #{folder[:revision]}"
        end
      end
    end

    desc <<-DESC
    DESC
    task :check_current_version do
        rev_info = get_current_rev_info
        revs = Set.new
        rev_info.each do |host, rev|
          revs.add(rev)
        end

        if revs.length > 1
          logger.important("There are more than 1 current revisions! Please update machines so that all are running the same current revision")
          logger.important("Found #{revs.length} current revision values:")
          rev_info.each do |host, rev|
            logger.important("#{host} -> #{rev}")
          end
          return
        end

        logger.important("The current revision installed on #{rev_info.keys.length} machines is #{revs.first}")
    end

    desc <<-DESC
      Print out a report showing the distinct set of versions installed on \
      machines
    DESC
    task :revision_sets do
      info = collect_version_info_for_cluster

      current_round = info.keys.reverse
      next_round = []
      sets = []
      sets_to_machine = Hash.new {|h, k| h[k] = []} # on new key return empty array

      while not current_round.empty?
        current_machine = current_round.pop
        current_set = Set.new info[current_machine].collect {|item| item[:revision]}
        sets_to_machine[current_set].push current_machine

        while not current_round.empty?
          next_machine = current_round.pop
          next_set = Set.new info[next_machine].collect {|item| item[:revision]}
          if next_set == current_set
            sets_to_machine[current_set].push next_machine
            next
          end
          next_round.push next_machine
        end

        sets.push current_set
        current_round = next_round
      end

      puts "Found #{sets_to_machine.keys.length} distinct set(s) of deployed revisions\n"
      sets_to_machine.keys.each do |revision_set|
        hosts_for_set = sets_to_machine[revision_set]
        puts "Revision set\n  #{revision_set.to_a.join("\n  ")}\nfound on hosts\n  #{hosts_for_set.to_a.join("\n  ")}\n"
      end
    end
  end

  # Return a hash with host -> current revision mapping
  def get_current_rev_info
    host_versions = {}
    ssh_to_cluster do |machine, ssh|
        host_versions[machine.host] = ssh.exec!("cat #{deploy_to}/current/REVISION").strip
    end
    return host_versions
  end

  # Return a hash with host -> hash of information on release folder mapping
  def collect_version_info_for_cluster
    cluster_info = {}
    ssh_to_cluster do |machine, ssh|
      ls_output = ssh.exec!("ls -l #{deploy_to}/releases/")
      folder_info = parse_ls_l(ls_output)
      folder_info.each do |info|
        revision = ssh.exec!("cat #{deploy_to}/releases/#{info[:folder]}/REVISION")
        info[:revision] = revision.strip
      end
      cluster_info[machine.host] = folder_info
    end
    return cluster_info
  end

  # Allow passing a block to process on each cluster/stage machine
  def  ssh_to_cluster
    servers = find_servers_for_task(current_task)
    user = fetch(:user)
    deploy_to = fetch(:deploy_to)

    gateway_config = fetch(:gateway, nil)
    if gateway_config != nil
      gateway_host = fetch(:gateway, {'localhost'=>nil}).keys.first
      gateway = Net::SSH::Gateway.new(gateway_host, user)
      servers.each do |machine|
        gateway.ssh(machine, user) do |ssh|
          yield machine, ssh
        end
      end
      gateway.shutdown!
    else
      servers.each do |machine|
        Net::SSH.start(machine.host, user) do |ssh|
          yield machine, ssh
        end
      end
    end
  end

  # Parse the output of 'ls -l' command return hash with prased details
  def parse_ls_l(text)
    file_info = []
    lines = text.split("\n")[1..-1]
    lines.each do |line|
      parts = line.split
      ls_info = {}
      ls_info[:permissions] = parts[0]
      ls_info[:owner] = parts[2]
      ls_info[:group] = parts[3]
      ls_info[:folder] = parts[8]
      file_info.push(ls_info)
    end
    return file_info
  end
end
