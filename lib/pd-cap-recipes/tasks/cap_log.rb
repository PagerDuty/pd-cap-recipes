# This logs the output a capistrano deployment to a log file. Also dumps the
# cap environment in the file for debugging

require 'json'

module Capistrano 
  class DualLogger < Logger
    attr_accessor :console_output

    def initialize(*args)
      @console_output = true
      super
    end

    def log(level, message, line_prefix=nil)
      if level <= self.level
        indent = "%*s" % [MAX_LEVEL, "*" * (MAX_LEVEL - level)]
        now = "[#{Time.now}]"
        (RUBY_VERSION >= "1.9" ? message.lines : message).each do |line|
          msg = if line_prefix
                  "#{indent} #{now} [#{line_prefix}] #{line.strip}\n"
                else
                  "#{indent} #{now} #{line.strip}\n"
                end
          puts msg if @console_output
          device.puts msg
        end
      end
    end

    def without_console
      @console_output = false
      yield self
    ensure
      @console_output = true
    end
  end
end

Capistrano::Configuration.instance(:must_exist).load do |config|
  config.on :load do
    file = File.open('log/capistrano.log', 'a') rescue nil

    config.logger = Capistrano::DualLogger.new(:output => file)
    config.logger.level = 3
  end
end

