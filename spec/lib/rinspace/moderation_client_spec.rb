# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::ModerationClient do
  around do |example|
    ClimateControl.modify(
      RINSPACE_MODERATION_ENDPOINT: 'https://rinspace.internal/rinspace/internal/v1/mastodon/moderation/text',
      RINSPACE_MODERATION_HMAC_KEY: 'm' * 32
    ) { example.run }
  end

  it 'uses a signed server-side request and accepts only pass' do
    request = stub_request(:post, ENV.fetch('RINSPACE_MODERATION_ENDPOINT')).to_return(status: 200, body: '{"decision":"pass"}')

    expect(described_class.new.review_text!(subject: 'uid-1', target_type: 'status', target_id: '', title: '', text: 'hello')).to be true
    expect(request.with { |value| value.headers['X-Rin-Service'] == 'rinspace-mastodon' && value.headers['X-Rin-Signature'].present? }).to have_been_requested
  end

  it 'fails closed on review decisions and service outages' do
    stub_request(:post, ENV.fetch('RINSPACE_MODERATION_ENDPOINT')).to_return(status: 200, body: '{"decision":"review"}')
    expect { described_class.new.review_text!(subject: 'uid-1', target_type: 'status', target_id: '', title: '', text: 'hello') }.to raise_error(Rinspace::ModerationRejectedError)

    stub_request(:post, ENV.fetch('RINSPACE_MODERATION_ENDPOINT')).to_return(status: 503)
    expect { described_class.new.review_text!(subject: 'uid-1', target_type: 'status', target_id: '', title: '', text: 'hello') }.to raise_error(Rinspace::ModerationUnavailableError)
  end
end
