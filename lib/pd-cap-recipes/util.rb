require 'net/ssh/gateway'
require 'net/ssh'

# Return a hash with host -> current revision mapping
def get_current_rev_info(servers, user, port, gateway_host: nil)
  host_versions = {}
  ssh_to_cluster(servers, user, port, gateway_host: gateway_host) do |machine, ssh|
      ssh.exec!("cat #{deploy_to}/current/REVISION") do |ch, strm, data|
        if strm == :stdout
          host_versions[machine.host] = data.strip
        else
          host_versions[machine.host] = 'unknown'
        end
      end
  end
  return host_versions
end

# Return a hash with host -> hash of information on release folder mapping
def collect_version_info(servers, user, port, gateway_host: nil)
  cluster_info = {}
  ssh_to_cluster(servers, user, port, gateway_host: gateway_host) do |machine, ssh|
    ls_output = ssh.exec!("ls -l #{deploy_to}/releases/")
    folder_info = parse_ls_l(ls_output)
    folder_info.each do |info|
      ssh.exec!("cat #{deploy_to}/releases/#{info[:folder]}/REVISION") do |ch, strm, data|
        if strm == :stdout
          info[:revision] = data.strip
        else
          info[:revision] = '*unable to determine'
        end
      end
    end
    cluster_info[machine.host] = folder_info
  end
  return cluster_info
end

# Allow passing a block to process on each cluster/stage machine
def ssh_to_cluster(servers, user, port, gateway_host: nil)
  if gateway_host != nil
    gateway = Net::SSH::Gateway.new(gateway_host, user, :port=>port)
    servers.each do |machine|
      gateway.ssh(machine, user) do |ssh|
        yield machine, ssh
      end
    end
    gateway.shutdown!
  else
    servers.each do |machine|
      Net::SSH.start(machine.host, user, :port=>port) do |ssh|
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
