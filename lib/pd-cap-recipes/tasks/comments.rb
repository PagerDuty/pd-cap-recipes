COMMENT_FILE = "/var/tmp/cap_message.txt"

Capistrano::Configuration.instance(:must_exist).load do |config|
  namespace :hipchat do
    task :custom_comment do
      hipchat.send(comment, hipchat.send_options)
    end
  end

  # Make sure that there's a comment for this deploy
  set :comment do
    unless config[:comment_value]
      file = COMMENT_FILE
      FileUtils.rm(file) if File.exists?(file)
      if no_comment?
        prev = safe_current_revision
        cur = fetch(:branch)
        content =
"""

# Please provide a meaningful comment describing what you are deploying.
"""
        File.open(file, 'w') do |f|
          f.write(content)
        end

        if prev && cur
          `git log #{prev}..#{cur} --pretty="# %h: %s" >> #{file}`
        end

        system("#{ENV['EDITOR'] || 'vim'} #{file}")
        comment = File.exist?(file) ? File.open(file).read : nil

        config[:comment_value] = clean_comment(comment)
      end

      if no_comment?
        raise "You must specify a comment"
      end
    end
    config[:comment_value]
  end

  def no_comment?
    !exists?(:comment_value) || fetch(:comment_value).nil? || fetch(:comment_value).strip == ""
  end

  def clean_comment(comment)
    comment.split("\n").reject{|line| /^\s*#.*$/ === line}.reject{|line| line.strip == ""}.join("\n")
  end
end
