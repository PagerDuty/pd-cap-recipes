Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :deploy do
    desc 'Release in percentage based blocks, defaulting blocks to (floor of) 10% of machines'
    task :slow do
      percentage = fetch(:slow_block_size, 0.10).to_f
      if percentage < 0 || percentage > 1
        raise "Please set slow_block_size to a percentage between 0.0 and 1.0"
      end

      server_count = find_servers_for_task(current_task).size
      hosts = (server_count * percentage).floor
      if hosts <= 0
        hosts = 1
      end
      set :max_hosts, hosts
      default # run default set of tasks (build, deploy, etc)
    end
  end
end
