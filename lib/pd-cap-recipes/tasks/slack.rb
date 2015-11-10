require 'pd-cap-recipes/pd_slack'

Capistrano::Configuration.instance(:must_exist).load do
  # Slack
  ########
  # Please set these in your project's Capfile:
  # - slack_deploy_incoming_webhook to a posting key authorized for your Slack account, e.g. '/Tfoofoo/Bbarbar/Ibazbazbaz'
  # - slack_username is who the slack notification will claim to be from
  # - slack_emoji is the avatar for who the slack notification will claim to be from
  # - slack_application
  # - slack_scm_app_url e.g. 'https://github.com/PagerDuty/appname'
  # - slack_additional_attachments if you want extra information in the the deploy start message.
  #   Should be a list of (title, value, short) as per PdSlack::IncomingWebhookAttachment#add_field.
  # - slack_pub_channel defaults to #deployments-prod (when production) or #deployments-other

  # Hooks
  #####
  before 'deploy', 'slack:starting'
  after 'deploy', 'slack:finished'

  def enabled?
    fetch(:slack_enabled, true)
  end

  def slack_environment
    fetch(:stage, 'production')
  end

  def slack_revision(branch)
    return '---' if branch.nil? || branch == ''

    "<#{slack_scm_app_url}/tree/#{branch}|#{branch}>"
  end

  def slack_commit(sha)
    "<#{slack_scm_app_url}/commit/#{sha}|#{sha}>"
  end

  def slack_starting_color
    '#FFCC00'
  end

  def slack_finished_color
    '#009933'
  end

  def slack_failure_color
    '#CC0000'
  end

  def slack_deployer
    fetch(:deployer_name, nil) || ENV['DEPLOYER_NAME'] || ENV['GIT_AUTHOR_NAME'] || `git config user.name`.chomp || 'Someone'
  end

  def slack_deployment_name
    return slack_application unless fetch(:branch, nil)
    "#{slack_application}/#{branch}"
  end

  def build_changelog
    changelog = []
    begin
      from = fetch(:latest_revision)
      to = fetch(:real_revision)
      # generates a string like '9ce7af12$$Author$$commit log string'. Easy to parse in next step.
      logs = run_locally(source.local.scm(:log, "--no-merges --pretty=format:'%h$$%an$$%s' #{from}..#{to}"))
      logs.split(/\n/).each do |log|
        ll = log.split(/\$\$/)
        changelog << "• #{ll[2]} (#{slack_commit(ll[0])})"
      end
    rescue => e
      Capistrano::CLI.ui.say red "Unable to determine revision information, skipping changelog generation for Slack notification."
      logger.important(e.message)
    end
    changelog
  end

  def channel
    fetch(:slack_pub_channel)
  rescue
    stage == :production ? '#deployments-prod' : '#deployments-other'
  end

  namespace :slack do
    task :starting do
      next unless enabled?
      changelog = build_changelog

      attachment = PdSlack::IncomingWebhookAttachment.new(
        fallback: "#{slack_deployer} is deploying.",
        color: slack_starting_color
      )

      attachment.add_field('Application', slack_application, short: true)
      attachment.add_field('Environment', slack_environment, short: true)
      attachment.add_field('Revision', slack_revision(branch), short: true)
      fetch(:slack_additional_attachments, []).each { |a| attachment.send :add_field, *a }
      attachment.add_field('Changelog', changelog, short: false) unless changelog.empty?

      webhook = PdSlack::IncomingWebhook.new(
        fetch(:slack_deploy_incoming_webhook),
        username: fetch(:slack_username, 'DevOps Taylor Swift'),
        icon_emoji: fetch(:slack_emoji, ':cooltay:'),
        mrkdwn: true,
        channel: channel,
        attachments: [attachment]
      )

      webhook.invoke(text: "#{slack_deployer} is deploying.")
      set(:start_time, Time.now)
    end

    task :finished do
      next unless enabled?
      wrapup_msg = "#{slack_deployer} deployed #{slack_deployment_name} to #{slack_environment} successfully"
      slack_start_time = fetch(:start_time, nil)
      if slack_start_time
        wrapup_msg << " in #{Time.now.to_i - slack_start_time.to_i} seconds"
      end
      wrapup_msg << '.'

      attachment = PdSlack::IncomingWebhookAttachment.new(
        fallback: wrapup_msg,
        color: slack_finished_color
      )

      attachment.add_field('', wrapup_msg, short: true)

      webhook = PdSlack::IncomingWebhook.new(
        fetch(:slack_deploy_incoming_webhook),
        username: fetch(:slack_username, 'DevOps Taylor Swift'),
        icon_emoji: fetch(:slack_emoji, ':cooltay'),
        mrkdwn: true,
        channel: channel,
        attachments: [attachment]
      )

      webhook.invoke(text: '')
    end
  end
end
