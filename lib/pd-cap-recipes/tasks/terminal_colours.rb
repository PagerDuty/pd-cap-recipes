Capistrano::Configuration.instance(:must_exist).load do |config|

  def green(s)
    "\e[1m\e[32m#{s}\e[0m"
  end

  def yellow(s)
    "\e[1m\e[33m#{s}\e[0m"
  end

  def red(s)
    "\e[1m\e[31m#{s}\e[0m"
  end

  def purple(s)
    "\e[1m\e[35m#{s}\e[0m"
  end

end
