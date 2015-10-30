require 'spec_helper'
require 'pd-cap-recipes/pd_slack'

describe PdSlack::IncomingWebhookAttachment do
  context 'testing field' do
    it 'initializes with values' do
      field = PdSlack::IncomingWebhookAttachmentField.new('Field 1', 'Value 1', false)
      expect(field.short).to eq false
    end
  end

  context 'testing attachments' do
    it 'initalizes with some elements, and no fields' do
      attachment = PdSlack::IncomingWebhookAttachment.new(
        pretext: 'Real Time Deployment via Capistrano',
        fallback: 'Deployed version something something',
        author_name: 'Rob Ottaway',
        color: 'good',
        title: 'Hey Slack!',
        title_link: 'https://pagerduty.com')
      expect(attachment.elements.keys.length).to eq 6
      expect(attachment.fields.length).to eq 0
    end

    it 'initalizes with some elements and fields' do
      field1 = PdSlack::IncomingWebhookAttachmentField.new('Field 1', 'Field 1 value')
      field2 = PdSlack::IncomingWebhookAttachmentField.new('Field 2', 'Field 2 value', false)
      attachment = PdSlack::IncomingWebhookAttachment.new(
        pretext: 'Real Time Deployment via Capistrano',
        fallback: 'Deployed version something something',
        author_name: 'Rob Ottaway',
        color: 'good',
        title: 'Hey Slack!',
        title_link: 'https://pagerduty.com',
        fields: [field1, field2])
      expect(attachment.elements.keys.length).to eq 6
      expect(attachment.fields.length).to eq 2
    end

    it 'initializes with elements, and add two fields' do
      attachment = PdSlack::IncomingWebhookAttachment.new(
        fallback: 'Deployed version something something')
      attachment.add_field('Field 1', 'field 1 value')
      attachment.add_field('Field 2', 'field 2 value')
      expect(attachment.elements.keys.length).to eq 1
      expect(attachment.fields.length).to eq 2
    end

    it 'returns the expected hash when no fields configured' do
      attachment = PdSlack::IncomingWebhookAttachment.new(
        pretext: 'just a random element')
      hash = attachment.as_payload
      expect(hash.keys.length).to eq 1
      expect(hash[:pretext]).to eq 'just a random element'
      expect(attachment.fields.length).to eq 0
    end

    it 'attachment returns the expected hash when fields' do
      attachment = PdSlack::IncomingWebhookAttachment.new(
        pretext: 'just a random element')
      attachment.add_field('Field 1', 'field 1 value')
      hash = attachment.as_payload
      expect(hash.keys.length).to eq 2
      expect(hash[:pretext]).to eq 'just a random element'
      expect(hash[:fields].first[:title]).to eq 'Field 1'
      expect(hash[:fields].first[:value]).to eq 'field 1 value'
    end

    it 'fails when given unknown fields' do
      expect {PdSlack::IncomingWebhookAttachment.new(notaelement: 'oops')}.to raise_error PdSlack::InvalidElement
    end
  end

  context 'testing incoming webhook' do
    fake_uri = '/bah/bah/blacksheep'

    it 'initializes with some elements, but no attachments' do
      hook = PdSlack::IncomingWebhook.new(fake_uri, text: 'bah', icon_emoji: ':funny:')
      expect(hook.elements.length).to eq 2
      expect(hook.attachments.length).to eq 0
    end

    it 'initializes with some elements and attachments' do
      attachment = PdSlack::IncomingWebhookAttachment.new(
        pretext: 'just a random element')
      hook = PdSlack::IncomingWebhook.new(fake_uri, text: 'bah', icon_emoji: ':funny:', attachments: [attachment])
      expect(hook.elements.length).to eq 2
      expect(hook.attachments.length).to eq 1
    end

    it 'returns the expected hash when no attachments' do
      hook = PdSlack::IncomingWebhook.new('/bah/bah/blacksheep', text: 'bah')
      expect(hook.uri.host).to eq 'hooks.slack.com'
      expect(hook.uri.path).to eq '/services/bah/bah/blacksheep'
      expect(hook.elements.length).to eq 1
      expect(hook.attachments.length).to eq 0
    end

    it 'returns the expected hash when attachments' do
      attachment = PdSlack::IncomingWebhookAttachment.new(
        pretext: 'just a random element')
      hook = PdSlack::IncomingWebhook.new(fake_uri, text: 'bah', icon_emoji: ':funny:', attachments: [attachment])
      hash = hook.as_payload
      expect(hash[:text]).to eq 'bah'
      expect(hash[:icon_emoji]).to eq ':funny:'
      expect(hash[:attachments].length).to eq 1
    end

    it 'fails when given unknown fields' do
      expect {PdSlack::IncomingWebhook.new('/bah/bah/blacksheep', notaelement: 'oops')}.to raise_error PdSlack::InvalidElement
    end

    it 'invokes without issue' do
      attachment = PdSlack::IncomingWebhookAttachment.new(
        pretext: 'just a random element')
      http = spy(Net::HTTP)
      allow_any_instance_of(PdSlack::IncomingWebhook).to receive(:http).and_return(http)
      hook = PdSlack::IncomingWebhook.new(fake_uri, text: 'bah', icon_emoji: ':funny:', attachments: [attachment])
      payload_as_json = hook.as_payload.to_json
      expect_any_instance_of(Net::HTTP::Post).to receive(:set_form_data).with(payload: payload_as_json)
      expect(http).to have_recieved(:request)
      hook.invoke
    end
  end
end
