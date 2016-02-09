require 'json'
require 'uri'
require 'net/http'

module PdSlack
  class InvalidElement < StandardError
  end

  # Represents a field in incoming webhook attachment
  class IncomingWebhookAttachmentField
    attr_reader :title, :value, :short

    def initialize(title, value, short=true)
      @title = title
      @value = value
      @short = short
    end

    def as_payload
      {
        :title => @title,
        :value => @value,
        :short => @short
      }
    end
  end

  # Represents an attachment on an incoming webhook
  # see: https://api.slack.com/docs/attachments
  class IncomingWebhookAttachment
    @allowed_elements = [
      :fallback, :color, :pretext, :author_name, :author_link, :author_icon,
      :title, :title_link, :text, :image_url, :thumb_url, :mrkdwn_in]
    attr_reader :elements, :fields

    def self.element_allowed?(element)
      @allowed_elements.include? element
    end

    def initialize(**elements)
      @elements = elements
      @fields = elements.key?(:fields) ? elements.delete(:fields) : []
      @elements.keys.each do |element|
        unless IncomingWebhookAttachment.element_allowed? element
          fail InvalidElement.new("#{element} is not a valid element, please see https://api.slack.com/incoming-webhooks")
        end
      end
    end

    # Create hash of attachment
    def as_payload
      payload = @elements.clone
      payload[:fields] = @fields.collect(&:as_payload) if fields.length > 0
      payload
    end

    def add_field(title, value='', short=true)
      @fields.push(IncomingWebhookAttachmentField.new(title, value, short))
    end
  end

  # Represents a webhook that can be invoked to pass along message.
  # see: https://api.slack.com/incoming-webhooks
  class IncomingWebhook
    @allowed_elements = [
      :text, :username, :icon_url, :icon_emoji, :channel, :mrkdwn]
    attr_reader :uri, :http, :attachments, :elements

    def self.element_allowed?(element)
      @allowed_elements.include? element
    end

    def initialize(webhook_path, **elements)
      @base_uri = 'https://hooks.slack.com/services'
      @uri = URI.parse("#{@base_uri}#{webhook_path}")
      @http = Net::HTTP.new(@uri.host, @uri.port)
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      @attachments = elements.key?(:attachments) ? elements.delete(:attachments) : []
      @elements = elements
      @elements.keys.each do |element|
        unless IncomingWebhook.element_allowed? element
          fail InvalidElement.new("#{element} is not a valid element, please see https://api.slack.com/incoming-webhooks")
        end
      end
    end

    def add_attachment(attachment)
      @attachments.push attachment
    end

    # You can override elements and attachments for one invocation by passing
    # them here.
    def invoke(**elements)
      payload = as_payload(elements)
      request = Net::HTTP::Post.new(@uri.request_uri)
      request.set_form_data(payload: payload.to_json)
      @http.request(request)
    end

    # Create the hash representing webhook payload, including any overrides
    # passed.
    def as_payload(**elements)
      payload = @elements.clone
      elements.each do |k, v|
        payload[k] = v
      end

      # check if any override attachements, sub them in
      copy_of_attachments = @attachments.clone
      if elements.key?(:attachments)
        elements[:attachments].each do |a|
          copy_of_attachments.push a
        end
      end
      payload[:attachments] = copy_of_attachments.collect(&:as_payload) unless copy_of_attachments.length == 0

      payload
    end
  end
end
